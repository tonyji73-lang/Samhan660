extends RefCounted
## Text only: this catalog never enables a faction or changes a campaign.

const DATA_PATH := "res://ui/faction_declaration_v1/declarations.json"
var _entries: Dictionary = {}


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if parsed is Dictionary:
		_entries = parsed.get("entries", {})
	else:
		push_error("Faction declarations: declarations.json could not be read.")


func find_declaration(scenario_id: String, faction_id: String) -> Dictionary:
	# These must be actual IDs or explicitly mapped IDs from the current controller.
	var entry: Dictionary = _entries.get(scenario_id + "/" + faction_id, {})
	return entry.duplicate(true)


func find_art_profile(profile_key: String) -> Dictionary:
	# Use only when the current controller already supplies this exact art key.
	for value: Variant in _entries.values():
		var entry: Dictionary = value
		if str(entry.get("profile_key", "")) == profile_key:
			return entry.duplicate(true)
	return {}
