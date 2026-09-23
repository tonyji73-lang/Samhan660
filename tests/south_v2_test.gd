extends "res://tests/south_r3_registration_test.gd"
const V2_OUT="res://tests/art_review/south_v2/game_captures/"
var pairs: Array=[]

func snap(name: String) -> void:
	root.warp_mouse(Vector2(10,10))
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(10,10);root.push_input(motion,true)
	await pause();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(V2_OUT+name+".png")==OK,"capture "+name)

func compare(name: String) -> void:
	var camera: Dictionary=ui.map.get_view_state()
	ui.map.full_r3.suppressed=true;ui.map.queue_redraw();await snap(name+"-base")
	ui.map.full_r3.suppressed=false;ui.map.queue_redraw();await snap(name+"-v2")
	check(ui.map.get_view_state()==camera,"same camera "+name)
	check("south_continuous_v2" in ui.map.full_r3.last_drawn,"actual new PNG draw "+name)
	check("detail_2_2" not in ui.map.full_r3.last_drawn,"no old south underneath new patch")
	pairs.append({"name":name,"camera":camera,"zoom":ui.map.map_zoom,"diagnostics":ui.map.full_r3.diagnostics(ui.map.terrain_pixel_scale())})

func _run() -> void:
	create_timer(300).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(V2_OUT)
	root.content_scale_size=Vector2i.ZERO
	await start(Scenarios.SCENARIOS[1],"silla","historical");await settle_events();ui=c.settlement_overlay
	ui.map.settlement_selected.connect(func(id: String):click_ids.append(id))
	var before: Dictionary=full_state()
	var layer=ui.map.full_r3
	check(layer.errors.is_empty() and layer.south_v2.size()>0,"v2 loaded and hash/size verified")
	check(layer.south_v2.texture.get_size()==Vector2(1346,1168) and layer.south_v2.rect==Rect2(560,740,300,260),"actual decoded pixels and native patch rectangle")
	var arrays: Array=layer.south_v2.mesh.surface_get_arrays(0)
	check(arrays[Mesh.ARRAY_TEX_UV]==PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]),"identity UV; old 12-point warp not applied")
	check(FileAccess.get_sha256("res://ui/korea_layout_v1/data/castle_layout_v1.json")=="b199ee4a532d37e1bb15cbf0d018d86ac964116bea7731b4d32644796d53d654","all city coordinates/widths unchanged")
	check(FileAccess.get_sha256("res://ui/korea_layout_v1/full_r3_v1/jeju_registration.json")=="c6566173dd01cfcf8880aab646fa962a9ec3258a9788957a1fa15b9903b0b33f","Jeju mesh unchanged")
	for res: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=res;await pause();layer.south_v2_review=true
		for city: String in ["dalgubeol","geumseong","daegaya"]:
			ui.select_city(city)
			if ui._city_panel.visible:await click(ui.buttons.city_info)
			ui.map.focus_on_province(city,2.0);await pause()
			for level: String in ["wide","middle","max"]:
				if level=="middle":await wheel_to(city,4.9)
				if level=="max":await wheel_to(city,12)
				await compare("%d-%s-%s" % [res.x,city,level])
				var point:=point_for(city);var count_before:=click_ids.size()
				await mouse(point,MOUSE_BUTTON_LEFT,true);await mouse(point,MOUSE_BUTTON_LEFT,false);await pause()
				check(click_ids.size()==count_before+1 and click_ids[-1]==city and ui.selected==city,"real selection "+city+" "+level)
				if ui._city_panel.visible:await click(ui.buttons.city_info)
			var zoom: float=ui.map.map_zoom
			for i in range(5):
				var point:=point_for(city);await mouse(point,MOUSE_BUTTON_WHEEL_DOWN,true);await mouse(point,MOUSE_BUTTON_WHEEL_DOWN,false)
			check(ui.map.map_zoom<zoom,"actual wheel zoom out "+city)
		var targets: Dictionary={"outer-west":Vector2(560,850),"outer-east":Vector2(860,850),"outer-north":Vector2(710,740),"outer-south":Vector2(710,1000),"estuary":Vector2(685,935),"cape":Vector2(805,820),"old-crossing":Vector2(600,900)}
		for area: String in targets:
			center_native(targets[area],6);await compare(str(res.x)+"-"+area)
		var pan: Vector2=ui.map.map_pan_offset
		var drag: Vector2=ui.map.get_global_transform_with_canvas()*Vector2(1100,520)
		await mouse(drag,MOUSE_BUTTON_LEFT,true)
		var motion:=InputEventMouseMotion.new();motion.position=drag+Vector2(100,70);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true)
		await mouse(motion.position,MOUSE_BUTTON_LEFT,false);await pause()
		check(ui.map.map_pan_offset.distance_to(pan)>20,"actual boundary drag")
		await snap(str(res.x)+"-boundary-drag")
		ui.select_city("dalgubeol");ui.map.focus_region();select_value(ui.sources,"geumseong")
		check(ui.route_open and ui.map.preview_source=="geumseong","support route retains city IDs")
		await snap(str(res.x)+"-support-v2")
		layer.south_v2_review=false;ui.map.queue_redraw();await pause()
		check("south_continuous_v2" not in layer.last_drawn,"unapproved v2 never auto-enabled in production")
		await snap(str(res.x)+"-production")
		ui.select_city("tamna");ui.map.focus_on_province("tamna",2)
		if ui._city_panel.visible:await click(ui.buttons.city_info)
		await pause();check(layer.last_drawn.is_empty(),"Jeju wide uses base")
		await wheel_to("tamna",5);await pause()
		check(layer.last_drawn==["detail_3_1"],"Jeju automatic LOD retained")
		await snap(str(res.x)+"-jeju")
		check(full_state()==before,"display/input do not change campaign")
	var f:=FileAccess.open(V2_OUT+"results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"pid":OS.get_process_id(),"method":"Godot GUI automatic input, not human manual play","pairs":pairs},"\t"));f.close()
	print("SOUTH V2: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
