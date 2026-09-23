extends "res://tests/full_r3_regions_test.gd"
func _run() -> void:
	create_timer(80).timeout.connect(func():quit(2))
	root.content_scale_size=Vector2i.ZERO
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(R3_OUT+"play.json"))
	check(OS.get_process_id()!=int(saved.pid),"separate OS process")
	for row: Dictionary in saved.records:
		root.size=Vector2i(int(row.resolution),720 if int(row.resolution)==1280 else 1080)
		await load_from_title(row.slot)
		check(ui.visible and full_state()==row.state,"new process restores campaign in bright atlas")
		check(ui.selected=="tamna" and is_equal_approx(ui.map.map_zoom,float(row.view.zoom)),"new process restores castle and zoom")
		check(not ui.map.full_r3.review and ui.map.full_r3.last_drawn==["detail_3_1"],"new process renders registered island, no raw candidates")
		await capture_region(str(int(row.resolution))+"-production-restart")
		ui.map.set_r3_comparison(true);await pause()
		check(ui.map.corrected_comparison and ui.map.r3_comparison and ui.map.full_r3.last_drawn.is_empty(),"existing r2/r3 takes exclusive review priority")
		ui.map.set_corrected_comparison(false);await pause()
		var terrain=ui.map.full_r3
		var tile: Dictionary=terrain.tiles.filter(func(t):return t.id=="detail_3_1")[0]
		var entry: Dictionary=terrain.approvals.tiles.detail_3_1
		var original_hash: String=entry.mesh_sha256
		entry.mesh_sha256="controlled-invalid-hash"
		check(terrain.weight(tile,ui.map.terrain_pixel_scale())==0.0,"changed mesh cannot inherit geography approval")
		entry.mesh_sha256=original_hash
	print("FULL R3 RESTART: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
