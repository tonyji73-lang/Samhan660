extends "res://tests/faction_selection_ui_v1_test.gd"
const LAYOUT_OUT = "res://tests/faction_layout_20261006/"
func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	root.content_scale_size = Vector2i.ZERO
	await enter_setup()
	var before := "--before" in OS.get_cmdline_user_args()
	for resolution: Vector2i in [Vector2i(1280,720), Vector2i(1920,1080)]:
		root.size = resolution
		await pause()
		for faction: String in ["silla", "baekje", "goguryeo"]:
			await choose("faction:" + faction)
			var view: Control = setup.faction_view
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(LAYOUT_OUT + str(resolution.x) + "-" + faction + ("-before" if before else "-after") + ".png") == OK, "capture " + str(resolution.x) + faction)
			if not before:
				check(view._box("portrait").position.x > 0 and view._box("portrait").position.y >= view._box("factions").end.y, "portrait clears top tabs " + faction)
				check(view._focus_controls.start.get_global_rect().end.y <= resolution.y, "start fits " + faction)
				check(setup.selected_faction_id == faction and view._model.leader == setup._get_selected_faction_data().ruler, "real faction ruler " + faction)
		if not before:
			await choose("faction:silla")
			await choose("difficulty:hard")
			await choose("difficulty:normal")
			check(setup.selected_difficulty_id == "normal", "difficulty input")
			var view: Control = setup.faction_view
			var point: Vector2 = view._details.get_global_rect().get_center()
			for i in range(8):
				await mouse(point, MOUSE_BUTTON_WHEEL_DOWN, true)
				await mouse(point, MOUSE_BUTTON_WHEEL_DOWN, false)
			check(view._details.scroll_vertical > 0, "details scroll")
	if not before:
		var view: Control = setup.faction_view
		view._focus_controls["modes:fictional"].grab_focus()
		for down: bool in [true, false]:
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER; key.pressed = down; root.push_input(key, true)
			await process_frame
		await pause()
		check(setup.selected_play_style_id == "fictional", "keyboard mode selection")
		await escape()
		await create_timer(1).timeout
		check(current_scene.scene_file_path == "res://title_screen.tscn", "escape back")
		await enter_setup()
		await choose("faction:silla")
		await choose("start")
		await create_timer(3).timeout
		c = current_scene
		check(c.year == 632 and c.player_faction_id == "silla", "existing campaign start")
	print("FACTION_LAYOUT_COMPLETE ", checks, " checks; ", failures, " failures")
	quit(1 if failures > 0 else 0)