extends "res://tests/settlement_ui_test.gd"
const EAST_OUT = "res://.godot/east-coast-zoom/"
var rows: Array = []

func capture_east(name: String) -> void:
	var cursor := InputEventMouseMotion.new(); cursor.position=Vector2(10,10); root.push_input(cursor,true)
	await pause(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(EAST_OUT+name+".png")

func _run() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(EAST_OUT)
	root.content_scale_size = Vector2i.ZERO
	await start(Scenarios.SCENARIOS[1], "silla", "historical"); await settle_events(); await pause()
	ui = c.settlement_overlay
	await click(c.settlement_button)
	var m: Control = ui.map
	var before: Dictionary = full_state()
	var registration: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/map_review/east_coast_detail_v1/detail_registration.json"))
	check(not m.east_detail.visible and not m.korea_preview,"default map preserved")
	check(FileAccess.get_sha256(m.EAST_DETAIL)==registration.asset_sha256,"source SHA256 matches registration")
	var original := Image.new()
	original.load_png_from_buffer(FileAccess.get_file_as_bytes(m.EAST_DETAIL))
	var rendered: Image = m.east_detail.texture.get_image()
	check(rendered.has_mipmaps(),"detail has same-source mip levels")
	rendered.clear_mipmaps()
	original.convert(Image.FORMAT_RGBA8); rendered.convert(Image.FORMAT_RGBA8)
	check(rendered.get_size()==Vector2i(1254,1254) and rendered.get_data()==original.get_data(),"loaded texture pixels match new original PNG")
	check(m.fortress.resource_path=="res://assets/ui_handoff/korean_fortress_demo_rgba.png","unchanged castle source")
	for p: Dictionary in registration.points:
		check(m.WORLD_CITY_MAP_UV[p.id].distance_to(Vector2(p.world_uv[0],p.world_uv[1]))<0.000001,"unchanged UV "+p.id)
	await click(ui.buttons.korea_preview)
	check(not m.east_detail.visible,"detail is opt in")
	check(m.terrain.texture.get_image().has_mipmaps(),"overview has same-source mip levels")
	await click(ui.buttons.east_detail)
	var detail_texture: Texture2D=m.east_detail.texture
	var overview_texture: Texture2D=m.terrain.texture
	for scale: float in [0.3,0.7,1.0,2.0,3.0,4.0,5.0,2.0,0.7]:
		m._set_map_zoom(scale,m.size/2)
		var world: Rect2=m._get_displayed_map_rect()
		check(m.east_detail.visible and m.east_detail.texture==detail_texture and m.terrain.texture==overview_texture,"zoom never switches terrain source")
		check(((m.east_detail.position-world.position)/world.size*m.MAP_TEXTURE_SIZE).distance_to(m.EAST_RECT.position)<0.02,"same coastline world registration across zoom")
	await click(ui.buttons.east_detail)
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await pause()
		for zoom: float in [0.0,3.0,5.0]:
			if zoom==0: await click(ui.buttons.overview)
			else: m.focus_on_province("ulleung",zoom)
			await pause()
			await capture_east("%d-zoom%d-before" % [resolution.x,zoom])
			await click(ui.buttons.east_detail)
			check(m.east_detail.visible and m.east_detail.texture.resource_path==m.EAST_DETAIL,"new detail shown")
			var point: Vector2=m.global_position+m.size*Vector2(0.85,0.8)
			await mouse(point,MOUSE_BUTTON_WHEEL_UP,true); await mouse(point,MOUSE_BUTTON_WHEEL_UP,false)
			await mouse(point,MOUSE_BUTTON_WHEEL_DOWN,true); await mouse(point,MOUSE_BUTTON_WHEEL_DOWN,false)
			check(m.east_detail.visible and m.east_detail.texture.resource_path==m.EAST_DETAIL,"wheel retains same detail asset")
			await mouse(point,MOUSE_BUTTON_LEFT,true)
			var motion:=InputEventMouseMotion.new(); motion.position=point+Vector2(-18,10); motion.button_mask=MOUSE_BUTTON_MASK_LEFT
			root.push_input(motion,true); await mouse(motion.position,MOUSE_BUTTON_LEFT,false)
			for id: String in ["siljik","ulleung","geumseong"]:
				if zoom>0: m.focus_on_province(id,zoom)
				var prior_pan: Vector2=m.map_pan_offset
				await mouse(point,MOUSE_BUTTON_LEFT,true)
				root.push_input(motion,true); await mouse(motion.position,MOUSE_BUTTON_LEFT,false)
				check(m.map_pan_offset.distance_to(prior_pan)>1,"drag moves world before selection")
				await click(m.city_buttons[id])
				check(ui.selected==id and c.selected_province_id==id,"actual selection "+id)
				var ground: Vector2=m.global_position+m.anchor(id)
				await mouse(ground,MOUSE_BUTTON_LEFT,true); await mouse(ground,MOUSE_BUTTON_LEFT,false)
				check(ui.selected==id,"ground marker click "+id)
				var r: Rect2=m._get_displayed_map_rect()
				var b: Button=m.city_buttons[id]
				var expected: Vector2=r.position+m.EAST_RECT.position/m.MAP_TEXTURE_SIZE*r.size
				check(expected.distance_to(m.east_detail.position)<0.002 and (m.EAST_RECT.size/m.MAP_TEXTURE_SIZE*r.size).distance_to(m.east_detail.size)<0.002,"full-world detail transform")
				check((b.position+b.size*Vector2(0.5,0.67)).distance_to(m.anchor(id))<0.002,"castle pivot preserved")
				var art: TextureRect=b.get_child(0)
				check(absf(art.size.x/r.size.x*6144-130)<0.001,"castle scales exactly with terrain")
				check((b.position+art.position+art.size*Vector2(0.5,0.67)).distance_to(m.anchor(id))<0.002,"independent artwork ground pivot")
				check(b.size.x>=32 and art.visible==(art.size.x>=m.CASTLE_MARKER_THRESHOLD),"independent hit minimum and far marker")
				rows.append({"resolution":resolution.x,"zoom":m.map_zoom,"id":id,"sprite_px":art.size.x,"hit_px":b.size.x,"marker":not art.visible,"effective_world_width":art.size.x/r.size.x*6144})
				await capture_east("%d-zoom%d-%s" % [resolution.x,zoom,id])
				if zoom==5:
					for button: Button in m.city_buttons.values(): button.get_child(0).hide()
					await capture_east("%d-ground-%s" % [resolution.x,id])
					for button: Button in m.city_buttons.values(): button.get_child(0).show()
			check(ui.bottom.get_global_rect().end.y<=resolution.y,"UI fits viewport")
			await click(ui.buttons.east_detail)
			check(not m.east_detail.visible and m.korea_preview,"comparison returns to overview asset")
	await click(ui.buttons.east_detail)
	await click(ui.buttons.korea_preview)
	check(not m.east_detail.visible and not m.east_comparison and m.map_background.visible,"close clears detail and restores map")
	check(full_state()==before,"campaign data unchanged")
	var f:=FileAccess.open(EAST_OUT+"result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"path":m.EAST_DETAIL,"sha256":FileAccess.get_sha256(m.EAST_DETAIL),"castle_source":m.fortress.resource_path,"castle_source_size":[m.fortress.get_width(),m.fortress.get_height()],"measurements":rows},"\t")); f.close()
	print("EAST DETAIL: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
