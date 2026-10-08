@tool
extends EditorPlugin

class RawSources:
	extends EditorExportPlugin
	var editor_helper: Variant = null

	func _get_name() -> String:
		return "SamhanRuntimeSourceHashes"

	func _export_begin(_features: PackedStringArray, _debug: bool, _path: String, _flags: int) -> void:
		# The editor helper's own plugin skips registration in headless exports.
		editor_helper = ProjectSettings.get_setting("autoload/_mcp_game_helper", null)
		ProjectSettings.set_setting("autoload/_mcp_game_helper", null)

	func _export_end() -> void:
		if editor_helper != null:
			ProjectSettings.set_setting("autoload/_mcp_game_helper", editor_helper)

	func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
		# Imported textures alone cannot satisfy FileAccess.get_sha256(original_png).
		# Keep the exact bytes for map registration and the supplied ornament pack.
		var source_area := path.begins_with("res://ui/korea_layout_v1/") or path == "res://ui/faction_selection_v1/assets/approved_korea.png" or path.begins_with("res://ui/living_city_v1/assets/ornaments/v1_3/")
		if source_area and path.get_extension() in ["png", "gdshader"]:
			add_file(path, FileAccess.get_file_as_bytes(path), false)

var exporter: RawSources

func _enter_tree() -> void:
	exporter = RawSources.new()
	add_export_plugin(exporter)

func _exit_tree() -> void:
	remove_export_plugin(exporter)
