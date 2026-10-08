extends "res://tests/faction_selection_ui_v1_test.gd"
const CLARITY_OUT = "res://tests/play_map_clarity_20261002/"
func shot(label: String) -> void:
	await pause()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(CLARITY_OUT+label+".png") == OK,"capture "+label)
func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	root.content_scale_size = Vector2i.ZERO
	await enter_setup()
	await choose("faction:silla")
	await choose("start")
	await create_timer(3).timeout
	c = current_scene
	await settle_events()
	ui = c.settlement_overlay
	var before := full_state()
	var map: Control = ui.map
	var old_shader := Shader.new()
	old_shader.code = FileAccess.get_file_as_string(CLARITY_OUT+"detail_before.gdshader")
	var new_shader: Shader = load("res://ui/korea_layout_v1/terrain_refresh_20261001/detail.gdshader")
	for resolution: Vector2i in [Vector2i(1280,720)]:
		root.size = resolution
		await pause()
		for id: String in ["pyongyang"]:
			ui.select_city(id)
			map.focus_on_province(id,6)
			await pause()
			map.refreshed_detail.fine_enabled = false
			for tile: TextureRect in map.refreshed_detail.tiles: tile.material.shader = old_shader
			map.queue_redraw()
			await shot(str(resolution.x)+"-"+id+"-before")
			map.refreshed_detail.fine_enabled = true
			for tile: TextureRect in map.refreshed_detail.tiles: tile.material.shader = new_shader
			map.queue_redraw()
			await shot(str(resolution.x)+"-"+id+"-after")
			check(map.refreshed_detail.weight > 0.9,"actual play detail active "+id)
			var point: Vector2 = map.get_global_transform_with_canvas()*map.anchor(id)
			await mouse(point,MOUSE_BUTTON_LEFT,true)
			await mouse(point,MOUSE_BUTTON_LEFT,false)
			check(c.selected_province_id == id,"actual castle click "+id)
		ui.select_city("pyongyang")
		map.focus_on_province("pyongyang",6)
		var zoom: float = map.map_zoom
		await mouse(Vector2(resolution)*Vector2(0.65,0.5),MOUSE_BUTTON_WHEEL_UP,true)
		await mouse(Vector2(resolution)*Vector2(0.65,0.5),MOUSE_BUTTON_WHEEL_UP,false)
		check(map.map_zoom > zoom,"wheel zooms play map")
		await shot(str(resolution.x)+"-wheel")
		map.focus_on_province("pyongyang",12)
		await shot(str(resolution.x)+"-maximum")
		map.fit_all()
		await pause()
		check(is_zero_approx(map.refreshed_detail.weight),"overview unchanged")
		check(full_state() == before,"campaign unchanged")
	print("PLAY MAP CLARITY: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)