extends "res://tests/faction_selection_ui_v1_test.gd"
func _run() -> void:
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
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		await pause()
		for place: String in ["continuous","changan","asuka","steppe_huihe"]:
			if place == "continuous": ui.map.fit_all()
			else: ui.map.focus_on_province(place,100)
			await mouse(Vector2(10,50),MOUSE_BUTTON_LEFT,false)
			await pause()
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png("res://tests/unified_play_map_20261002/final-"+str(resolution.x)+"-"+place+".png") == OK,"final region labels/capture "+place)
	print("UNIFIED FINAL VISUAL: ",checks," checks, ",failures," failures")
	if "--keep-open" in OS.get_cmdline_user_args():
		root.size = Vector2i(1280,720)
		await pause()
		ui.map.fit_all()
		root.title = "삼한660 · 통합 플레이 지도 · 현재 프로젝트"
	else: quit(0 if failures == 0 else 1)
