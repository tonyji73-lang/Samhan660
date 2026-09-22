extends "res://tests/silla_642_gameplay_loop.gd"
const UI_DIR = "res://.godot/settlement-ui/"
var ui: Control
var moved_id: String

func pause() -> void:
	await process_frame; await process_frame; await create_timer(0.25).timeout

func mouse(point: Vector2, code: MouseButton, down: bool) -> void:
	var motion := InputEventMouseMotion.new(); motion.position = point; root.push_input(motion, true)
	var event := InputEventMouseButton.new(); event.position = point; event.button_index = code; event.pressed = down
	root.push_input(event, true); await process_frame

func click(button: Control) -> void:
	await pause()
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size / 2)
	await mouse(point, MOUSE_BUTTON_LEFT, true); await mouse(point, MOUSE_BUTTON_LEFT, false)
	await pause()

func screen(label: String) -> void:
	await pause(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(UI_DIR + label + ".png") == OK, "capture " + label)

func escape() -> void:
	for down: bool in [true, false]:
		var e := InputEventKey.new(); e.keycode = KEY_ESCAPE; e.pressed = down; root.push_input(e, true)
	await pause()

func _run() -> void:
	create_timer(150).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(UI_DIR)
	root.content_scale_size = Vector2i.ZERO
	seed(64220260922)
	await start(Scenarios.SCENARIOS[1], "silla", "historical"); await settle_events(); await pause()
	ui = c.settlement_overlay
	var original: Dictionary = ui.map.WORLD_CITY_MAP_UV.duplicate(true)
	var before: Dictionary = full_state()
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution; await pause()
		if not ui.visible: await click(c.settlement_button)
		check(ui.visible and c.map_area.modal_input_locked, "campaign entry locks underlying map")
		ui.select_city("dalgubeol"); ui.map.focus_region(); await pause()
		await screen(str(resolution.x) + "-dalgubeol")
		check(ui.get_global_rect().end.y <= resolution.y and ui.bottom.get_global_rect().end.y <= resolution.y, "UI fits " + str(resolution))
		check(ui.header.text.contains(str(c.year)) and ui.header.text.contains(str(c.gold)), "live date and treasury")
		check(not ui.threat.visible, "no fabricated invasion")
		for id: String in ["dalgubeol", "geumseong", "sabeol", "chupungnyeong", "daegaya"]:
			ui.map.focus_on_province(id, 5); await pause()
			await click(ui.map.city_buttons[id])
			check(ui.selected == id and c.selected_province_id == id and ui.city_title.text == c.provinces[id].name, "actual castle selection " + id)
			check(ui.statistics.text.contains(str(c.provinces[id].troops)) and ui.statistics.text.contains(str(c.provinces[id].food_stock)), "live troops and grain " + id)
			var rect: Rect2 = ui.map._get_displayed_map_rect()
			check(((ui.map.anchor(id) - rect.position) / rect.size).distance_to(original[id]) < 0.000001, "unchanged anchor " + id)
		ui.map.focus_on_province("dalgubeol", 4)
		var point: Vector2 = ui.map.global_position + ui.map.size * Vector2(0.87, 0.7)
		await mouse(point, MOUSE_BUTTON_WHEEL_UP, true); await mouse(point, MOUSE_BUTTON_WHEEL_UP, false)
		check(ui.map.map_zoom > 4, "wheel zoom up")
		await mouse(point, MOUSE_BUTTON_WHEEL_DOWN, true); await mouse(point, MOUSE_BUTTON_WHEEL_DOWN, false)
		check(is_equal_approx(ui.map.map_zoom, 4), "wheel zoom down")
		var pan: Vector2 = ui.map.map_pan_offset
		await mouse(point, MOUSE_BUTTON_LEFT, true)
		var motion := InputEventMouseMotion.new(); motion.position = point + Vector2(60, 30); motion.button_mask = MOUSE_BUTTON_MASK_LEFT; root.push_input(motion, true)
		await mouse(motion.position, MOUSE_BUTTON_LEFT, false)
		check(ui.map.map_pan_offset.distance_to(pan) > 20, "drag pan")
		ui.select_city("geumseong"); await pause()
		pan = ui.map.map_pan_offset
		for kind: String in ["domestic", "army", "production", "politics"]:
			await click(ui.buttons[kind])
			var overlay: Control = c.get({"domestic":"domestic_overlay", "army":"army_overlay", "production":"production_overlay", "politics":"politics_overlay"}[kind])
			check(overlay.visible and not ui.visible, "existing menu " + kind)
			if kind == "politics":
				check(overlay.targets.get_item_metadata(overlay.targets.selected).city == "geumseong", "personnel opens at selected city")
			await escape()
			check(ui.visible and ui.selected == "geumseong" and ui.map.map_pan_offset == pan, "return selection and pan " + kind)
		check(full_state() == before, "all menus and selections read only")
		await click(ui.preview); await screen(str(resolution.x) + "-support-preview")
		check(ui.route_open and ui.route_text.text.contains(str(c.province_transfer_turns(ui.source_id(), ui.selected))), "shared support duration")
		await click(ui.buttons.cancel)
		check(ui.map.preview_source.is_empty() and full_state() == before, "preview cancel has no resource or reservation effects")
		var zoom: float = ui.map.map_zoom
		await mouse(ui.header.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP, true)
		await mouse(ui.header.get_global_rect().get_center(), MOUSE_BUTTON_WHEEL_UP, false)
		check(ui.map.map_zoom == zoom, "header wheel does not reach map")
		await click(ui.buttons.overview)
		check(ui.map.map_zoom == 1 and ui.map.terrain.texture.get_size() == Vector2(1254,1254), "overview preserves corrected native texture")
		await screen(str(resolution.x) + "-overview")
		await click(ui.buttons.close)
		check(not ui.visible and not c.map_area.modal_input_locked, "original map restored")
	# Normal unit-specific support through the existing army command, no troop injection.
	await click(c.settlement_button); ui.select_city("dalgubeol"); await pause()
	select_value(ui.sources, "geumseong"); await click(ui.preview); await click(ui.support)
	check(c.army_overlay.visible and c.army_overlay.city == "geumseong", "support opens existing unit and commander screen")
	check(c.army_overlay.destination.get_item_metadata(c.army_overlay.destination.selected) == "dalgubeol", "target preselected")
	moved_id = c.army_overlay.id()
	var order_count: int = c.pending_transfer_orders.size()
	await click(c.army_overlay.move_button)
	check(c.pending_transfer_orders.size() == order_count + 1 and c.pending_transfer_orders.back().unit_ids == [moved_id], "existing normal command dispatches selected unit once")
	await click(c.army_overlay.move_button)
	check(c.pending_transfer_orders.size() == order_count + 1, "repeat click cannot redispatch departed unit")
	await escape()
	check(ui.visible and ui.selected == "dalgubeol", "support return preserves destination")
	var slot: String = "user://settlement_ui_%d_%d.json" % [int(Time.get_unix_time_from_system()), OS.get_process_id()]
	check(not FileAccess.file_exists(slot) and c._on_save_button_pressed(slot), "separate native save slot")
	var saved: Dictionary = full_state()
	var previous: int = stamp()
	await click(ui.buttons.month); await settle_events(); c.merit_overlay.hide(); await pause()
	check(stamp() == previous + 1 and c.Army.units(c.strategy_state)[moved_id].location == "dalgubeol", "normal month resolves actual support")
	check(ui.statistics.text.contains(str(c.provinces.dalgubeol.troops)), "month refresh reflects arrivals and AI")
	await screen("after-normal-month")
	c._on_load_button_pressed(slot); await pause()
	check(full_state() == saved and ui.selected == c.selected_province_id, "load refresh preserves full pending state")
	check(ui.map.WORLD_CITY_MAP_UV == original, "all 54 runtime coordinates preserved")
	# Paid normal work verifies that live estimates are not reference illustration values.
	for task: Array in [["build", "smelter", "historical:001"], ["research", "swordsmithing", "historical:003"]]:
		var job_result: Dictionary = c.Industry.start(c.strategy_state, c.provinces, c.strategy, "silla", "geumseong", task[0], task[1], task[2], stamp(), c.scenario_id, c.iron_supply_rules)
		check(job_result.ok, "normal paid job " + task[0])
	ui.select_city("geumseong"); ui.map.focus_on_province("geumseong", 5); await pause()
	check(ui.statistics.text.contains("현재 조건 약"), "live common work estimate")
	await screen("active-industry")
	ui.select_city("dalgubeol"); ui.map.focus_region()
	root.content_scale_size = Vector2i(1920,1080); root.size = Vector2i(1280,720); await pause()
	await screen("1280-default-canvas-scale")
	check(ui.bottom.get_global_rect().end.y <= 1080, "default project canvas scaling fits")
	var file := FileAccess.open(UI_DIR + "normal.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(), "slot":slot, "state":saved, "unit":moved_id, "checks":checks, "failures":failures}, "\t")); file.close()
	print("SETTLEMENT UI: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
