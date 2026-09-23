extends "res://tests/south_r3_registration_test.gd"
const V3_OUT="res://tests/art_review/south_v3/production/"
var records: Array=[]
var snapshots: Array=[]
func enter_setup() -> void:
	# Drain native tooltip/window updates before freeing the prior campaign.
	root.warp_mouse(Vector2(10,10))
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(10,10);root.push_input(motion,true)
	await pause()
	await super.enter_setup()
func snap(name: String) -> void:
	root.warp_mouse(Vector2(10,10))
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(10,10);root.push_input(motion,true)
	await pause();await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(V3_OUT+name+".png")==OK,"capture "+name)
	records.append({"name":name,"selected":ui.selected,"camera":ui.map.get_view_state(),"v3":ui.map.south_v3.diagnostics(),"old_layers":ui.map.full_r3.last_drawn})
func _run() -> void:
	create_timer(300).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(V3_OUT);root.content_scale_size=Vector2i.ZERO
	check(OS.get_cmdline_user_args().is_empty(),"no developer review arguments")
	for scenario_index: int in [0,1]:
		for res: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
			root.size=res
			await enter_setup();await choose("scenario:"+str(Scenarios.SCENARIOS[scenario_index].id));await choose("faction:silla");await choose("start")
			await create_timer(3).timeout;c=current_scene;await settle_events();ui=c.settlement_overlay
			var year: int=c.year;var prefix: String=str(year)+"-"+str(res.x)
			var layer=ui.map.south_v3;var before: Dictionary=full_state()
			check(layer.approved and not layer.review and not ui.map.full_r3.review and not ui.map.full_r3.south_v2_review,"normal campaign loads pinned inland approval "+prefix)
			check(layer.error.is_empty() and ui.map.material==null and ui.map.terrain_canvas.material==null and layer.material is ShaderMaterial,"shader only belongs to separate terrain child")
			ui.map.settlement_selected.connect(func(id: String):click_ids.append(id))
			for city: String in ["geumseong","dalgubeol","daegaya"]:
				ui.select_city(city)
				if ui._city_panel.visible:await click(ui.buttons.city_info)
				ui.map.focus_on_province(city,2);await pause()
				check(layer.weight==0 and layer.material.get_shader_parameter("lod_weight")==0,"wide original "+city)
				await snap(prefix+"-"+city+"-wide")
				var weights: Array=[]
				for i in range(9):
					var point:=point_for(city);await mouse(point,MOUSE_BUTTON_WHEEL_UP,true);await mouse(point,MOUSE_BUTTON_WHEEL_UP,false);await pause()
					weights.append(layer.weight)
					if layer.weight==1 and ui.map.map_zoom>=5:break
				check(weights.has(1.0) and weights.filter(func(v):return v>0 and v<1).size()>0,"real wheel sends intermediate and full shader LOD "+city)
				await wheel_to(city,9)
				check(layer.drawn and is_equal_approx(layer.weight,layer.material.get_shader_parameter("lod_weight")),"actual production layer and material weight "+city)
				var native: Vector2=ui.map.local_to_map(ui.map.anchor(city))
				check(layer.coverage_at(native)==(0.0 if city=="daegaya" else 1.0),"local coverage/original exclusion "+city)
				var n:=click_ids.size();var point:=point_for(city)
				await mouse(point,MOUSE_BUTTON_LEFT,true);await mouse(point,MOUSE_BUTTON_LEFT,false);await pause()
				check(click_ids.size()==n+1 and click_ids[-1]==city,"normal castle click "+city)
				if ui._city_panel.visible:await click(ui.buttons.city_info)
				await snap(prefix+"-"+city+"-near")
				await click(ui.buttons.overview);await pause();check(layer.weight==0,"zoom back to whole uses original")
			# The complete sprite rectangle, not merely its center, lies in full coverage.
			for box: Rect2 in [Rect2(686.69,797.5046,24.62,24.62),Rect2(734.69,808.5046,24.62,24.62)]:
				var covered:=true
				for y in range(26):
					for x in range(26):
						if layer.coverage_at(box.position+box.size*Vector2(x,y)/25.0)<0.999:covered=false
				check(covered,"whole fixed castle rectangle has full registered terrain coverage")
			ui.select_city("dalgubeol");ui.map.focus_region();select_value(ui.sources,"geumseong")
			check(ui.route_open and ui.map.preview_source=="geumseong","normal support route")
			await snap(prefix+"-support")
			var view: Dictionary=ui.map.get_view_state()
			await click(ui.support);check(c.army_overlay.visible,"normal support screen opens")
			await escape();await pause();check(ui.map.get_view_state()==view,"command return keeps camera and selected city")
			ui.select_city("tamna");ui.map.focus_on_province("tamna",5);await pause()
			check(ui.map.full_r3.last_drawn==["detail_3_1"],"Jeju automatic LOD still active")
			await snap(prefix+"-jeju")
			check(full_state()==before,"display tests preserve campaign")
			ui.select_city("geumseong");ui.map.focus_on_province("geumseong",9);await pause()
			var slot: String="user://south_v3_%d_%d_%d_%d.json" % [Time.get_unix_time_from_system(),OS.get_process_id(),year,res.x]
			check(c._on_save_button_pressed(slot),"separate test save")
			snapshots.append({"slot":slot,"year":year,"resolution":res.x,"state":full_state(),"view":ui.map.get_view_state()})
	var f:=FileAccess.open(V3_OUT+"results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"pid":OS.get_process_id(),"checks":checks,"failures":failures,"snapshots":snapshots,"records":records},"\t"));f.close()
	print("SOUTH V3 NORMAL PLAY ",checks," checks ",failures," failures")
	quit(0 if failures==0 else 1)
