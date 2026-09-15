extends SceneTree
# Opens an actual recorded checkpoint for manual continuation; no automation or state injection.
func _initialize() -> void:
 call_deferred("_open_checkpoint")
func _open_checkpoint() -> void:
 var checkpoint: String="month-037"
 for argument: String in OS.get_cmdline_user_args():
  if argument.begins_with("--checkpoint="): checkpoint=argument.trim_prefix("--checkpoint=")
 if checkpoint not in ["normal-start","month-037","month-073","before-battle-106","final"]:
  push_error("Choose normal-start, month-037, month-073, before-battle-106 or final"); quit(2); return
 var path: String="res://.godot/normal-completion-final/"+checkpoint+".json"
 if not FileAccess.file_exists(path): push_error("Checkpoint missing: "+path); quit(2); return
 change_scene_to_file("res://campaign_main.tscn")
 await process_frame; await process_frame; await create_timer(0.5).timeout
 current_scene._on_load_button_pressed(path)
 print("MANUAL CONTINUATION ",ProjectSettings.globalize_path(path)," USER DIR ",ProjectSettings.globalize_path("user://"))
