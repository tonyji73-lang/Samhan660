extends "res://tests/full_r3_regions_test.gd"
var saved_records: Array=[]

func _run() -> void:
	create_timer(180).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(R3_OUT)
	root.content_scale_size=Vector2i.ZERO
	for res: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=res
		await enter_setup();await choose("scenario:"+str(Scenarios.SCENARIOS[1].id));await choose("faction:silla");await choose("start")
		await create_timer(3).timeout;c=current_scene;await settle_events();ui=c.settlement_overlay
		check(ui.visible and not ui.map.full_r3.review,"normal new game directly opens production atlas")
		check(not ui.buttons.has("view_options") and not ui.buttons.has("detail_r3") and not ui.buttons.has("close"),"no separate map/candidate UI")
		var layer=ui.map.full_r3
		var approved_tiles: Array=layer.tiles.filter(func(t):return layer.approved(t))
		check(approved_tiles.size()==1 and approved_tiles[0].id=="detail_3_1","only reviewed island patch is eligible")
		var before: Dictionary=full_state()
		ui.select_city("tamna");ui.map.focus_on_province("tamna",2.0);await pause()
		var tile: Dictionary=approved_tiles[0]
		check(layer.weight(tile,ui.map.terrain_pixel_scale())==0,"wide view uses approved base")
		# At low zoom the southern image edge clamps the camera, so the island
		# is below the viewport center. Wheel over the island the player sees.
		var point: Vector2=ui.map.get_global_transform_with_canvas()*ui.map.anchor("tamna")
		var weights: Array=[]
		for i in range(7):
			point=ui.map.get_global_transform_with_canvas()*ui.map.anchor("tamna")
			await mouse(point,MOUSE_BUTTON_WHEEL_UP,true);await mouse(point,MOUSE_BUTTON_WHEEL_UP,false)
			weights.append(layer.weight(tile,ui.map.terrain_pixel_scale()))
			if ui.map.terrain_pixel_scale()>3.0:break
		check(weights[-1]==1.0 and weights.filter(func(w):return w>0 and w<1).size()>0,"real wheel crosses intermediate and full detail weights")
		await pause()
		check(layer.last_drawn==["detail_3_1"],"production renders only registered patch")
		await capture_region(str(res.x)+"-jeju-production-near")
		var anchor: Vector2=ui.map.get_global_transform_with_canvas()*ui.map.anchor("tamna")
		await mouse(anchor,MOUSE_BUTTON_LEFT,true);await mouse(anchor,MOUSE_BUTTON_LEFT,false)
		check(ui.selected=="tamna","registered terrain keeps actual Tamna selection")
		var pan: Vector2=ui.map.map_pan_offset
		await mouse(point,MOUSE_BUTTON_LEFT,true)
		var motion:=InputEventMouseMotion.new();motion.position=point+Vector2(90,40);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true)
		await mouse(motion.position,MOUSE_BUTTON_LEFT,false);await pause()
		check(ui.map.map_pan_offset.distance_to(pan)>20,"actual boundary drag moves one shared terrain camera")
		await capture_region(str(res.x)+"-jeju-production-pan")
		await click(ui.buttons.overview)
		check(ui.visible and is_equal_approx(ui.map.map_zoom,1.0) and layer.last_drawn.is_empty(),"whole view is same atlas and detail fades out")
		ui.select_city("dalgubeol");ui.map.focus_region();select_value(ui.sources,"geumseong")
		check(ui.route_open and ui.map.preview_source=="geumseong","production support route uses original cities")
		var view: Dictionary=ui.map.get_view_state()
		await click(ui.support);check(c.army_overlay.visible,"support opens existing army command")
		await escape();await pause();check(ui.map.get_view_state()==view,"command return preserves camera")
		check(full_state()==before,"terrain and support browsing preserve simulation")
		ui.select_city("tamna");ui.map.focus_on_province("tamna",5.0);await pause()
		var slot: String="user://full_r3_%d_%d_%d.json" % [Time.get_unix_time_from_system(),OS.get_process_id(),res.x]
		check(c._on_save_button_pressed(slot),"separate test save")
		var saved: Dictionary=full_state();view=ui.map.get_view_state()
		saved_records.append({"resolution":res.x,"slot":slot,"state":saved,"view":view})
		await load_from_title(slot)
		check(ui.visible and ui.selected=="tamna" and full_state()==saved,"title load directly restores atlas and real campaign state")
		check(ui.map.full_r3.last_drawn==["detail_3_1"],"title load restores automatic island detail")
		await capture_region(str(res.x)+"-production-loaded")
	var file:=FileAccess.open(R3_OUT+"play.json",FileAccess.WRITE);file.store_string(JSON.stringify({"pid":OS.get_process_id(),"records":saved_records,"checks":checks,"failures":failures},"\t"));file.close()
	print("FULL R3 PLAY: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
