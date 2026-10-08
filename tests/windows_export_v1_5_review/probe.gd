extends SceneTree
func _initialize() -> void:
	print("EXPORT_PROBE ", OS.get_executable_path(), " USER=", OS.get_user_data_dir(), " ARGS=", OS.get_cmdline_user_args())
	print("DATA ", FileAccess.file_exists("res://data/officers_v1.json"), " HELPER ", ProjectSettings.has_setting("autoload/_mcp_game_helper"))
	print("GODOT_LICENSE ", Engine.get_license_text().length())
	quit()
