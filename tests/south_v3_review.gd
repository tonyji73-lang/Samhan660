extends "res://tests/full_r3_regions_test.gd"
const V3_OUT="res://tests/art_review/south_v3/review/"
func snap(name: String) -> void:
	await pause();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(V3_OUT+name+".png")
func _run() -> void:
	create_timer(120).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(V3_OUT)
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1920,1080)
	await start(Scenarios.SCENARIOS[1],"silla","historical");await settle_events();ui=c.settlement_overlay
	ui.select_city("daegaya");await click(ui.buttons.city_info)
	var layer=ui.map.south_v3
	check(layer.error.is_empty(),"v3 source and shader loaded")
	var positions: Dictionary={"daegaya":Vector3(654,846,9),"inland":Vector3(723,815,8),"whole":Vector3(710,870,3)}
	for id: String in positions:
		var p: Vector3=positions[id];center_native(Vector2(p.x,p.y),p.z)
		var view: Dictionary=ui.map.get_view_state()
		for mode: String in ["base","raw","edge_sea","inland_proposal"]:
			layer.suppressed=mode=="base";layer.review=mode!="inland_proposal";layer.raw=mode=="raw"
			if mode=="inland_proposal":layer.approved=true
			ui.map.queue_redraw();await snap(id+"-"+mode)
			check(ui.map.get_view_state()==view,"same camera "+id+" "+mode)
			if mode!="base":check(layer.drawn and layer.weight>0 and is_equal_approx(layer.material.get_shader_parameter("lod_weight"),layer.weight) and (not layer.review or layer.weight==1),"actual shader weight forwarded "+mode)
	print("V3 REVIEW ",checks," checks ",failures," failures")
	quit(0 if failures==0 else 1)
