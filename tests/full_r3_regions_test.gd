extends "res://tests/unified_atlas_test.gd"
const R3_OUT="res://.godot/full-r3-regions/"
var measurements: Array=[]

func capture_region(name: String) -> void:
	root.warp_mouse(Vector2(10,10))
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(10,10);root.push_input(motion,true)
	await pause();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(R3_OUT+name+".png")

func center_native(point: Vector2, zoom: float) -> void:
	ui.map.map_zoom=zoom;ui.map.map_pan_offset=Vector2.ZERO
	ui.map.map_pan_offset=ui.map.size*0.5-ui.map.map_to_local(point)
	ui.map._layout_city_buttons()

func _run() -> void:
	create_timer(420).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(R3_OUT)
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1280,720)
	await enter_setup();await choose("scenario:"+str(Scenarios.SCENARIOS[1].id));await choose("faction:silla");await choose("start")
	await create_timer(3).timeout;c=current_scene;await settle_events();ui=c.settlement_overlay
	check(ui.visible and c.year==642,"new 642 Silla directly opens bright atlas")
	check(ui.map.full_r3.tiles.size()==13 and ui.map.full_r3.errors.is_empty(),"13 decoded native tiles and source hashes")
	var before: Dictionary=full_state()
	var locations: Dictionary={"north":"pyongyang","central":"gukwon","south":"geumseong","jeju":"tamna"}
	for res: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=res;await pause()
		for area: String in locations:
			var city: String=locations[area]
			ui.select_city(city);ui.map.focus_on_province(city,5.0)
			var camera: Dictionary=ui.map.get_view_state()
			ui.map.full_r3.suppressed=true;ui.map.queue_redraw()
			await capture_region(str(res.x)+"-"+area+"-base")
			ui.map.full_r3.suppressed=false;ui.map.queue_redraw()
			await capture_region(str(res.x)+"-"+area+"-candidate")
			check(ui.map.get_view_state()==camera,"same camera "+area)
			measurements.append({"resolution":res.x,"area":area,"camera":camera,"diagnostics":ui.map.full_r3.diagnostics(ui.map.terrain_pixel_scale())})
		# Same camera, native rectangles and no new UI modes in the actual campaign.
		for tile: Dictionary in ui.map.full_r3.tiles:
			ui.map.full_r3.review_tile=tile.id
			center_native(tile.rect.get_center(),3.0 if tile.level=="overview" else 4.0)
			ui.map.full_r3.suppressed=true;ui.map.queue_redraw()
			await capture_region(str(res.x)+"-"+tile.id+"-base")
			ui.map.full_r3.suppressed=false;ui.map.queue_redraw()
			await capture_region(str(res.x)+"-"+tile.id+"-candidate")
		ui.map.full_r3.review_tile=""
		for city: String in ui.map.get_visible_ids():
			ui.map.focus_on_province(city,6.0);await pause()
			var point: Vector2=ui.map.get_global_transform_with_canvas()*ui.map.anchor(city)
			await mouse(point,MOUSE_BUTTON_LEFT,true);await mouse(point,MOUSE_BUTTON_LEFT,false)
			check(ui.selected==city,"actual castle selection "+city+" "+str(res.x))
		await click(ui.buttons.overview)
		check(ui.visible and is_equal_approx(ui.map.map_zoom,1.0),"whole view stays same atlas")
		ui.select_city("dalgubeol");ui.map.focus_region();select_value(ui.sources,"geumseong")
		check(ui.route_open and ui.map.preview_source=="geumseong","support route retained")
		await capture_region(str(res.x)+"-support")
		check(full_state()==before,"map review does not mutate campaign")
	var file:=FileAccess.open(R3_OUT+"measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"measurements":measurements,"checks":checks,"failures":failures},"\t"));file.close()
	print("FULL R3 REGIONS: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
