extends SceneTree

## Smoke test for SaveManager (task 2.3 of add-pause-menu).
##
## Builds a known run state, saves it to a dedicated slot, loads it back and
## compares every restorable field. Also checks the error paths: missing slot,
## corrupt file quarantined as .bak, and unsupported schema version.
##
## Run: godot --headless --path game --script res://scripts/dev/save_smoke.gd
## Exit code 0 when every check passes, 1 otherwise.

const ECONOMY_PATH: String = "res://databases/economy.tres"
const MACHINES_PATH: String = "res://databases/machines.tres"
const EVENTS_PATH: String = "res://databases/events.tres"
const SLOT_PATH: String = "user://saves/savegame_smoke.json"

var _checks: int = 0
var _failures: int = 0


func _init() -> void:
	var economy: EconomyData = ResourceLoader.load(ECONOMY_PATH) as EconomyData
	var machines: MachineDatabase = ResourceLoader.load(MACHINES_PATH) as MachineDatabase
	var events: EventData = ResourceLoader.load(EVENTS_PATH) as EventData
	if economy == null or machines == null or events == null:
		push_error("save_smoke: cannot load the databases")
		quit(1)
		return

	SaveManager.save_path = SLOT_PATH
	_cleanup_slot()

	_check_round_trip(economy, events)
	_check_missing_slot(events)
	_check_corrupt_slot(events)
	_check_unsupported_version(events)

	_cleanup_slot()
	SaveManager.save_path = SaveManager.DEFAULT_SAVE_PATH
	print("save_smoke: %d checks, %s" % [_checks, "FAIL" if _failures > 0 else "OK"])
	quit(1 if _failures > 0 else 0)


## Saves a fully populated run and compares the restored values.
func _check_round_trip(economy: EconomyData, events: EventData) -> void:
	var state: SimState = SimState.new()
	state.reset_from_economy(economy)
	state.tick = 42
	state.resources[SimState.OXYGEN] = 3.5
	state.resources[SimState.WATER] = 4.25
	state.resources[SimState.FOOD] = 5.75
	state.resources[SimState.ENERGY] = 6.5
	state.health = 77.5
	state.radiation_dose = 12.5
	state.peak_radiation = 13.25
	state.hunger = 66.5
	state.thirst = 55.5
	state.suit_reserve_ticks = 45
	state.is_outside = true
	state.blackout_active = true
	state.event_cursor = 7
	state.comms_blocked = true
	state.run_seed = 12345
	state.player.repair_speed_multiplier = 1.5
	state.player.move_speed_multiplier = 1.2
	state.player.max_hunger = 120.0
	state.player.max_thirst = 110.0

	var lights: MachineState = state.machines[SimState.MACHINE_LIGHTS]
	lights.health = 37.5
	lights.powered = false
	lights.upgrade_level = 2
	lights.repair_ticks_total = 3
	lights.repair_work_done = 1.0
	lights.applied_upgrades.append(&"smoke_upgrade")
	lights.power_delta = -0.5
	lights.degradation_delta = 0.25
	lights.output_deltas[SimState.FOOD] = 1.5

	var row: EventRow = null
	if not events.rows.is_empty():
		row = events.rows[0]
		state.active_events.append(ActiveEvent.new(row, 30))
		state.pending_events.append(PendingEvent.new(row, 50))

	var entries: Array[LogEntry] = []
	var report_payload: Dictionary[Variant, Variant] = {
		&"source": &"smoke",
		&"count": 2,
		&"nested": {&"depth": 1.5},
	}
	entries.append(LogEntry.new(LogEntry.Type.REPORT_SENT, 40, report_payload))
	entries.append(LogEntry.new(LogEntry.Type.SUBMISSION_COMPLETED, 41, {}))
	var peak_payload: Dictionary[Variant, Variant] = {&"dose": 13.25}
	entries.append(LogEntry.new(LogEntry.Type.RADIATION_PEAK, 42, peak_payload))

	var world: World = World.new()
	world.id = "smoke-world"
	world.name = "Smoke World"
	var saved: bool = SaveManager.save_run(
		state,
		entries,
		"res://scenes/base/base.tscn",
		world,
		Vector2(320.0, 240.0),
		2
	)
	_check(saved, "save succeeds")
	if not saved:
		push_error("save_smoke: " + SaveManager.get_last_error())
		return

	var loaded: bool = SaveManager.request_load(events)
	_check(loaded, "load succeeds")
	if not loaded:
		push_error("save_smoke: " + SaveManager.get_last_error())
		return

	var restored: SimState = SaveManager.get_pending_state()
	_check(restored != null, "pending state exists")
	if restored == null:
		return
	_check(restored.tick == 42, "tick restored")
	_check(_close(restored.resources[SimState.OXYGEN], 3.5), "oxygen restored")
	_check(_close(restored.resources[SimState.WATER], 4.25), "water restored")
	_check(_close(restored.resources[SimState.FOOD], 5.75), "food restored")
	_check(_close(restored.resources[SimState.ENERGY], 6.5), "energy restored")
	_check(_close(restored.health, 77.5), "health restored")
	_check(_close(restored.radiation_dose, 12.5), "dose restored")
	_check(_close(restored.peak_radiation, 13.25), "peak radiation restored")
	_check(_close(restored.hunger, 66.5), "hunger restored")
	_check(_close(restored.thirst, 55.5), "thirst restored")
	_check(restored.suit_reserve_ticks == 45, "suit reserve restored")
	_check(restored.is_outside, "outside flag restored")
	_check(restored.blackout_active, "blackout restored")
	_check(restored.event_cursor == 7, "event cursor restored")
	_check(restored.comms_blocked, "comms block restored")
	_check(restored.run_seed == 12345, "run seed restored")
	_check(_close(restored.player.repair_speed_multiplier, 1.5), "repair multiplier restored")
	_check(_close(restored.player.move_speed_multiplier, 1.2), "move multiplier restored")
	_check(_close(restored.player.max_hunger, 120.0), "max hunger restored")
	_check(_close(restored.player.max_thirst, 110.0), "max thirst restored")

	var restored_lights: MachineState = restored.machines[SimState.MACHINE_LIGHTS]
	_check(_close(restored_lights.health, 37.5), "machine health restored")
	_check(not restored_lights.powered, "machine power restored")
	_check(restored_lights.upgrade_level == 2, "machine upgrade level restored")
	_check(restored_lights.repair_ticks_total == 3, "machine repair total restored")
	_check(_close(restored_lights.repair_work_done, 1.0), "machine repair work restored")
	_check(restored_lights.applied_upgrades.has(&"smoke_upgrade"), "machine upgrades restored")
	_check(_close(restored_lights.power_delta, -0.5), "machine power delta restored")
	_check(_close(restored_lights.degradation_delta, 0.25), "machine degradation restored")
	_check(_close(restored_lights.output_deltas.get(SimState.FOOD, 0.0), 1.5), "machine output restored")

	_check(restored.active_events.size() == 1, "active event restored")
	if restored.active_events.size() == 1 and row != null:
		_check(restored.active_events[0].row.id == row.id, "active event row restored")
		_check(restored.active_events[0].started_tick == 30, "active event tick restored")
	_check(restored.pending_events.size() == 1, "pending event restored")
	if restored.pending_events.size() == 1:
		_check(restored.pending_events[0].not_before_tick == 50, "pending event tick restored")

	var ledger: Array[LogEntry] = SaveManager.get_pending_ledger()
	_check(ledger.size() == 3, "ledger size restored")
	if ledger.size() == 3:
		_check(ledger[0].type == LogEntry.Type.REPORT_SENT, "ledger type restored")
		_check(ledger[0].tick == 40, "ledger tick restored")
		var source: Variant = ledger[0].payload.get(&"source")
		var source_type: int = typeof(source)
		_check(
			(source_type == TYPE_STRING or source_type == TYPE_STRING_NAME)
			and str(source) == "smoke",
			"payload string restored"
		)
		var nested: Variant = ledger[0].payload.get(&"nested")
		if typeof(nested) == TYPE_DICTIONARY:
			var nested_dictionary: Dictionary[Variant, Variant] = nested
			_check(_close(float(nested_dictionary.get(&"depth", 0.0)), 1.5), "payload nested value restored")
		else:
			_check(false, "payload nested dictionary restored")
		_check(ledger[2].type == LogEntry.Type.RADIATION_PEAK, "ledger peak restored")
		_check(_close(float(ledger[2].payload.get(&"dose", 0.0)), 13.25), "payload dose restored")

	_check(SaveManager.get_pending_speed() == 2, "speed restored")
	_check(SaveManager.get_pending_scene_path() == "res://scenes/base/base.tscn", "scene restored")
	var position: Vector2 = SaveManager.get_pending_player_position()
	_check(_close(position.x, 320.0) and _close(position.y, 240.0), "player position restored")
	var restored_world: World = SaveManager.get_pending_world()
	_check(restored_world != null and restored_world.name == "Smoke World", "world restored")
	SaveManager.clear_pending()
	_check(not SaveManager.has_pending_load(), "pending load cleared")


func _check_missing_slot(events: EventData) -> void:
	_cleanup_slot()
	_check(not SaveManager.request_load(events), "missing slot fails")
	_check(not SaveManager.get_last_error().is_empty(), "missing slot reports an error")
	_check(not SaveManager.has_pending_load(), "missing slot leaves no pending state")


func _check_corrupt_slot(events: EventData) -> void:
	var file: FileAccess = FileAccess.open(SLOT_PATH, FileAccess.WRITE)
	if file == null:
		_check(false, "corrupt slot fixture")
		return
	file.store_string("{ not valid json")
	file.close()
	_check(not SaveManager.request_load(events), "corrupt slot fails")
	_check(FileAccess.file_exists(SLOT_PATH + SaveManager.BACKUP_SUFFIX), "corrupt slot kept as backup")
	_check(not SaveManager.has_pending_load(), "corrupt slot leaves no pending state")
	_cleanup_slot()


func _check_unsupported_version(events: EventData) -> void:
	var file: FileAccess = FileAccess.open(SLOT_PATH, FileAccess.WRITE)
	if file == null:
		_check(false, "version slot fixture")
		return
	file.store_string(JSON.stringify({"version": SaveManager.SAVE_VERSION + 1}))
	file.close()
	_check(not SaveManager.request_load(events), "unsupported version fails")
	_check(not SaveManager.get_last_error().is_empty(), "unsupported version reports an error")
	_check(not SaveManager.has_pending_load(), "unsupported version leaves no pending state")
	_cleanup_slot()


func _close(value: float, expected: float) -> bool:
	return is_equal_approx(value, expected)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("save_smoke: FAIL - " + message)


func _cleanup_slot() -> void:
	for path: String in [
		SLOT_PATH,
		SLOT_PATH + SaveManager.TEMP_SUFFIX,
		SLOT_PATH + SaveManager.BACKUP_SUFFIX,
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
