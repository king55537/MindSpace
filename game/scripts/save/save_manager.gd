class_name SaveManager
extends RefCounted

## Single-slot game persistence for the current run.
##
## The simulation and the ledger stay as runtime objects: this class is the only
## place that knows the JSON schema. It does not touch the autoloads directly:
## the caller passes the live state in and applies the loaded state back, so the
## class can be exercised without a running scene tree.
##
## A save is written to a temporary file and renamed over the slot, so an
## interrupted write never truncates the previous save. The file is validated
## completely before it is handed back as a pending load.
##
## No autoload on purpose: callers use the static API, like [WorldStore].

const DEFAULT_SAVE_PATH: String = "user://saves/savegame.json"
## Suffix of the temporary file used to replace the save file atomically.
const TEMP_SUFFIX: String = ".tmp"
## Suffix of the backup kept when the save file cannot be parsed.
const BACKUP_SUFFIX: String = ".bak"
## Schema version stored in the file. Older or newer files are rejected.
const SAVE_VERSION: int = 1
## Scene the "save and exit" action returns to.
const WELCOME_SCENE: String = "res://scenes/welcome/welcome.tscn"

## Slot used by the next write and read. Tests point it to a temporary file.
static var save_path: String = DEFAULT_SAVE_PATH
## Human-readable message from the last failed operation, or "" when it worked.
static var last_error: String = ""

## Sections that a saved state must carry to be restorable.
const REQUIRED_STATE_KEYS: Array[String] = ["tick", "resources", "machines", "player"]
## Resource ids written to and read from the save.
const RESOURCE_IDS: Array[StringName] = [
	SimState.OXYGEN, SimState.WATER, SimState.FOOD, SimState.ENERGY,
]

static var _has_pending: bool = false
static var _pending: Dictionary[String, Variant] = {}
static var _pending_state: SimState = null
static var _pending_ledger: Array[LogEntry] = []


## True when a save file exists at the current slot, even if it is unreadable.
static func has_save() -> bool:
	return FileAccess.file_exists(save_path)


## Saves a live run. The caller supplies the state, the ledger and the scene
## data; the file is written atomically. Returns false (and sets
## [member last_error]) when the data is incomplete or the file cannot be
## written.
static func save_run(
	state: SimState,
	entries: Array[LogEntry],
	scene_path: String,
	world: World,
	player_position: Vector2,
	speed: int
) -> bool:
	last_error = ""
	if state == null:
		last_error = "There is no game state to save."
		return false
	if scene_path.is_empty():
		last_error = "The current scene has no file path."
		return false

	var world_data: Dictionary[String, Variant] = {}
	if world != null:
		world_data["id"] = world.id
		world_data["name"] = world.name

	var player_data: Dictionary[String, Variant] = {
		"x": player_position.x,
		"y": player_position.y,
	}

	var data: Dictionary[String, Variant] = {
		"version": SAVE_VERSION,
		"saved_at": Time.get_datetime_string_from_system(true),
		"scene": scene_path,
		"world": world_data,
		"player_position": player_data,
		"speed": speed,
		"state": _state_to_dictionary(state),
		"ledger": _ledger_to_array(entries),
	}
	return _write(data)


## Reads and validates the save file into a pending load. Nothing is applied
## until the caller takes the pending state, so every error leaves the live run
## untouched. Event rows are resolved against [param events].
static func request_load(events: EventData) -> bool:
	last_error = ""
	_clear_pending()
	if not FileAccess.file_exists(save_path):
		last_error = "There is no saved game."
		return false

	var file: FileAccess = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		last_error = "The saved game could not be opened (error %d)." % FileAccess.get_open_error()
		return false
	var raw: String = file.get_as_text()
	file.close()

	var parsed: Variant = null
	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(raw)
	if parse_error == OK:
		parsed = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		_quarantine_save()
		last_error = "The saved game was unreadable and was kept as a backup."
		return false

	var data: Dictionary[String, Variant] = _as_dictionary(parsed)
	var version: int = _as_int(data.get("version"), -1)
	if version != SAVE_VERSION:
		last_error = "The saved game uses an unsupported version (%d)." % version
		return false

	var state_data: Dictionary[String, Variant] = _as_dictionary(data.get("state"))
	var state: SimState = _state_from_dictionary(state_data, events)
	if state == null:
		last_error = "The saved game has no valid simulation state."
		return false

	var ledger: Array[LogEntry] = []
	var ledger_value: Variant = data.get("ledger")
	if typeof(ledger_value) != TYPE_ARRAY and ledger_value != null:
		last_error = "The saved game has an invalid ledger."
		return false
	if typeof(ledger_value) == TYPE_ARRAY:
		ledger = _ledger_from_array(ledger_value)

	_pending = data
	_pending_state = state
	_pending_ledger = ledger
	_has_pending = true
	return true


static func has_pending_load() -> bool:
	return _has_pending and _pending_state != null


## Restored state of the pending load. The caller applies it with
## `GameSim.load_state()` and restores the ledger with `EventLog.restore()`.
static func get_pending_state() -> SimState:
	return _pending_state


## Restored ledger of the pending load, in chronological order.
static func get_pending_ledger() -> Array[LogEntry]:
	return _pending_ledger


## Speed stored in the pending save, as the integer used by [GameSim.Speed].
static func get_pending_speed() -> int:
	return _as_int(_pending.get("speed"), 0)


## Scene stored in the pending save, or "" when there is none.
static func get_pending_scene_path() -> String:
	return _as_string(_pending.get("scene"), "")


## Astronaut position stored in the pending save. Returns Vector2.ZERO when the
## save carried no position.
static func get_pending_player_position() -> Vector2:
	var position_data: Dictionary[String, Variant] = _as_dictionary(
		_pending.get("player_position")
	)
	if position_data.is_empty():
		return Vector2.ZERO
	return Vector2(
		_as_float(position_data.get("x"), 0.0),
		_as_float(position_data.get("y"), 0.0)
	)


## World stored in the pending save, or null when there is none.
static func get_pending_world() -> World:
	var world_data: Dictionary[String, Variant] = _as_dictionary(_pending.get("world"))
	if world_data.is_empty():
		return null
	var world: World = World.new()
	world.id = _as_string(world_data.get("id"), "")
	world.name = _as_string(world_data.get("name"), "")
	if world.name.is_empty():
		return null
	return world


static func clear_pending() -> void:
	_clear_pending()


static func get_last_error() -> String:
	return last_error


static func _clear_pending() -> void:
	_has_pending = false
	_pending = {}
	_pending_state = null
	_pending_ledger = []


# ---------------------------------------------------------------- write

## Writes the slot atomically: a complete temporary file replaces the save file
## in one rename, so a failed write cannot truncate the previous save.
static func _write(data: Dictionary[String, Variant]) -> bool:
	var base_dir: DirAccess = DirAccess.open("user://")
	if base_dir == null:
		last_error = "The save folder could not be opened."
		return false
	if not base_dir.dir_exists("saves"):
		var make_error: Error = base_dir.make_dir("saves")
		if make_error != OK and make_error != ERR_ALREADY_EXISTS:
			last_error = "The save folder could not be created (error %d)." % make_error
			return false

	var temp_path: String = save_path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		last_error = "The save file could not be written (error %d)." % FileAccess.get_open_error()
		return false
	file.store_string(JSON.stringify(data, "\t"))
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_path)
		last_error = "The save file could not be written (error %d)." % write_error
		return false

	var rename_error: Error = DirAccess.rename_absolute(temp_path, save_path)
	if rename_error != OK:
		DirAccess.remove_absolute(temp_path)
		last_error = "The save file could not be replaced (error %d)." % rename_error
		return false
	return true


## Moves an unreadable save file to the backup path so the next save never
## overwrites it silently.
static func _quarantine_save() -> void:
	var backup_path: String = save_path + BACKUP_SUFFIX
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	var error: Error = DirAccess.rename_absolute(save_path, backup_path)
	if error != OK:
		push_warning("SaveManager: could not keep a backup of %s" % save_path)


# ---------------------------------------------------------------- state

static func _state_to_dictionary(state: SimState) -> Dictionary[String, Variant]:
	var resources: Dictionary[String, Variant] = {}
	for id: StringName in state.resources.keys():
		resources[String(id)] = state.resources[id]

	var machines: Dictionary[String, Variant] = {}
	for id: StringName in state.machines.keys():
		var machine: MachineState = state.machines[id]
		if machine == null:
			continue
		machines[String(id)] = _machine_to_dictionary(machine)

	var active_events: Array[Variant] = []
	for event: ActiveEvent in state.active_events:
		if event == null or event.row == null:
			continue
		active_events.append({
			"row": String(event.row.id),
			"started_tick": event.started_tick,
		})

	var pending_events: Array[Variant] = []
	for event: PendingEvent in state.pending_events:
		if event == null or event.row == null:
			continue
		pending_events.append({
			"row": String(event.row.id),
			"not_before_tick": event.not_before_tick,
		})

	var result: Dictionary[String, Variant] = {
		"tick": state.tick,
		"resources": resources,
		"health": state.health,
		"max_health": state.max_health,
		"radiation_dose": state.radiation_dose,
		"peak_radiation": state.peak_radiation,
		"hunger": state.hunger,
		"thirst": state.thirst,
		"suit_reserve_ticks": state.suit_reserve_ticks,
		"is_outside": state.is_outside,
		"machines": machines,
		"player": _player_to_dictionary(state.player),
		"blackout_active": state.blackout_active,
		"game_over": state.game_over,
		"death_cause": String(state.death_cause),
		"event_cursor": state.event_cursor,
		"active_events": active_events,
		"pending_events": pending_events,
		"comms_blocked": state.comms_blocked,
		"run_seed": state.run_seed,
	}
	return result


static func _machine_to_dictionary(machine: MachineState) -> Dictionary[String, Variant]:
	var applied: Array[Variant] = []
	for upgrade_id: StringName in machine.applied_upgrades:
		applied.append(String(upgrade_id))

	var output_deltas: Dictionary[String, Variant] = {}
	for resource_id: StringName in machine.output_deltas.keys():
		output_deltas[String(resource_id)] = machine.output_deltas[resource_id]

	var result: Dictionary[String, Variant] = {
		"health": machine.health,
		"powered": machine.powered,
		"upgrade_level": machine.upgrade_level,
		"repair_ticks_total": machine.repair_ticks_total,
		"repair_work_done": machine.repair_work_done,
		"applied_upgrades": applied,
		"power_delta": machine.power_delta,
		"degradation_delta": machine.degradation_delta,
		"output_deltas": output_deltas,
	}
	return result


static func _player_to_dictionary(player: PlayerStats) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {
		"repair_speed_multiplier": player.repair_speed_multiplier,
		"move_speed_multiplier": player.move_speed_multiplier,
		"max_hunger": player.max_hunger,
		"max_thirst": player.max_thirst,
	}
	return result


## Builds a state from the saved dictionary, or null when a required section is
## missing or malformed. The caller checks the result before mutating anything.
static func _state_from_dictionary(
	data: Dictionary[String, Variant],
	events: EventData
) -> SimState:
	if data.is_empty():
		return null
	for key: String in REQUIRED_STATE_KEYS:
		if not data.has(key):
			return null

	var resources: Dictionary[String, Variant] = _as_dictionary(data.get("resources"))
	var machines: Dictionary[String, Variant] = _as_dictionary(data.get("machines"))
	var player_data: Dictionary[String, Variant] = _as_dictionary(data.get("player"))
	for id: StringName in SimState.MACHINE_IDS:
		if not machines.has(String(id)):
			return null

	var state: SimState = SimState.new()
	state.tick = maxi(0, _as_int(data.get("tick"), 0))
	for id: StringName in RESOURCE_IDS:
		state.resources[id] = _as_float(resources.get(String(id)), 0.0)

	state.health = maxf(0.0, _as_float(data.get("health"), 0.0))
	state.max_health = maxf(1.0, _as_float(data.get("max_health"), 1.0))
	state.radiation_dose = clampf(_as_float(data.get("radiation_dose"), 0.0), 0.0, 100.0)
	state.peak_radiation = maxf(0.0, _as_float(data.get("peak_radiation"), 0.0))
	state.hunger = maxf(0.0, _as_float(data.get("hunger"), 0.0))
	state.thirst = maxf(0.0, _as_float(data.get("thirst"), 0.0))
	state.suit_reserve_ticks = maxi(0, _as_int(data.get("suit_reserve_ticks"), 0))
	state.is_outside = _as_bool(data.get("is_outside"), false)
	state.blackout_active = _as_bool(data.get("blackout_active"), false)
	state.game_over = _as_bool(data.get("game_over"), false)
	state.death_cause = StringName(_as_string(data.get("death_cause"), ""))
	state.event_cursor = maxi(0, _as_int(data.get("event_cursor"), 0))
	state.comms_blocked = _as_bool(data.get("comms_blocked"), false)
	state.run_seed = _as_int(data.get("run_seed"), SimState.DEFAULT_RUN_SEED)

	state.player.repair_speed_multiplier = maxf(
		0.1, _as_float(player_data.get("repair_speed_multiplier"), 1.0)
	)
	state.player.move_speed_multiplier = maxf(
		0.1, _as_float(player_data.get("move_speed_multiplier"), 1.0)
	)
	state.player.max_hunger = maxf(1.0, _as_float(player_data.get("max_hunger"), 100.0))
	state.player.max_thirst = maxf(1.0, _as_float(player_data.get("max_thirst"), 100.0))

	for id: StringName in SimState.MACHINE_IDS:
		var machine_data: Dictionary[String, Variant] = _as_dictionary(machines.get(String(id)))
		state.machines[id] = _machine_from_dictionary(id, machine_data)

	state.active_events = _active_events_from_array(data.get("active_events"), events)
	state.pending_events = _pending_events_from_array(data.get("pending_events"), events)
	return state


static func _machine_from_dictionary(
	id: StringName,
	data: Dictionary[String, Variant]
) -> MachineState:
	var machine: MachineState = MachineState.new()
	machine.id = id
	machine.health = clampf(
		_as_float(data.get("health"), MachineState.MAX_HEALTH),
		0.0,
		MachineState.MAX_HEALTH
	)
	machine.powered = _as_bool(data.get("powered"), true)
	machine.upgrade_level = maxi(0, _as_int(data.get("upgrade_level"), 0))
	machine.repair_ticks_total = maxi(0, _as_int(data.get("repair_ticks_total"), 0))
	machine.repair_work_done = maxf(0.0, _as_float(data.get("repair_work_done"), 0.0))
	machine.applied_upgrades = _as_string_name_array(data.get("applied_upgrades"))
	machine.power_delta = _as_float(data.get("power_delta"), 0.0)
	machine.degradation_delta = _as_float(data.get("degradation_delta"), 0.0)
	machine.output_deltas = _as_string_float_dictionary(data.get("output_deltas"))
	return machine


static func _active_events_from_array(value: Variant, events: EventData) -> Array[ActiveEvent]:
	var result: Array[ActiveEvent] = []
	if typeof(value) != TYPE_ARRAY or events == null:
		return result
	var raw_entries: Array[Variant] = value
	for entry: Variant in raw_entries:
		var entry_data: Dictionary[String, Variant] = _as_dictionary(entry)
		var row_id: StringName = StringName(_as_string(entry_data.get("row"), ""))
		var row: EventRow = events.get_row(row_id)
		if row == null:
			continue
		var started_tick: int = _as_int(entry_data.get("started_tick"), 0)
		result.append(ActiveEvent.new(row, started_tick))
	return result


static func _pending_events_from_array(value: Variant, events: EventData) -> Array[PendingEvent]:
	var result: Array[PendingEvent] = []
	if typeof(value) != TYPE_ARRAY or events == null:
		return result
	var raw_entries: Array[Variant] = value
	for entry: Variant in raw_entries:
		var entry_data: Dictionary[String, Variant] = _as_dictionary(entry)
		var row_id: StringName = StringName(_as_string(entry_data.get("row"), ""))
		var row: EventRow = events.get_row(row_id)
		if row == null:
			continue
		var not_before_tick: int = _as_int(entry_data.get("not_before_tick"), 0)
		result.append(PendingEvent.new(row, not_before_tick))
	return result


# ---------------------------------------------------------------- ledger

static func _ledger_to_array(entries: Array[LogEntry]) -> Array[Variant]:
	var result: Array[Variant] = []
	for entry: LogEntry in entries:
		var payload: Dictionary[String, Variant] = {}
		for key: Variant in entry.payload.keys():
			payload[str(key)] = _to_json_value(entry.payload[key])
		result.append({
			"type": int(entry.type),
			"tick": entry.tick,
			"payload": payload,
		})
	return result


static func _ledger_from_array(value: Variant) -> Array[LogEntry]:
	var result: Array[LogEntry] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var raw_entries: Array[Variant] = value
	for entry: Variant in raw_entries:
		var entry_data: Dictionary[String, Variant] = _as_dictionary(entry)
		var type_value: int = _as_int(entry_data.get("type"), -1)
		if not LogEntry.is_valid_type(type_value):
			continue
		var payload_data: Dictionary[String, Variant] = _as_dictionary(entry_data.get("payload"))
		var payload: Dictionary[Variant, Variant] = {}
		for key: String in payload_data.keys():
			payload[StringName(key)] = _from_json_value(payload_data[key])
		if not LogEntry.is_plain_payload(payload):
			continue
		result.append(LogEntry.new(type_value, _as_int(entry_data.get("tick"), 0), payload))
	return result


## Converts runtime payload values into JSON-safe values: StringName keys and
## StringName values become plain strings, recursively.
static func _to_json_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value)
		TYPE_DICTIONARY:
			var raw_dictionary: Dictionary[String, Variant] = _as_dictionary(value)
			var converted: Dictionary[String, Variant] = {}
			for key: String in raw_dictionary.keys():
				converted[key] = _to_json_value(raw_dictionary[key])
			return converted
		TYPE_ARRAY:
			var raw_array: Array[Variant] = value
			var converted_array: Array[Variant] = []
			for item: Variant in raw_array:
				converted_array.append(_to_json_value(item))
			return converted_array
		_:
			return value


## Converts JSON payload values back into the runtime shape: StringName keys and
## nested dictionaries and arrays.
static func _from_json_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var raw_dictionary: Dictionary[String, Variant] = _as_dictionary(value)
			var converted: Dictionary[Variant, Variant] = {}
			for key: String in raw_dictionary.keys():
				converted[StringName(key)] = _from_json_value(raw_dictionary[key])
			return converted
		TYPE_ARRAY:
			var raw_array: Array[Variant] = value
			var converted_array: Array[Variant] = []
			for item: Variant in raw_array:
				converted_array.append(_from_json_value(item))
			return converted_array
		_:
			return value


# ---------------------------------------------------------------- helpers

static func _as_dictionary(value: Variant) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {}
	if typeof(value) != TYPE_DICTIONARY:
		return result
	var raw: Dictionary[Variant, Variant] = value
	for key: Variant in raw.keys():
		result[str(key)] = raw[key]
	return result


static func _as_float(value: Variant, fallback: float) -> float:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			return float(value)
		_:
			return fallback


static func _as_int(value: Variant, fallback: int) -> int:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			return int(value)
		_:
			return fallback


static func _as_bool(value: Variant, fallback: bool) -> bool:
	if typeof(value) != TYPE_BOOL:
		return fallback
	return bool(value)


static func _as_string(value: Variant, fallback: String) -> String:
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			return str(value)
		_:
			return fallback


static func _as_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY:
		return result
	var raw: Array[Variant] = value
	for item: Variant in raw:
		var text: String = _as_string(item, "")
		if not text.is_empty():
			result.append(StringName(text))
	return result


static func _as_string_float_dictionary(value: Variant) -> Dictionary[StringName, float]:
	var result: Dictionary[StringName, float] = {}
	var raw: Dictionary[String, Variant] = _as_dictionary(value)
	for key: String in raw.keys():
		result[StringName(key)] = _as_float(raw[key], 0.0)
	return result
