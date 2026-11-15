extends Node

## Autoload that drives the simulation clock. It owns the run's SimState,
## converts real time into ticks, forwards every tick to SimTick and publishes
## the resulting facts to the EventLog ledger.
## No class_name on purpose: the autoload singleton is already named GameSim.

signal tick_advanced(tick: int)
signal game_over(cause: StringName)
signal game_reset()

const ECONOMY_PATH: String = "res://databases/economy.tres"
const MACHINES_PATH: String = "res://databases/machines.tres"
const EVENTS_PATH: String = "res://databases/events.tres"
const SECONDS_PER_TICK: float = 60.0
const MAX_TICKS_PER_FRAME: int = 10

enum Speed { X1, X5, X10 }

var state: SimState = SimState.new()
var speed: Speed = Speed.X1
## The clock boots frozen: menus and the intro must never advance ticks before
## a playable scene calls start_run().
var paused: bool = true
## True only between start_run() and stop_run(): menus and non-playable scenes
## keep it false, so a save request can tell a live run from a menu.
var run_active: bool = false

var _economy: EconomyData = null
var _machines: MachineDatabase = null
var _events: EventData = null
var _time_accumulator: float = 0.0


## Loads the data databases, reports their problems and prepares a fresh run.
## It does not call new_game(): booting must not clear an existing ledger.
func _ready() -> void:
	_economy = _load_economy()
	_machines = _load_machines()
	_events = _load_events()
	state.reset_from_economy(_economy)


## Converts this frame's real time into ticks unless the clock is paused.
func _process(delta: float) -> void:
	if paused:
		return
	feed_time(delta)


## Adds scaled real time to the accumulator and advances as many whole ticks as
## it holds, capped at MAX_TICKS_PER_FRAME. The remainder stays accumulated.
## Returns the number of ticks advanced.
func feed_time(seconds: float) -> int:
	_time_accumulator += seconds * get_rate()
	var ran: int = 0
	while _time_accumulator >= SECONDS_PER_TICK and ran < MAX_TICKS_PER_FRAME:
		_time_accumulator -= SECONDS_PER_TICK
		advance_tick()
		ran += 1
	return ran


## Steps the simulation once and publishes the facts of that tick.
func advance_tick() -> void:
	var facts: Array[LogEntry] = SimTick.step(state, _economy, _machines, _events)
	EventLog.log_entries(facts)
	tick_advanced.emit(state.tick)
	for fact: LogEntry in facts:
		if fact.type == LogEntry.Type.GAME_OVER:
			game_over.emit(state.death_cause)
			# Freeze the real-time clock on death. advance_tick()/advance_ticks()
			# remain manual harness APIs and keep stepping if called directly.
			paused = true
			break


func advance_ticks(count: int) -> void:
	for i: int in range(count):
		advance_tick()


## Starts a clean run: fresh state, empty accumulator and empty ledger.
## It does not change the clock by itself: the caller decides when to run.
func new_game() -> void:
	state.reset_from_economy(_economy)
	_time_accumulator = 0.0
	EventLog.reset()
	game_reset.emit()


## Starts a playable run: resets the simulation and then enables the clock.
func start_run() -> void:
	new_game()
	run_active = true
	paused = false


## Freezes the clock and leaves the exterior state when the playable scene ends,
## so no later scene keeps consuming resources or radiation.
func stop_run() -> void:
	run_active = false
	paused = true
	state.is_outside = false


func reset_game() -> void:
	new_game()


func set_speed(value: Speed) -> void:
	speed = value


func set_paused(value: bool) -> void:
	paused = value


func is_paused() -> bool:
	return paused


## Adopts a restored state as the current run. The clock and the accumulator
## stay frozen until the playable scene enables the clock explicitly, so a load
## never consumes ticks on its own. The speed is the integer stored by the save
## file (0 = x1, 1 = x5, 2 = x10).
func load_state(restored: SimState, restored_speed: int = 0) -> void:
	if restored == null:
		return
	state = restored
	_time_accumulator = 0.0
	speed = _speed_from_value(restored_speed)
	run_active = true
	paused = true


## Maps a saved speed index to the runtime enum; unknown values fall back to x1.
func _speed_from_value(value: int) -> Speed:
	match value:
		1:
			return Speed.X5
		2:
			return Speed.X10
		_:
			return Speed.X1


## Real seconds the accumulator gains per second of wall clock.
func get_rate() -> float:
	match speed:
		Speed.X5:
			return 5.0
		Speed.X10:
			return 10.0
		_:
			return 1.0


func get_economy() -> EconomyData:
	return _economy


## Editable sheet of a machine, or null when the registry has no such id.
func get_machine_data(id: StringName) -> MachineData:
	if _machines == null:
		return null
	return _machines.get_machine(id)


## Mutable state of a machine, or null when the run has no such machine.
func get_machine_state(id: StringName) -> MachineState:
	if not state.machines.has(id):
		return null
	return state.machines[id]


## True when a repair could start right now: live run, existing data and state,
## no repair in progress, damaged machine and enough energy for the cost.
func can_start_repair(id: StringName) -> bool:
	if state.game_over:
		return false
	var data: MachineData = get_machine_data(id)
	var machine: MachineState = get_machine_state(id)
	if data == null or machine == null:
		return false
	if machine.is_repairing():
		return false
	if machine.health >= MachineState.MAX_HEALTH:
		return false
	return state.get_resource(SimState.ENERGY) >= maxf(0.0, data.repair_energy_cost)


## Charges the repair cost and queues the work divisions. The REPAIR fact is
## emitted by the tick that completes it, never here.
func start_repair(id: StringName) -> bool:
	if not can_start_repair(id):
		return false
	var data: MachineData = get_machine_data(id)
	var machine: MachineState = get_machine_state(id)
	if data == null or machine == null:
		return false
	_spend_energy(data.repair_energy_cost)
	machine.repair_ticks_total = maxi(1, data.repair_ticks)
	machine.repair_work_done = 0.0
	return true


## True while the machine has a started repair with work divisions left.
func is_repairing(id: StringName) -> bool:
	var machine: MachineState = get_machine_state(id)
	if machine == null:
		return false
	return machine.is_repairing()


## Completed fraction of the repair in progress, 0.0 when there is none.
func repair_progress(id: StringName) -> float:
	var machine: MachineState = get_machine_state(id)
	if machine == null or machine.repair_ticks_total <= 0:
		return 0.0
	if not machine.is_repairing():
		return 0.0
	return clampf(
		machine.repair_work_done / float(machine.repair_ticks_total), 0.0, 1.0
	)


## True when the upgrade could be applied right now: live run, existing data,
## state and upgrade, healthy machine, not already applied and enough energy.
func can_apply_upgrade(id: StringName, upgrade_id: StringName) -> bool:
	if state.game_over:
		return false
	var data: MachineData = get_machine_data(id)
	var machine: MachineState = get_machine_state(id)
	if data == null or machine == null:
		return false
	var upgrade: UpgradeData = data.get_upgrade(upgrade_id)
	if upgrade == null:
		return false
	if not data.supports_effect(upgrade.effect_stat):
		return false
	if machine.is_broken():
		return false
	if machine.applied_upgrades.has(upgrade_id):
		return false
	return state.get_resource(SimState.ENERGY) >= maxf(0.0, upgrade.energy_cost)


## Charges the upgrade, records it as applied and lands its additive effect.
## Emits exactly one UPGRADE fact with the machine and the upgrade ids.
func apply_upgrade(id: StringName, upgrade_id: StringName) -> bool:
	if not can_apply_upgrade(id, upgrade_id):
		return false
	var data: MachineData = get_machine_data(id)
	var machine: MachineState = get_machine_state(id)
	if data == null or machine == null:
		return false
	var upgrade: UpgradeData = data.get_upgrade(upgrade_id)
	if upgrade == null:
		return false
	_spend_energy(upgrade.energy_cost)
	machine.applied_upgrades.append(upgrade.id)
	machine.upgrade_level += 1
	_apply_upgrade_effect(machine, upgrade)
	var payload: Dictionary[Variant, Variant] = {}
	payload[&"machine"] = id
	payload[&"upgrade"] = upgrade.id
	EventLog.log_entry(LogEntry.new(LogEntry.Type.UPGRADE, state.tick, payload))
	return true


## Lands the additive delta of one upgrade on its declared statistic.
func _apply_upgrade_effect(machine: MachineState, upgrade: UpgradeData) -> void:
	match upgrade.effect_stat:
		UpgradeData.EffectStat.POWER_DRAW:
			machine.power_delta += upgrade.delta
		UpgradeData.EffectStat.DEGRADATION:
			machine.degradation_delta += upgrade.delta
		UpgradeData.EffectStat.SOLAR_OUTPUT:
			_add_output_delta(machine, SimState.ENERGY, upgrade.delta)
		UpgradeData.EffectStat.FOOD_OUTPUT:
			_add_output_delta(machine, SimState.FOOD, upgrade.delta)
		UpgradeData.EffectStat.OXYGEN_OUTPUT:
			_add_output_delta(machine, SimState.OXYGEN, upgrade.delta)
		UpgradeData.EffectStat.WATER_OUTPUT:
			_add_output_delta(machine, SimState.WATER, upgrade.delta)
		UpgradeData.EffectStat.REPAIR_SPEED:
			state.player.repair_speed_multiplier = maxf(
				0.1, state.player.repair_speed_multiplier + upgrade.delta
			)
		UpgradeData.EffectStat.MOVE_SPEED:
			state.player.move_speed_multiplier = maxf(
				0.1, state.player.move_speed_multiplier + upgrade.delta
			)
		UpgradeData.EffectStat.HUNGER_MAX:
			state.player.max_hunger = maxf(1.0, state.player.max_hunger + upgrade.delta)
			state.hunger = clampf(
				state.hunger + upgrade.delta, 0.0, state.player.max_hunger
			)
		UpgradeData.EffectStat.THIRST_MAX:
			state.player.max_thirst = maxf(1.0, state.player.max_thirst + upgrade.delta)
			state.thirst = clampf(
				state.thirst + upgrade.delta, 0.0, state.player.max_thirst
			)


## Adds delta to the machine production of one resource, creating the entry.
func _add_output_delta(
	machine: MachineState, resource_id: StringName, delta: float
) -> void:
	machine.output_deltas[resource_id] = (
		machine.output_deltas.get(resource_id, 0.0) + delta
	)


## Removes energy, never letting the pool go below zero and never adding energy
## because of a negative cost.
func _spend_energy(amount: float) -> void:
	state.set_resource(
		SimState.ENERGY,
		maxf(0.0, state.get_resource(SimState.ENERGY) - maxf(0.0, amount))
	)
func get_events() -> EventData:
	return _events


## Loads and validates the economy database. A missing or wrongly typed resource
## never breaks the boot: it warns and falls back to an empty database.
func _load_economy() -> EconomyData:
	var loaded: Resource = ResourceLoader.load(ECONOMY_PATH)
	if loaded == null:
		push_warning("GameSim: could not load economy at " + ECONOMY_PATH)
		return EconomyData.new()
	if not loaded is EconomyData:
		push_warning("GameSim: " + ECONOMY_PATH + " is not an EconomyData resource")
		return EconomyData.new()
	var economy: EconomyData = loaded
	for message: String in economy.validate_rows():
		push_warning("GameSim: economy row problem: " + message)
	# Rows are never mutated: an out-of-range value falls back at read time.
	return economy


## Loads and validates the machine registry. A missing or wrongly typed
## resource never breaks the boot: it warns and falls back to an empty database.
func _load_machines() -> MachineDatabase:
	var loaded: Resource = ResourceLoader.load(MACHINES_PATH)
	if loaded == null:
		push_warning("GameSim: could not load machine database at " + MACHINES_PATH)
		return MachineDatabase.new()
	if not loaded is MachineDatabase:
		push_warning("GameSim: " + MACHINES_PATH + " is not a MachineDatabase resource")
		return MachineDatabase.new()
	var database: MachineDatabase = loaded
	for message: String in database.validate():
		push_warning("GameSim: machine database problem: " + message)
	_warn_machine_coverage(database)
	return database


## Warns about sheets outside the frozen core ids and core ids without a sheet.
func _warn_machine_coverage(database: MachineDatabase) -> void:
	var covered: Dictionary[StringName, bool] = {}
	for machine: MachineData in database.machines:
		if machine == null:
			continue
		covered[machine.id] = true
		if not SimState.MACHINE_IDS.has(machine.id):
			push_warning(
				"GameSim: machine '%s' is not one of the core machine ids"
				% String(machine.id)
			)
	for id: StringName in SimState.MACHINE_IDS:
		if not covered.has(id):
			push_warning(
				"GameSim: machine '%s' has no sheet in %s" % [String(id), MACHINES_PATH]
			)
## Loads and validates the event registry. A missing or invalid registry leaves
## an empty EventData so the simulation still boots with events disabled.
func _load_events() -> EventData:
	var loaded: Resource = ResourceLoader.load(EVENTS_PATH)
	if loaded == null:
		push_warning("GameSim: could not load events at " + EVENTS_PATH)
		return EventData.new()
	if not loaded is EventData:
		push_warning("GameSim: " + EVENTS_PATH + " is not an EventData resource")
		return EventData.new()
	var events: EventData = loaded
	for message: String in events.validate_rows():
		push_warning("GameSim: event row problem: " + message)
	return events
