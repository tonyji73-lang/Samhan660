extends "res://tests/full_r3_regions_test.gd"
const SOUTH_OUT="res://tests/art_review/south_r3_v1/game_captures/"
var observations: Array=[]
var click_ids: Array[String]=[]

func snap(name: String) -> void:
	root.warp_mouse(Vector2(10,10))
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(10,10);root.push_input(motion,true)
	await pause();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(SOUTH_OUT+name+".png")

func point_for(city: String) -> Vector2:
	return ui.map.get_global_transform_with_canvas()*ui.map.anchor(city)

func wheel_to(city: String,target: float) -> void:
	for attempt in range(20):
		if ui.map.map_zoom>=target-0.001:break
		var point:=point_for(city)
		await mouse(point,MOUSE_BUTTON_WHEEL_UP,true);await mouse(point,MOUSE_BUTTON_WHEEL_UP,false)
	await pause()

func _run() -> void:
	create_timer(240).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(SOUTH_OUT)
	root.content_scale_size=Vector2i.ZERO
	await start(Scenarios.SCENARIOS[1],"silla","historical");await settle_events();ui=c.settlement_overlay
	ui.map.settlement_selected.connect(func(id: String):click_ids.append(id))
	var before: Dictionary=full_state()
	var layer=ui.map.full_r3
	var south: Dictionary=layer.tiles.filter(func(t):return t.id=="detail_2_2")[0]
	var jeju: Dictionary=layer.tiles.filter(func(t):return t.id=="detail_3_1")[0]
	check(south.has("registered_mesh") and layer.errors.is_empty(),"south review UV loads through actual renderer")
	check(not layer.approved(south) and layer.weight(south,20)==0,"unresolved south cannot enter production LOD")
	check(layer.approved(jeju),"existing Jeju approval retained")
	check(FileAccess.get_sha256("res://ui/korea_layout_v1/data/castle_layout_v1.json")=="b199ee4a532d37e1bb15cbf0d018d86ac964116bea7731b4d32644796d53d654","immutable city coordinate and size data")
	for res: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=res;await pause()
		for city: String in ["dalgubeol","geumseong","daegaya"]:
			ui.select_city(city)
			if ui._city_panel.visible:await click(ui.buttons.city_info)
			ui.map.focus_on_province(city,2.0);await pause()
			layer.review=true;layer.review_tile="detail_2_2"
			for level: String in ["wide","middle","max"]:
				if level=="middle":await wheel_to(city,4.9)
				if level=="max":await wheel_to(city,12.0)
				var camera: Dictionary=ui.map.get_view_state()
				for mode: String in ["base","raw","uv"]:
					layer.suppressed=mode=="base";layer.registered_review=mode=="uv";ui.map.queue_redraw()
					await snap("%d-%s-%s-%s" % [res.x,city,level,mode])
					check(ui.map.get_view_state()==camera,"same camera "+city+" "+level+" "+mode+" "+str(res.x))
				var point:=point_for(city)
				var native: Vector2=ui.map.local_to_map(ui.map.anchor(city))
				var events_before:=click_ids.size()
				await mouse(point,MOUSE_BUTTON_LEFT,true);await mouse(point,MOUSE_BUTTON_LEFT,false);await pause()
				check(ui.selected==city and click_ids.size()==events_before+1 and click_ids[-1]==city,"real mouse selection signal "+city+" "+level+" "+str(res.x))
				check(ui.map.local_to_map(ui.map.anchor(city)).distance_to(native)<0.001,"zoom/click preserves native anchor")
				observations.append({"resolution":[res.x,res.y],"city":city,"level":level,"zoom":ui.map.map_zoom,"camera":camera,"diagnostics":layer.diagnostics(ui.map.terrain_pixel_scale())})
				if ui._city_panel.visible:await click(ui.buttons.city_info)
			var zoom_before: float=ui.map.map_zoom
			for i in range(5):
				var point:=point_for(city);await mouse(point,MOUSE_BUTTON_WHEEL_DOWN,true);await mouse(point,MOUSE_BUTTON_WHEEL_DOWN,false)
			check(ui.map.map_zoom<zoom_before,"real wheel zoom out "+city)
		# Cross both southern tile boundaries by dragging; keep actual UI unmodified.
		layer.review_tile="";layer.registered_review=true;center_native(Vector2(630,900),5.0);await pause()
		await snap(str(res.x)+"-boundary-before")
		var pan: Vector2=ui.map.map_pan_offset
		var drag: Vector2=ui.map.get_global_transform_with_canvas()*Vector2(1100,520)
		await mouse(drag,MOUSE_BUTTON_LEFT,true)
		var motion:=InputEventMouseMotion.new();motion.position=drag+Vector2(100,70);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true)
		await mouse(motion.position,MOUSE_BUTTON_LEFT,false);await pause()
		check(ui.map.map_pan_offset.distance_to(pan)>20,"actual drag across south boundary "+str(res.x))
		await snap(str(res.x)+"-boundary-after")
		ui.select_city("dalgubeol");ui.map.focus_region();select_value(ui.sources,"geumseong")
		check(ui.route_open and ui.map.preview_source=="geumseong","support preview uses unchanged city path")
		await snap(str(res.x)+"-support-uv-review")
		layer.review=false;layer.suppressed=false;ui.map.queue_redraw();await pause()
		check("detail_2_2" not in layer.last_drawn,"normal play retains base in unapproved south")
		await snap(str(res.x)+"-support-production")
		# Narrow regression for the existing, approved island only.
		ui.select_city("tamna");ui.map.focus_on_province("tamna",2.0)
		if ui._city_panel.visible:await click(ui.buttons.city_info)
		await pause();check(layer.weight(jeju,ui.map.terrain_pixel_scale())==0,"Jeju wide view retains base")
		await wheel_to("tamna",5.0);await pause()
		check(layer.last_drawn==["detail_3_1"] and layer.weight(jeju,ui.map.terrain_pixel_scale())==1,"Jeju automatic detail remains working")
		await snap(str(res.x)+"-jeju-retained")
		check(full_state()==before,"review, selection and route browsing do not mutate campaign")
	var f:=FileAccess.open(SOUTH_OUT+"results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"pid":OS.get_process_id(),"method":"Godot GUI automated input; not human manual play","observations":observations},"\t"));f.close()
	print("SOUTH R3 GUI: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
