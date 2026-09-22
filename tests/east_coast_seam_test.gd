extends "res://tests/settlement_ui_test.gd"
const SEAM_OUT="res://.godot/east-coast-seam/"
var pairs: Array=[]

func capture_seam(name: String) -> Image:
	var cursor:=InputEventMouseMotion.new(); cursor.position=Vector2(10,10); root.push_input(cursor,true)
	await pause(); await RenderingServer.frame_post_draw
	var picture: Image=root.get_texture().get_image()
	picture.save_png(SEAM_OUT+name+".png")
	return picture

func _run() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(SEAM_OUT)
	root.content_scale_size=Vector2i.ZERO
	await start(Scenarios.SCENARIOS[1],"silla","historical"); await settle_events(); await pause()
	ui=c.settlement_overlay
	await click(c.settlement_button); await click(ui.buttons.korea_preview); await click(ui.buttons.east_detail)
	var m: Control=ui.map
	var before_state: Dictionary=full_state()
	var join: ShaderMaterial=m.east_detail.material
	check(join!=null and join.shader.resource_path=="res://assets/map_render/east_coast_join_v1.gdshader","dedicated detail shader loaded")
	check(not m.east_detail.use_parent_material and m.east_detail.mouse_filter==Control.MOUSE_FILTER_IGNORE,"dedicated material and click passthrough")
	check(m.terrain.visible and m.terrain.z_index<m.east_detail.z_index and Rect2(m.terrain.position,m.terrain.size).encloses(Rect2(m.east_detail.position,m.east_detail.size)),"overview drawn underneath whole detail")
	check(m.material==null and ui.material==null and m.terrain.material==null and m.selection_layer.material==null and m.roads_layer.material==null,"material isolated from map markers routes UI")
	check(m.east_detail.stretch_mode==TextureRect.STRETCH_SCALE and not m.east_detail.flip_h and not m.east_detail.flip_v,"full unflipped texture UV 0 to 1")
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await pause()
		for zoom: float in [0.0,5.0]:
			if zoom==0: await click(ui.buttons.overview)
			for id: String in ["siljik","geumseong","ulleung"]:
				if zoom>0: m.focus_on_province(id,zoom)
				await click(m.city_buttons[id])
				check(ui.selected==id,"castle selection "+id)
				await click(ui.buttons.preview)
				check(ui.route_open and m.preview_source==ui.source_id() and not m.preview_source.is_empty() and not ui.support.disabled,"support route stays usable "+id)
				var b: Button=m.city_buttons[id]
				var art: TextureRect=b.get_child(0)
				check(b.material==null and art.material==null and m.city_labels[id].material==null,"castle and label not shaded")
				var world: Rect2=m._get_displayed_map_rect()
				check(absf(art.size.x/world.size.x*6144-130)<0.001 and b.size.x>=32 and art.visible==(art.size.x>=40),"proportional castle far marker and click minimum")
				check(ui.bottom.get_global_rect().end.y<=resolution.y,"bottom UI fits")
				check(ui.terrain_note.get_global_rect().end.y<=resolution.y,"footer fits with support route %.1f/%d" % [ui.terrain_note.get_global_rect().end.y,resolution.y])
				var camera: Vector3=Vector3(m.map_zoom,m.map_pan_offset.x,m.map_pan_offset.y)
				var name: String="%d-zoom%d-%s" % [resolution.x,zoom,id]
				m.east_detail.material=null
				var before: Image=await capture_seam(name+"-before")
				m.east_detail.material=join
				var after: Image=await capture_seam(name+"-after")
				check(camera==Vector3(m.map_zoom,m.map_pan_offset.x,m.map_pan_offset.y),"identical camera for before and after")
				var point: Vector2i=Vector2i(m.global_position+m.anchor(id))
				if zoom>0:
					check(before.get_region(Rect2i(point-Vector2i(4,4),Vector2i(8,8))).get_data()==after.get_region(Rect2i(point-Vector2i(4,4),Vector2i(8,8))).get_data(),"protected center pixels preserved")
					var bounds: Dictionary={"siljik":Rect2(0.07685546875,0.0952734375,0.248828125,0.2234375),"geumseong":Rect2(0.01685546875,0.7352734375,0.248828125,0.2234375),"ulleung":Rect2(0.31685546875,0.2552734375,0.248828125,0.2234375)}
					var protection: Rect2=bounds[id]
					var protected_screen:=Rect2(m.east_detail.global_position+protection.position*m.east_detail.size,protection.size*m.east_detail.size).grow(-2)
					var region:=Rect2i(protected_screen.intersection(m.get_global_rect()))
					check(before.get_region(region).get_data()==after.get_region(region).get_data(),"entire visible protection rectangle unchanged")
				pairs.append({"name":name,"zoom":camera.x,"pan":[camera.y,camera.z],"before":name+"-before.png","after":name+"-after.png"})
				await click(ui.buttons.east_detail)
				check(not m.east_detail.visible and m.terrain.visible,"detail off retains overview")
				await click(ui.buttons.east_detail)
				check(m.east_detail.visible and m.east_detail.material==join,"detail on retains shader")
	check(full_state()==before_state,"campaign data preserved")
	var f:=FileAccess.open(SEAM_OUT+"result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"pairs":pairs},"\t")); f.close()
	print("EAST SEAM: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
