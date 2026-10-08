extends "res://tests/faction_selection_ui_v1_test.gd"
const ART_REVIEW = "res://tests/map_art_20261001/"

func art_capture(label: String) -> void:
	await pause()
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ART_REVIEW+label+".png") == OK, "capture " + label)

func _run() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	root.content_scale_size = Vector2i.ZERO
	await enter_setup()
	await choose("faction:silla")
	await choose("start")
	await create_timer(3).timeout
	c = current_scene
	await settle_events()
	ui = c.settlement_overlay
	var before: Dictionary = full_state()
	var map: Control = ui.map
	check(FileAccess.get_sha256(map.RESOURCE_DIR+"assets/korea_approved_1254.png") == "36594c1d1ee0cbcd80a175d72790d3e22423103cf81d6b191f8bf2d317e1f246", "original terrain unchanged")
	for tile: TextureRect in map.refreshed_detail.tiles:
		check(tile.texture.get_width() > 650 and tile.texture.get_height() > 650, "generated detail density exceeds source")
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		await pause()
		for id: String in ["pyongyang","gukwon","sabi","geumseong"]:
			map.focus_on_province(id,6)
			await pause()
			map.refreshed_detail.suppressed = true
			map.queue_redraw()
			await art_capture(str(resolution.x)+"-"+id+"-before")
			map.refreshed_detail.suppressed = false
			map.queue_redraw()
			await art_capture(str(resolution.x)+"-"+id+"-after")
			check(map.refreshed_detail.weight > 0.9, "detail active " + id)
			var point: Vector2 = map.get_global_transform_with_canvas() * map.anchor(id)
			await mouse(point,MOUSE_BUTTON_LEFT,true)
			await mouse(point,MOUSE_BUTTON_LEFT,false)
			check(c.selected_province_id == id, "unchanged actual castle click " + id)
		map.fit_all()
		await pause()
		check(is_zero_approx(map.refreshed_detail.weight), "original overview preserved")
		await art_capture(str(resolution.x)+"-korea-overview")
		await click(ui.buttons.overview)
		check(ui.world_view and c.map_area.map_background.texture.resource_path.ends_with("terrain_refresh_20261001/east_asia.png"), "new world art displayed")
		await art_capture(str(resolution.x)+"-world")
		await escape()
		check(ui.visible and not ui.world_view, "world return")
		check(full_state() == before, "map changes do not alter campaign")
	var file := FileAccess.open(ART_REVIEW+"results.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info().string},"\t"))
	print("MAP ART REFRESH: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
