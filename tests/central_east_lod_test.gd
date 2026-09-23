extends "res://tests/approved_castle_layout_test.gd"
const CENTRAL_OUT="res://.godot/central-east-lod/"
var measurements: Array=[]

func capture_central(name: String) -> void:
	var e:=InputEventMouseMotion.new(); e.position=Vector2(10,10);root.push_input(e,true)
	await pause();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(CENTRAL_OUT+name+".png")

func _run() -> void:
	create_timer(180).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(CENTRAL_OUT)
	root.content_scale_size=Vector2i.ZERO
	await start(Scenarios.SCENARIOS[1],"silla","historical");await settle_events();await pause()
	ui=c.settlement_overlay;await pause()
	var m: Control=ui.map
	var state: Dictionary=full_state()
	check(m._terrain.get_size()==Vector2(1254,1254) and m._detail_texture.get_size()==Vector2(1536,1024),"actual loaded native resolutions")
	check(m._terrain.get_image().has_mipmaps() and m._detail_texture.get_image().has_mipmaps(),"runtime mipmaps without source shrink")
	check(not m.detail_comparison and not m.detail_auto_allowed() and m.detail_weight()==0,"candidate never replaces default")
	for res: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=res;await pause()
		await click(ui.buttons.detail_focus)
		for zoom: float in [1.0,5.0,10.0]:
			m._set_map_zoom(zoom,m.size/2);await pause()
			var camera: Dictionary=m.get_view_state()
			await capture_central("%d-z%d-before" % [res.x,zoom])
			await click(ui.buttons.detail_compare)
			check(m.get_view_state()==camera and m.detail_weight()==1,"comparison preserves exact camera")
			check(m.map_to_local(m._detail_rect.position).is_equal_approx(m._get_displayed_map_rect().position+m._detail_rect.position/1254*m._get_displayed_map_rect().size),"detail uses approved native rectangle")
			await capture_central("%d-z%d-after" % [res.x,zoom])
			measurements.append({"resolution":res.x,"zoom":zoom,"diagnostics":m.detail_diagnostics()})
			await click(ui.buttons.detail_compare)
			check(not m.detail_auto_allowed() and m.detail_weight()==0,"leaving comparison restores original")
		for id: String in ["bukhansan","danghangseong","gukwon","haslla","siljik","jukryeong"]:
			m.focus_on_province(id,5);await pause()
			await click(ui.buttons.detail_compare)
			var pt: Vector2=m.get_global_transform_with_canvas()*m.anchor(id)
			await mouse(pt,MOUSE_BUTTON_LEFT,true);await mouse(pt,MOUSE_BUTTON_LEFT,false)
			check(ui.selected==id and c.selected_province_id==id,"unchanged castle click "+id)
			await click(ui.buttons.detail_compare)
		ui.select_city("siljik");m.focus_detail();await pause();await click(ui.preview)
		check(ui.route_open and m.preview_source==ui.source_id(),"existing support preview")
		await capture_central(str(res.x)+"-support")
		check(ui._city_panel.get_global_rect().end.y<=res.y and ui.buttons.month.get_global_rect().end.y<=res.y,"bottom UI fits")
		await click(ui.buttons.cancel)
		var scale: float=m.map_zoom
		var pt: Vector2=m.get_global_transform_with_canvas()*(m.size/2)
		await mouse(pt,MOUSE_BUTTON_WHEEL_UP,true);await mouse(pt,MOUSE_BUTTON_WHEEL_UP,false)
		check(m.map_zoom>scale and m.detail_weight()==0,"real wheel keeps unregistered detail blocked")
	# Controlled in-memory gate/transition test, not an art approval or production setting.
	var saved_manifest: Dictionary=m._detail_manifest.duplicate(true)
	m._detail_manifest.production_auto_switch_allowed=true
	check(not m.detail_auto_allowed(),"flag alone cannot authorize candidate")
	m._detail_manifest.status="registered";m._detail_manifest.registered_detail_sha256=m._detail_hash
	for pixel_scale: float in [1.0,1.75,2.5]:
		m._set_map_zoom(pixel_scale/(m._fit_scale()*m.get_screen_transform().x.length()),m.size/2)
		var expected: float=smoothstep(1.5,2.0,pixel_scale)
		check(absf(m.detail_weight()-expected)<0.001,"controlled registered LOD weight %.2f" % expected)
	m._detail_manifest=saved_manifest
	root.content_scale_size=Vector2i(1920,1080);root.size=Vector2i(1280,720);await pause()
	m._set_map_zoom(5,m.size/2)
	check(absf(m.terrain_pixel_scale()/(m._fit_scale()*m.map_zoom)-2.0/3.0)<0.01,"pixel density includes viewport stretch")
	check(not m.detail_auto_allowed() and full_state()==state,"fixture discarded and game state preserved")
	var f:=FileAccess.open(CENTRAL_OUT+"result.json",FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":measurements},"\t"));f.close()
	print("CENTRAL LOD: ",checks," checks, ",failures," failures");quit(0 if failures==0 else 1)
