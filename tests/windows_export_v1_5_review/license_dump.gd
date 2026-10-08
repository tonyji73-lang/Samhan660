extends SceneTree
func _initialize() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out.path_join("GODOT-LICENSE.txt"), FileAccess.WRITE)
	file.store_string(Engine.get_license_text())
	file.close()
	file = FileAccess.open(out.path_join("GODOT-THIRD-PARTY.txt"), FileAccess.WRITE)
	file.store_string(JSON.stringify(Engine.get_copyright_info(), "\t") + "\n\n" + JSON.stringify(Engine.get_license_info(), "\t"))
	file.close()
	quit()
