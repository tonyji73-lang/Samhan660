extends RefCounted

# Immutable historical/game-design definitions. Numeric IDs are assigned in the
# checked-in manifest, never recomputed from a name, title, or ordering at runtime.
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/officers_v1.json"))
	return _data

static func definitions() -> Dictionary:
	return data().definitions

static func resolve(officer_ref: String) -> String:
	if definitions().has(officer_ref):
		return officer_ref
	var found: String = ""
	for id: String in definitions():
		if definitions()[id].aliases.has(officer_ref):
			if not found.is_empty():
				return ""
			found = id
	return found

static func scenario(id: String) -> Dictionary:
	return data().scenarios.get(id, {})

static func ruler_id(scenario_id: String, faction_id: String) -> String:
	for entry: Dictionary in scenario(scenario_id).get("entries", []):
		if entry.faction_id == faction_id and entry.ruler:
			return entry.officer_id
	return ""

static func legacy_database() -> Dictionary:
	var result: Dictionary = {}
	for id: String in definitions():
		var definition: Dictionary = definitions()[id]
		for label: String in definition.legacy_values:
			var row: Dictionary = definition.legacy_values[label].duplicate(true)
			row.merge(definition.base_stats, true)
			row["officer_id"] = id
			result[label] = row
	return result
