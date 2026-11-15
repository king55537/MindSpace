extends Node

## Autoload that keeps the run's fact ledger: chronological LogEntry records
## plus aggregated counters exposed as an EvaluationSummary snapshot.
## Every read API returns defensive copies, so callers can never mutate the
## ledger through a returned value.

signal fact_logged(entry: LogEntry)

var _entries: Array[LogEntry] = []


## Appends a valid entry and emits fact_logged. Returns false (without
## appending) when the entry is null, its type is out of range or its payload
## is not plain. The ledger stores its own copy, and the emitted entry is a copy
## too, so neither the caller nor a listener can mutate a logged fact.
func log_entry(entry: LogEntry) -> bool:
	if entry == null:
		return false
	if not LogEntry.is_valid_type(entry.type):
		return false
	if not LogEntry.is_plain_payload(entry.payload):
		return false
	var stored: LogEntry = _copy_entry(entry)
	_entries.append(stored)
	fact_logged.emit(_copy_entry(stored))
	return true


## Logs every valid entry, in order, silently skipping the invalid ones.
func log_entries(entries: Array[LogEntry]) -> void:
	for entry: LogEntry in entries:
		log_entry(entry)


## Snapshot copy of the ledger; mutating the returned array or its entries does
## not change the ledger.
func get_entries() -> Array[LogEntry]:
	var result: Array[LogEntry] = []
	for entry: LogEntry in _entries:
		result.append(_copy_entry(entry))
	return result


## Copy of the entries whose type matches p_type; same isolation as get_entries.
func get_entries_by_type(p_type: LogEntry.Type) -> Array[LogEntry]:
	var result: Array[LogEntry] = []
	for entry: LogEntry in _entries:
		if entry.type == p_type:
			result.append(_copy_entry(entry))
	return result


func get_count(p_type: LogEntry.Type) -> int:
	var count: int = 0
	for entry: LogEntry in _entries:
		if entry.type == p_type:
			count += 1
	return count


func get_summary() -> EvaluationSummary:
	var summary: EvaluationSummary = EvaluationSummary.new()
	summary.reports_sent = get_count(LogEntry.Type.REPORT_SENT)
	summary.submissions_completed = get_count(LogEntry.Type.SUBMISSION_COMPLETED)
	summary.shelter_uses = get_count(LogEntry.Type.SHELTER_USED)
	summary.sols_elapsed = get_count(LogEntry.Type.SOL_COMPLETED)
	summary.peak_radiation = _peak_radiation()
	summary.final_resources = _final_resources()
	return summary


func reset() -> void:
	_entries.clear()


## Replaces the ledger with restored entries without emitting fact_logged, so a
## load does not replay every fact as if it had just happened. Invalid entries
## are skipped.
func restore(entries: Array[LogEntry]) -> void:
	_entries.clear()
	for entry: LogEntry in entries:
		if entry == null:
			continue
		if not LogEntry.is_valid_type(entry.type):
			continue
		if not LogEntry.is_plain_payload(entry.payload):
			continue
		_entries.append(_copy_entry(entry))


## Defensive copy of one entry. The payload is deep-copied as well, so nested
## arrays and dictionaries are not shared with the ledger.
func _copy_entry(entry: LogEntry) -> LogEntry:
	return LogEntry.new(entry.type, entry.tick, entry.payload.duplicate(true))


## Highest payload dose among RADIATION_PEAK entries; 0.0 when there are none
## or none of them carries a float dose.
func _peak_radiation() -> float:
	var peak: float = 0.0
	for entry: LogEntry in _entries:
		if entry.type != LogEntry.Type.RADIATION_PEAK:
			continue
		var dose: Variant = entry.payload.get(&"dose")
		if typeof(dose) != TYPE_FLOAT:
			continue
		var dose_value: float = dose
		peak = maxf(peak, dose_value)
	return peak


## Copy of the payload resources of the last GAME_OVER entry, rekeyed as
## StringName keys with float values; empty dictionary when there is none.
func _final_resources() -> Dictionary[StringName, float]:
	var result: Dictionary[StringName, float] = {}
	var last_game_over: LogEntry = null
	for entry: LogEntry in _entries:
		if entry.type == LogEntry.Type.GAME_OVER:
			last_game_over = entry
	if last_game_over == null:
		return result
	var raw: Variant = last_game_over.payload.get(&"resources")
	if typeof(raw) != TYPE_DICTIONARY:
		return result
	var raw_dict: Dictionary[Variant, Variant] = raw
	for key: Variant in raw_dict.keys():
		var key_name: StringName
		match typeof(key):
			TYPE_STRING_NAME:
				key_name = key
			TYPE_STRING:
				var plain_key: String = key
				key_name = StringName(plain_key)
			_:
				continue
		var value: Variant = raw_dict[key]
		var value_float: float
		match typeof(value):
			TYPE_FLOAT:
				value_float = value
			TYPE_INT:
				var value_int: int = value
				value_float = float(value_int)
			_:
				continue
		result[key_name] = value_float
	return result
