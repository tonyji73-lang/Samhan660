extends "res://tests/faction_selection_ui_v1_test.gd"
const BOHAI_OUT = "res://tests/bohai_20261002/"
func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	await enter_setup()
	await choose("faction:silla")
	await choose("start")
	await create_timer(3).timeout
	c = current_scene
	await settle_events()
	ui = c.settlement_overlay
	await click(ui.buttons.hide_city)
	var map: Control = ui.map
	map.set_process(false)
	var before := full_state()
	check(map.get_layout_points().size()==35,"original 35 city layout preserved")
	check(map._reference_sites.has("shandong") and not c.provinces.has("shandong"),"Shandong remains display-only")
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		await pause()
		for view: String in ["region","dalian","yantai"]:
			var center := Vector2(-50,430)
			var zoom := 1.2
			if view == "dalian":
				center = Vector2(-170,370)
				zoom = 5.0
			elif view == "yantai":
				center = Vector2(-230,630)
				zoom = 5.0
			map.restore_view_state({"zoom":zoom,"center_native":[center.x,center.y],"selected":"geumseong"})
			for phase: String in ["before","after"]:
				map.unified_ground.bohai.visible = phase == "after"
				map._sites["shandong"].render_xy = [-250.0,620.0] if phase == "after" else [-233.984375,352.734375]
				map.queue_redraw()
				await pause()
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(BOHAI_OUT+str(resolution.x)+"-"+view+"-"+phase+".png")==OK,"capture "+str(resolution.x)+" "+view+" "+phase)
	check(full_state()==before,"rendering leaves campaign state unchanged")
	print("BOHAI REVIEW: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
