extends SceneTree
var checks: int=0
var failures: int=0
var evidence: Array=[]
const OUT="res://.godot/coast-review/"
func _initialize() -> void: run.call_deferred()
func check(value: bool, label: String) -> void:
	checks+=1
	if not value: failures+=1
	print("PASS: " if value else "FAIL: ",label)
func mouse(pos: Vector2, button: MouseButton, down: bool=true) -> void:
	var motion:=InputEventMouseMotion.new(); motion.position=pos; root.push_input(motion,true); await process_frame
	var e:=InputEventMouseButton.new(); e.position=pos; e.button_index=button; e.pressed=down; root.push_input(e,true); await process_frame
func capture(name: String) -> void:
	await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+name+".png")==OK,"capture "+name)
func run() -> void:
	create_timer(120).timeout.connect(func(): quit(2)); DirAccess.make_dir_recursive_absolute(OUT)
	root.content_scale_size=Vector2i.ZERO
	var scene: Control=load("res://dev/coast_fix_comparison.tscn").instantiate(); root.add_child(scene); current_scene=scene
	await process_frame; await process_frame
	var m: Control=scene.map
	var original: Dictionary=m.WORLD_CITY_MAP_UV.duplicate(true)
	check(m.after.get_size()==Vector2(1254,1254),"native asset resolution")
	check(original.size()==54,"runtime merged54 coordinates")
	var snapshot: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(m.ASSETS+"effective_coordinates.json"))
	for entry: Dictionary in snapshot.points: check(original[entry.id].distance_to(Vector2(entry.u,entry.v))<0.000001,"diagnostic snapshot matches runtime "+entry.id)
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await process_frame; await process_frame; m.frame_tile(); await process_frame
		var prefix: String=str(resolution.x)
		await capture(prefix+"-after")
		var point: Vector2=m.anchor("geumgwan")
		await mouse(scene.toggle.get_global_rect().get_center(),MOUSE_BUTTON_LEFT); await mouse(scene.toggle.get_global_rect().get_center(),MOUSE_BUTTON_LEFT,false)
		check(not m.corrected and m.anchor("geumgwan").is_equal_approx(point),"before toggle retains exact anchor")
		await capture(prefix+"-before")
		await mouse(scene.toggle.get_global_rect().get_center(),MOUSE_BUTTON_LEFT); await mouse(scene.toggle.get_global_rect().get_center(),MOUSE_BUTTON_LEFT,false)
		var zoom: float=m.map_zoom
		var focus: Vector2=m.global_position+m.size*Vector2(0.78,0.5)
		await mouse(focus,MOUSE_BUTTON_WHEEL_UP)
		await mouse(focus,MOUSE_BUTTON_WHEEL_UP,false)
		check(m.map_zoom>zoom and m.tile.texture==m.after,"real wheel up keeps corrected texture")
		await mouse(focus,MOUSE_BUTTON_WHEEL_DOWN)
		await mouse(focus,MOUSE_BUTTON_WHEEL_DOWN,false)
		check(is_equal_approx(m.map_zoom,zoom),"real wheel down")
		var pan: Vector2=m.map_pan_offset
		await mouse(focus,MOUSE_BUTTON_LEFT)
		var motion:=InputEventMouseMotion.new(); motion.position=focus+Vector2(70,30); motion.button_mask=MOUSE_BUTTON_MASK_LEFT; root.push_input(motion,true); await process_frame
		await mouse(motion.position,MOUSE_BUTTON_LEFT,false)
		check(m.map_pan_offset.distance_to(pan)>20,"real mouse drag pans map")
		for n: int in range(scene.cities.item_count):
			var id: String=scene.cities.get_item_metadata(n); m.focus_on_province(id,4); await process_frame
			var center: Vector2=m.city_buttons[id].get_global_rect().get_center()
			await mouse(center,MOUSE_BUTTON_LEFT); await mouse(center,MOUSE_BUTTON_LEFT,false)
			check(m.selected==id and scene.status.text.contains(m.WORLD_CITY_NAMES[id]),"castle selects "+prefix+" "+id)
			var rect: Rect2=m._get_displayed_map_rect()
			check(((m.anchor(id)-rect.position)/rect.size).distance_to(original[id])<0.000001,"shared inverse transform "+id)
			if resolution.x==1920:
				evidence.append({"id":id,"uv":[original[id].x,original[id].y],"mask_id":m.mask_id(id)})
				if id in ["geumgwan","sogaya","ulleung","geumseong","dalgubeol","sabeol"]: await capture(prefix+"-"+id)
		m.frame_tile(); scene.mask.button_pressed=true; await process_frame; await capture(prefix+"-mask")
		m.map_zoom=1; m.map_pan_offset=Vector2.ZERO; m._layout_city_buttons(); await process_frame
		check(m.tile.texture==m.after,"coarse zoom never swaps coastline")
		await capture(prefix+"-overview"); scene.mask.button_pressed=false
		for level: int in range(1,6):
			m._set_map_zoom(level,m.size*0.5)
			var rect: Rect2=m._get_displayed_map_rect()
			check(m.tile.texture==m.after and ((m.tile.position-rect.position)/rect.size).distance_to(Vector2(0.5,0.5))<0.000001 and (m.tile.size/rect.size).distance_to(Vector2(1.0/6,0.25))<0.000001,"fixed logical tile at zoom "+str(level))
		var line: Line2D=m.road_lines[0]; var road: Array=m.WORLD_MAP_ROADS[0]
		check(line.points[0].distance_to(m.anchor(road[0]))<0.001 and line.points[line.points.size()-1].distance_to(m.anchor(road[1]))<0.001,"existing route uses identical city transform")
		if resolution.x==1920:
			m.frame_tile(); m.show_routes=false; scene.castles.button_pressed=false; m._layout_city_buttons(); await capture("1920-land-after")
			m.corrected=false; m._layout_city_buttons(); await capture("1920-land-before")
			m.corrected=true; m._layout_city_buttons()
	check(m.WORLD_CITY_MAP_UV==original,"all runtime city coordinates unchanged")
	var file:=FileAccess.open(OUT+"result.json",FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"anchors":evidence},"\t")); file.close()
	print("COAST REVIEW: ",checks," checks, ",failures," failures"); quit(0 if failures==0 else 1)
