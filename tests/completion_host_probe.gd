extends "res://tests/ai_military_planning_audit.gd"
func _run() -> void:
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 var path: String="user://normal_completion_probe_20260915_"+str(Time.get_ticks_usec())+".json"
 print("HOST_USER_PATH ",ProjectSettings.globalize_path("user://"))
 print("HOST_SLOT ",ProjectSettings.globalize_path(path))
 var saved: bool=c._on_save_button_pressed(path)
 print("HOST_SAVED ",saved," EXISTS ",FileAccess.file_exists(path)," ERROR ",FileAccess.get_open_error())
 var f:=FileAccess.open("res://.godot/completion-host-probe.json",FileAccess.WRITE)
 f.store_string(JSON.stringify({"directory":ProjectSettings.globalize_path("user://"),"path":ProjectSettings.globalize_path(path),"saved":saved,"exists":FileAccess.file_exists(path)})); f.close()
 quit()