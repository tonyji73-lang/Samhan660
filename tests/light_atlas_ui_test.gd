extends "res://tests/faction_selection_ui_v1_test.gd"
## Run with the real GUI in a disposable test profile. This test has not been run here.
## Base helpers use transformed mouse coordinates, including the 720p stage scale.
const ATLAS_CAPTURES := "res://.godot/light-atlas-v1/"

func atlas_capture(caption: String) -> void:
	await pause()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ATLAS_CAPTURES + caption + ".png") == OK, "capture " + caption)

func atlas_visible(control: Control) -> bool:
	var rectangle := control.get_global_rect()
	return control.is_visible_in_tree() and Rect2(Vector2.ZERO, Vector2(root.size)).encloses(rectangle)

func atlas_click_visible(control: Control) -> void:
	# City-card controls can be below the fold when live job text is long.
	var ancestor := control.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(control)
		ancestor = ancestor.get_parent()
	await click(control)

func _run() -> void:
	create_timer(300).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(ATLAS_CAPTURES)
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1920, 1080)
	await enter_setup()
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await pause()
		for scenario: Dictionary in Scenarios.SCENARIOS:
			await choose("scenario:" + str(scenario.id))
			var view: Control = setup.faction_view
			for item: Dictionary in view._model.factions:
				var faction_button: Button = view._focus_controls["faction:" + str(item.id)]
				check(faction_button.disabled == (not bool(item.enabled)), "faction lock " + str(item.id))
				if not bool(item.enabled):
					check(faction_button.tooltip_text == "아직 오픈되지 않았습니다", "locked tooltip")
			check(atlas_visible(view._focus_controls.start), "start stays on screen")
			check(atlas_visible(view._focus_controls.back), "back stays on screen")
			check(view._scenario_scroll.get_global_rect().end.y < view._details.get_global_rect().position.y, "era selector above dossier")
		await choose("scenario:" + str(Scenarios.SCENARIOS[2].id))
		await choose("faction:silla")
		check(setup.faction_view._model.leader == setup._get_selected_faction_data().ruler, "existing ruler binding")
		await atlas_capture(str(resolution.x) + "-660-silla-selection")
		await choose("faction:goguryeo")
		check(setup.faction_view._model.leader == setup._get_selected_faction_data().ruler, "Goguryeo ruler binding")
		await atlas_capture(str(resolution.x) + "-660-goguryeo-selection")
	await choose("scenario:" + str(Scenarios.SCENARIOS[1].id))
	await choose("faction:silla")
	await choose("start")
	await create_timer(2).timeout
	c = current_scene
	c.event_presentation.display_level = "minimal"
	await settle_events()
	await pause()
	check(c.year == 642 and c.player_faction_id == "silla", "actual 642 Silla campaign")
	ui = c.settlement_overlay
	await pause()
	var map_view: Control = ui.map
	var initial: Dictionary = full_state()
	var coordinates: Dictionary = c.map_area.WORLD_CITY_MAP_UV.duplicate(true)
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await pause()
		check(map_view.get_visible_ids().size() == 35, "35 existing map sites")
		check(atlas_visible(ui._city_panel) and atlas_visible(ui.buttons.month), "card and next month fit")
		check(ui._city_panel.get_global_rect().encloses(ui.support.get_global_rect()) and ui._city_panel.get_global_rect().encloses(ui.buttons.cancel.get_global_rect()), "support actions remain inside card without scrolling")
		await click(ui.buttons.hide_city)
		check(not ui._city_panel.visible, "card closes")
		await click(ui.buttons.city_info)
		check(ui._city_panel.visible, "card reopens")
		await click(ui.buttons.overview)
		await atlas_capture(str(resolution.x) + "-overview")
		for city_id: String in ["dalgubeol", "geumseong", "siljik", "ulleung"]:
			map_view.focus_on_province(city_id, 5.0)
			await pause()
			var point: Vector2 = map_view.get_global_transform_with_canvas() * map_view.anchor(city_id)
			await mouse(point, MOUSE_BUTTON_LEFT, true)
			await mouse(point, MOUSE_BUTTON_LEFT, false)
			await pause()
			check(ui.selected == city_id and c.selected_province_id == city_id, "map click " + city_id)
		ui.select_city("geumseong")
		map_view.focus_on_province("geumseong", 4.2)
		await pause()
		var zoom_before: float = map_view.map_zoom
		await click(ui.buttons.zoom_in)
		check(map_view.map_zoom > zoom_before, "zoom button")
		await click(ui.buttons.zoom_out)
		var camera: Dictionary = map_view.get_view_state()
		for kind: String in ["domestic", "army", "production", "politics", "research"]:
			await click(ui.buttons[kind])
			var overlay_key: String = {"domestic": "domestic_overlay", "army": "army_overlay", "production": "production_overlay", "politics": "politics_overlay", "research": "industry_overlay"}[kind]
			check(c.get(overlay_key).visible and ui.visible and ui.suspended, "existing command " + kind)
			await escape()
			await pause()
			check(ui.visible and ui.selected == "geumseong" and map_view.get_view_state() == camera, "command return " + kind)
		await click(ui.buttons.menu)
		check(c.navigation_menu.get_popup().visible, "existing save menu")
		await escape()
		await pause()
		ui.select_city("dalgubeol")
		map_view.focus_region()
		select_value(ui.sources, "geumseong")
		await atlas_click_visible(ui.preview)
		check(ui.route_open and map_view.preview_source == "geumseong" and not ui.support.disabled, "existing support route")
		await atlas_capture(str(resolution.x) + "-support-card")
		await atlas_click_visible(ui.support)
		check(c.army_overlay.visible and c.army_overlay.city == "geumseong", "support opens real army selection")
		await escape()
		await pause()
		await atlas_click_visible(ui.buttons.cancel)
		check(full_state() == initial, "UI browsing preserves campaign state")
		check(c.map_area.WORLD_CITY_MAP_UV == coordinates, "world coordinates unchanged")
	print("LIGHT ATLAS GUI: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)
