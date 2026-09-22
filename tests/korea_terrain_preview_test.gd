extends "res://tests/settlement_ui_test.gd"
const DRAFT_OUT = "res://.godot/korea-draft/"
var registrations: Array = []

func capture_draft(name: String) -> void:
	var e := InputEventMouseMotion.new(); e.position=Vector2(10,10); root.push_input(e,true)
	await pause(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DRAFT_OUT+name+".png")

func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(DRAFT_OUT)
	root.content_scale_size=Vector2i.ZERO
	await start(Scenarios.SCENARIOS[1],"silla","historical"); await settle_events(); await pause()
	ui=c.settlement_overlay; ui.open(); await pause()
	var m: Control=ui.map
	var before: Dictionary=full_state()
	var base: Texture2D=m.map_background.texture
	check(not m.korea_preview,"candidate is not default")
	await click(ui.buttons.korea_preview)
	check(m.korea_preview and not m.map_background.visible and m.map_background.texture==base,"preview isolates atlas without replacing world texture")
	check(m.terrain.texture.get_size()==Vector2(1024,1536),"native draft resolution")
	var a: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/map_review/korea_draft_v1/atlas_registration.json"))
	var mask:=Image.load_from_file(m.WorldMapData.TERRITORY_ID_MAP_PATH)
	for p: Dictionary in a.points:
		var uv: Vector2=m.WORLD_CITY_MAP_UV[p.id]
		check(uv.distance_to(Vector2(p.world_uv[0],p.world_uv[1]))<0.000001,"runtime registration "+p.id)
		var xy: Vector2=(uv*m.MAP_TEXTURE_SIZE-m.KOREA_RECT.position)/m.KOREA_RECT.size
		check(xy.distance_to(Vector2(p.atlas_uv[0],p.atlas_uv[1]))<0.000001,"atlas registration "+p.id)
		registrations.append({"id":p.id,"atlas_uv":[xy.x,xy.y],"old_mask_id":roundi(mask.get_pixelv(Vector2i(uv*Vector2(mask.get_size()))).a*255),"full_footprint_certified":false})
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await pause()
		await click(ui.buttons.overview)
		check(Rect2(Vector2.ZERO,m.size).encloses(Rect2(m.terrain.position,m.terrain.size)),"whole atlas fits preview viewport")
		await capture_draft(str(resolution.x)+"-whole-atlas")
		for id: String in ["dalgubeol","sabeol","juryuseong","tamna","ulleung","pyongyang","ansi"]:
			await click(m.city_buttons[id])
			check(ui.selected==id,"whole atlas click %s %d" % [id,resolution.x])
		for zoom: float in [1.0,3.0,5.0]:
			for id: String in ["dalgubeol","sabeol","juryuseong","tamna","ulleung","pyongyang","ansi"]:
				m.focus_on_province(id,zoom); await pause()
				var free: Vector2=m.global_position+m.size*Vector2(0.9,0.85)
				await mouse(free,MOUSE_BUTTON_LEFT,true)
				var motion:=InputEventMouseMotion.new(); motion.position=free+Vector2(-20,12); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; root.push_input(motion,true)
				await mouse(motion.position,MOUSE_BUTTON_LEFT,false)
				await click(m.city_buttons[id])
				check(ui.selected==id,"after drag click %s %d zoom %.0f" % [id,resolution.x,zoom])
				var rect: Rect2=m._get_displayed_map_rect()
				var b: Button=m.city_buttons[id]
				check((b.position+b.size*Vector2(0.5,0.67)).distance_to(m.anchor(id))<0.002 and m.terrain.position.is_equal_approx(rect.position+m.KOREA_RECT.position/m.MAP_TEXTURE_SIZE*rect.size),"shared ground and atlas transform")
				if zoom==5: await capture_draft(str(resolution.x)+"-"+id)
			await capture_draft(str(resolution.x)+"-level-"+str(int(zoom)))
		m.focus_on_province("dalgubeol",3)
		var point: Vector2=m.global_position+m.size*Vector2(0.9,0.85)
		await mouse(point,MOUSE_BUTTON_WHEEL_UP,true); await mouse(point,MOUSE_BUTTON_WHEEL_UP,false)
		check(m.map_zoom>3,"wheel zoom up")
		await mouse(point,MOUSE_BUTTON_WHEEL_DOWN,true); await mouse(point,MOUSE_BUTTON_WHEEL_DOWN,false)
		check(is_equal_approx(m.map_zoom,3),"wheel zoom down")
		check(ui.bottom.get_global_rect().end.y<=resolution.y,"preview controls fit viewport")
	# Render each of the 35 centers and actual castle sprites at near zoom.
	root.size=Vector2i(1280,720); await pause()
	for mode: String in ["terrain","castle"]:
		var sheet:=Image.create(1280,1400,false,Image.FORMAT_RGBA8)
		for i: int in range(a.points.size()):
			var id: String=a.points[i].id
			ui.select_city(id); m.focus_on_province(id,5); await pause()
			for b: Button in m.city_buttons.values(): b.get_child(0).visible=mode=="castle"
			await RenderingServer.frame_post_draw
			var picture: Image=root.get_texture().get_image()
			picture.convert(Image.FORMAT_RGBA8)
			var center: Vector2=m.global_position+m.anchor(id)
			sheet.blit_rect(picture,Rect2i(Vector2i(center)-Vector2i(128,95),Vector2i(256,200)),Vector2i(i%5*256,i/5*200))
		sheet.save_png(DRAFT_OUT+"all35-"+mode+".png")
	await click(ui.buttons.korea_preview)
	check(not m.korea_preview and m.map_background.visible and m.terrain.texture.resource_path.contains("coast_fix"),"return restores prior map")
	check(full_state()==before,"preview and input preserve all campaign data")
	var f:=FileAccess.open(DRAFT_OUT+"result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"registrations":registrations},"\t")); f.close()
	print("KOREA PREVIEW: ",checks," checks, ",failures," failures"); quit(0 if failures==0 else 1)
