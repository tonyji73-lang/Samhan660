extends "res://tests/faction_selection_ui_v1_test.gd"

const WORLD_ACCESS_OUT = "res://.godot/world-map-access/"

func capture_map(label: String) -> void:
	await pause()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(WORLD_ACCESS_OUT + label + ".png") == OK, "capture " + label)

func _run() -> void:
	create_timer(150).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(WORLD_ACCESS_OUT)
	root.content_scale_size = Vector2i.ZERO
	await enter_setup()
	await choose("faction:silla")
	await choose("start")
	await create_timer(3).timeout
	c = current_scene
	await settle_events()
	ui = c.settlement_overlay
	var before: Dictionary = full_state()
	for resolution: Vector2i in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = resolution
		await pause()
		var camera: Dictionary = ui.map.get_view_state()
		await click(ui.buttons.overview)
		check(ui.world_view and not ui.visible and c.get_node("MainVBox").visible, "world map visible " + str(resolution))
		check(not c.map_area.modal_input_locked, "world input unlocked")
		check(c.event_presentation.adapter.map == c.map_area, "world event camera")
		var source_image := Image.load_from_file(c.map_area.DEFAULT_MAP_TEXTURE_PATH)
		check(c.map_area.map_background.texture.get_size() == Vector2(source_image.get_size()), "full world texture keeps source resolution")
		print("WORLD TEXTURE: ",source_image.get_size())
		var whole: Rect2 = c.map_area._get_displayed_map_rect()
		check(whole.position.x >= -1 and whole.position.y >= -1 and whole.end.x <= c.map_area.size.x+1 and whole.end.y <= c.map_area.size.y+1, "entire world fits without cropping")
		for id: String in ["changan", "asuka", "steppe_hun"]:
			check(c.map_area.city_buttons.has(id) and c.map_area.WORLD_CITY_MAP_UV.has(id), "existing world marker " + id)
			var rect: Rect2 = c.map_area._get_displayed_map_rect()
			var local: Vector2 = rect.position + rect.size * c.map_area.WORLD_CITY_MAP_UV[id]
			check(Rect2(Vector2.ZERO,c.map_area.size).has_point(local), "region in fitted map " + id)
		await capture_map(str(resolution.x) + "-world")
		var point: Vector2 = c.map_area.get_global_transform_with_canvas() * (c.map_area.size * 0.5)
		await mouse(point,MOUSE_BUTTON_WHEEL_UP,true)
		await mouse(point,MOUSE_BUTTON_WHEEL_UP,false)
		check(c.map_area.map_zoom > c.map_area.MAP_MIN_ZOOM, "world wheel zoom")
		await click(ui.return_from_world)
		check(ui.visible and not ui.world_view and not c.get_node("MainVBox").visible, "return button")
		check(ui.map.get_view_state() == camera, "regional camera preserved")
		check(c.event_presentation.adapter.map == ui.map and c.map_area.modal_input_locked, "regional camera and input restored")
		await capture_map(str(resolution.x) + "-regional")
		await click(ui.buttons.overview)
		await escape()
		check(ui.visible and not ui.world_view, "Esc return")
		check(full_state() == before, "navigation preserves campaign state")
	print("WORLD MAP ACCESS: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
