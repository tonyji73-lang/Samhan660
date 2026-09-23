extends "res://tests/full_r3_regions_test.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(R3_OUT)
	root.content_scale_size=Vector2i.ZERO
	await start(Scenarios.SCENARIOS[1],"silla","historical");await settle_events();ui=c.settlement_overlay
	ui.map.full_r3.review=true;ui.map.full_r3.review_tile="detail_3_1"
	for res: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=res;await pause();ui.select_city("tamna");ui.map.focus_on_province("tamna",5.0)
		for mode: String in ["base","raw","registered"]:
			ui.map.full_r3.suppressed=mode=="base"
			ui.map.full_r3.registered_review=mode=="registered"
			ui.map.queue_redraw();await capture_region(str(res.x)+"-jeju-"+mode+"-registration")
		check(ui.map.full_r3.tiles.filter(func(t):return t.id=="detail_3_1")[0].has("registered_mesh"),"nonfolding coast registration loaded")
		var point: Vector2=ui.map.get_global_transform_with_canvas()*ui.map.anchor("tamna")
		await mouse(point,MOUSE_BUTTON_LEFT,true);await mouse(point,MOUSE_BUTTON_LEFT,false)
		check(ui.selected=="tamna","Jeju actual unchanged castle selection")
	print("JEJU GUI: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
