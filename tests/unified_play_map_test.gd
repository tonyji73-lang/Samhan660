extends "res://tests/faction_selection_ui_v1_test.gd"
const UNIFIED_OUT = "res://tests/unified_play_map_20261002/"

func shot(label: String) -> void:
	await pause()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(UNIFIED_OUT+label+".png") == OK,"capture "+label)

func _run() -> void:
	create_timer(300).timeout.connect(func(): quit(2))
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	await enter_setup()
	await choose("faction:silla")
	await choose("start")
	await create_timer(3).timeout
	c = current_scene
	await settle_events()
	ui = c.settlement_overlay
	var map: Control = ui.map
	var before := full_state()
	check(not ui.buttons.has("overview") and not ui.has_method("open_world_map"),"separate world-map feature removed")
	check(map.get_layout_points().size() == 35,"original 35 layout entries preserved")
	check(map.get_layout_status().unmapped_live_ids.is_empty(),"all actual campaign sites have play-map anchors")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(map.UnifiedGround.DIR+"manifest.json"))
	for id: String in manifest.sites:
		check(map.has_site_id(id) and (c.provinces.has(id) or map._reference_sites.has(id)),"actual or explicitly reference-only site "+id)
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		await pause()
		map.fit_all()
		await shot(str(resolution.x)+"-continuous")
		for id: String in ["changan","shandong","steppe_huihe","steppe_bayegu","asuka","tsukushi","emishi_aguta","pyongyang","geumseong"]:
			ui.select_city("geumseong")
			map.focus_on_province(id,6)
			await pause()
			var point: Vector2 = map.get_global_transform_with_canvas()*map.anchor(id)
			await mouse(point,MOUSE_BUTTON_LEFT,true)
			await mouse(point,MOUSE_BUTTON_LEFT,false)
			await pause()
			if c.provinces.has(id):
				check(c.selected_province_id == id,"actual play-map click "+id+str(resolution))
			else:
				check(c.selected_province_id == "geumseong" and map.pick_id_at(map.anchor(id)).is_empty(),"reference geography cannot execute campaign commands "+id)
			check(map.is_visible_in_tree() and not c.get_node("MainVBox").visible,"one play view retained "+id)
			if id not in ["pyongyang","geumseong"]:
				check(map.unified_ground.active_tiles > 0,"external high-detail tiles active "+id)
			await shot(str(resolution.x)+"-"+id)
		map.focus_on_province("changan",2)
		var saved: Dictionary = map.get_view_state()
		map.focus_on_province("geumseong",1)
		map.restore_view_state(saved)
		check(map.get_view_state() == saved,"negative world center restores")
		var wheel_point := Vector2(resolution)*Vector2(0.65,0.5)
		var zoom: float = map.map_zoom
		await mouse(wheel_point,MOUSE_BUTTON_WHEEL_UP,true)
		await mouse(wheel_point,MOUSE_BUTTON_WHEEL_UP,false)
		check(map.map_zoom > zoom,"wheel zoom outside Korea")
		for id: String in ["changan","asuka","steppe_huihe"]:
			map.focus_on_province(id,100)
			await pause()
			check(map.terrain_pixel_scale() <= 3.501,"no detail texel enlargement at maximum "+id)
			await shot(str(resolution.x)+"-max-"+id)
		var pan: Vector2 = map.map_pan_offset
		await mouse(wheel_point,MOUSE_BUTTON_LEFT,true)
		var motion := InputEventMouseMotion.new()
		motion.position = wheel_point+Vector2(140,60)
		motion.relative = Vector2(140,60)
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		root.push_input(motion,true)
		await process_frame
		await mouse(motion.position,MOUSE_BUTTON_LEFT,false)
		check(map.map_pan_offset.distance_to(pan)>20,"actual drag outside Korea")
		await escape()
		await pause()
		await escape()
		await pause()
		check(map.is_visible_in_tree(),"Esc retains unified play map")
		check(full_state() == before,"navigation changes no campaign resources or troops")
	print("UNIFIED PLAY MAP: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
