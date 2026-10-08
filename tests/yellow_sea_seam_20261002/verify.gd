extends "res://tests/faction_selection_ui_v1_test.gd"
const SEA_OUT = "res://tests/yellow_sea_seam_20261002/"
func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	await enter_setup()
	await choose("faction:silla")
	await choose("start")
	await create_timer(3).timeout
	c = current_scene
	await settle_events()
	ui = c.settlement_overlay
	ui.select_city("pyongyang")
	var map: Control = ui.map
	var before := full_state()
	map.set_process(false) # Freeze edge panning for identical before/after framing.
	var new_tile: Shader = map.unified_ground.tiles[0].material.shader
	var old_tile := Shader.new()
	old_tile.code = FileAccess.get_file_as_string(SEA_OUT+"tile_before.gdshader")
	var new_base: Shader = map.unified_ground.korea.material.shader
	var new_detail: Shader = map.refreshed_detail.tiles[0].material.shader
	var old_base := Shader.new()
	old_base.code = FileAccess.get_file_as_string(SEA_OUT+"korea_before.gdshader")
	var old_detail := Shader.new()
	old_detail.code = FileAccess.get_file_as_string(SEA_OUT+"detail_before.gdshader")
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size = resolution
		await pause()
		for view: String in ["overview","west","jeju"]:
			var center := Vector2(350,550)
			var zoom := 0.9
			if view == "west":
				center = Vector2(200,800)
				zoom = 4.0
			elif view == "jeju":
				center = Vector2(530,1120)
				zoom = 3.0
			map.restore_view_state({"selected":"pyongyang","zoom":zoom,"center_native":[center.x,center.y]})
			for phase: String in ["before","after"]:
				for tile: TextureRect in map.unified_ground.tiles:
					tile.material.shader = old_tile if phase == "before" else new_tile
				map.unified_ground.korea.material.shader = old_base if phase == "before" else new_base
				for tile: TextureRect in map.refreshed_detail.tiles:
					tile.material.shader = old_detail if phase == "before" else new_detail
				await pause()
				await RenderingServer.frame_post_draw
				check(root.get_texture().get_image().save_png(SEA_OUT+str(resolution.x)+"-"+view+"-"+phase+".png") == OK,"sea capture "+str(resolution.x)+" "+view+" "+phase)
	check(full_state() == before,"visual comparison leaves campaign state unchanged")
	print("YELLOW SEA: ",checks," checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
