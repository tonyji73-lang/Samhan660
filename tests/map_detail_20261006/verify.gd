extends "res://tests/faction_selection_ui_v1_test.gd"
const CLARITY_OUT = "res://tests/map_detail_20261006/"
func _run() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
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
	var state := full_state()
	var current: Control = map.unified_ground
	var old: Control = load(CLARITY_OUT+"unified_ground_before.gd").new()
	old.show_behind_parent = true
	map.add_child(old)
	old.configure(current.korea.texture)
	old.hide()
	check(current.bohai_details.size()==7,"regional coast/inland detail coverage expanded to seven tiles")
	check(current.tiles.size()==old.tiles.size()+2,"missing western sea island tiles connected")
	for tile: TextureRect in current.bohai_details:
		check(tile.texture.get_width()/350.0>=3.5,"regional detail meets maximum camera density")
	for i in range(current.paths.size()-2,current.paths.size()):
		var texture: Texture2D = load(current.paths[i])
		check(texture.get_width()/350.0>=3.5,"island detail meets maximum camera density")
	var views := {"reported_islands":Vector2(80,1000),"southern_islands":Vector2(130,1240),"south_join":Vector2(-200,720),"dalian":Vector2(-170,370),"west_bohai":Vector2(-500,330),"north_bohai":Vector2(-160,70),"region":Vector2(-20,430)}
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		await pause()
		for label: String in views:
			var center: Vector2 = views[label]
			map.restore_view_state({"zoom":1.1 if label=="region" else 100.0,"center_native":[center.x,center.y],"selected":"geumseong"})
			for phase in ["before","after"]:
				current.visible = phase=="after"
				old.visible = phase=="before"
				map.unified_ground = current if phase=="after" else old
				map.queue_redraw()
				await pause()
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(CLARITY_OUT+str(resolution.x)+"-"+label+"-"+phase+".png")==OK,"capture "+str(resolution.x)+" "+label+" "+phase)
		var zoom: float = map.map_zoom
		var wheel_point := Vector2(resolution)*Vector2(0.65,0.5)
		await mouse(wheel_point,MOUSE_BUTTON_WHEEL_UP,true)
		await mouse(wheel_point,MOUSE_BUTTON_WHEEL_UP,false)
		check(map.map_zoom>zoom,"actual wheel zoom retained")
		var pan: Vector2 = map.map_pan_offset
		await mouse(wheel_point,MOUSE_BUTTON_LEFT,true)
		var motion := InputEventMouseMotion.new()
		motion.position = wheel_point+Vector2(100,40)
		motion.relative = Vector2(100,40)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion,true)
		await process_frame
		await mouse(motion.position,MOUSE_BUTTON_LEFT,false)
		check(map.map_pan_offset.distance_to(pan)>20,"actual map drag retained")
	map.unified_ground = current
	old.queue_free()
	check(full_state()==state,"visual navigation leaves campaign state unchanged")
	print("MAP DETAIL OCT06: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
