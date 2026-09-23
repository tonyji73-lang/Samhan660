extends "res://tests/south_v3_play.gd"
func _run() -> void:
	create_timer(100).timeout.connect(func():quit(2))
	root.content_scale_size=Vector2i.ZERO
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(V3_OUT+"results.json"))
	check(int(saved.pid)!=OS.get_process_id() and OS.get_cmdline_user_args().is_empty(),"new process, no review arguments")
	for row: Dictionary in saved.snapshots:
		root.size=Vector2i(int(row.resolution),720 if int(row.resolution)==1280 else 1080)
		await load_from_title(row.slot)
		var layer=ui.map.south_v3
		check(full_state()==row.state and ui.map.get_view_state()==row.view,"new process restores campaign and camera")
		check(layer.approved and not layer.review and layer.drawn and layer.weight==1 and layer.material.get_shader_parameter("lod_weight")==1,"new process automatically renders registered v3")
		await snap(str(int(row.year))+"-"+str(int(row.resolution))+"-restart")
	var f:=FileAccess.open(V3_OUT+"restart.json",FileAccess.WRITE);f.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"records":records},"\t"));f.close()
	print("SOUTH V3 RESTART ",checks," checks ",failures," failures")
	quit(0 if failures==0 else 1)
