extends "res://tests/industry_assignment_gui_test.gd"

var phase: String = "before"

func capture_view(label: String) -> void:
	await settle()
	await RenderingServer.frame_post_draw
	var path := "res://tests/living_city_v1_4_review/%s_%d_%s.png" % [phase, root.size.y, label]
	check(root.get_texture().get_image().save_png(path) == OK, "capture " + label)

func edge_states(panel: Node) -> void:
	var original_gold: int = c.gold
	var button: Button = panel.execute_button
	for state: String in ["normal","hover","pressed","hover_pressed","disabled"]:
		check(button.get_theme_stylebox(state) is StyleBoxTexture, "red texture " + state)
	button.grab_focus()
	check(button.has_focus(), "primary keyboard focus")
	await capture_view("focus")
	for down: bool in [true,false]:
		var key := InputEventKey.new(); key.keycode = KEY_TAB; key.pressed = down; root.push_input(key,true)
	await settle()
	check(root.gui_get_focus_owner() != button and root.gui_get_focus_owner() != null, "Tab advances focus")
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size / 2)
	var motion := InputEventMouseMotion.new(); motion.position = point; root.push_input(motion,true)
	await capture_view("hover")
	var press := InputEventMouseButton.new(); press.position = point; press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; root.push_input(press,true)
	await capture_view("pressed")
	motion = InputEventMouseMotion.new(); motion.position = Vector2(2,2); root.push_input(motion,true)
	press = InputEventMouseButton.new(); press.position = Vector2(2,2); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = false; root.push_input(press,true)
	await settle()
	check(c.gold == original_gold and panel.job().is_empty(), "press released outside never accepts job")
	panel.officer_selector.set_item_text(1, "긴 이름 표시 검증 " .repeat(15))
	panel.officer_selector.select(1); panel.refresh()
	await capture_view("long_name")
	check(panel.officer_selector.size.x <= panel.size.x * 0.7 and panel.officer_selector.tooltip_text.length() > 100, "long name bounded with full tooltip")
	panel.officer_selector.clear(); panel.refresh()
	check(button.disabled and panel.selected_id().is_empty(), "empty candidates disable acceptance")
	await capture_view("no_candidates")
	panel.rebuild_officers(); panel.refresh()
	var scroll: ScrollContainer = panel.details.get_parent()
	panel.details.text += "\n긴 설명 스크롤 검증".repeat(90)
	await settle(); scroll.scroll_vertical = 10000; await settle()
	check(scroll.scroll_vertical > 0 and not scroll.get_h_scroll_bar().visible, "long explanation scrolls internally")
	await capture_view("scroll")
	panel.refresh()
	panel.officer_selector.select(1); panel.officer_selector.item_selected.emit(1)
	check(not button.disabled, "normal build available after edge fixtures restored")
	await click(button)
	check(not panel.job().is_empty() and button.disabled and c.gold < original_gold, "real button accepts once and becomes disabled")
	await capture_view("pending")
	await click(panel.pause_button)
	check(panel.job().status == "paused", "pause retains accepted work")
	await capture_view("paused")
	await click(panel.assign_button)
	check(panel.job().status == "pending", "resume through assignment button")
	await click(panel.cancel_button)
	check(panel.job().is_empty() and c.gold == original_gold, "cancel before progress refunds original quote")
	await click(panel.close_button)
	check(not panel.visible and not c.settlement_overlay.busy(), "close restores map")

func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	if OS.get_cmdline_user_args().has("--after"): phase = "after"
	root.set_meta("new_game_settings", {"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn")
	await settle(); c = current_scene; await events()
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		await settle()
		c._on_city_card_production_requested("geumseong")
		await capture_view("production")
		var p: Node = c.production_overlay
		p.scroll_container.scroll_vertical = 10000
		await capture_view("requirements")
		await escape()
		for task_kind: String in ["build","research","production"]:
			c.open_industry("geumseong", task_kind, "forge" if task_kind == "build" else "swordsmithing")
			var panel: Node = c.industry_overlay
			await capture_view(task_kind + "_empty")
			if panel.officer_selector.item_count > 1:
				panel.officer_selector.select(1); panel.officer_selector.item_selected.emit(1)
			await capture_view(task_kind + "_selected")
			check(panel.close_button.get_global_rect().end.y <= panel.size.y, task_kind + " close inside viewport")
			await escape()
			check(not panel.visible and not c.settlement_overlay.busy(), task_kind + " Esc restores map")
		if phase == "after":
			c.open_industry("geumseong","build","forge")
			var panel: Node = c.industry_overlay
			panel.officer_selector.select(1); panel.officer_selector.item_selected.emit(1)
			await edge_states(panel)
			c.select_province("geumseong",false)
			c.open_domestic("agriculture")
			await settle()
			var domestic: Node = c.domestic_overlay
			var city_view: Control = domestic.find_child("CityPanorama",true,false)
			var work_view: Control = domestic.find_child("CityWorkPanel",true,false)
			check(is_equal_approx(city_view.size.x/domestic.size.x,0.65) and is_equal_approx(work_view.size.x/domestic.size.x,0.35), "domestic 65:35 preserved")
			await capture_view("domestic_unchanged")
			await escape()
	print("V1.4 VISUAL: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
