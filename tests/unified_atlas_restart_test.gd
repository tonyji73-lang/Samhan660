extends "res://tests/unified_atlas_test.gd"

func same_camera(expected: Dictionary) -> bool:
	var actual: Dictionary=ui.map.get_view_state()
	var a: Array=actual.center_native;var b: Array=expected.center_native
	return actual.selected==expected.selected and is_equal_approx(float(actual.zoom),float(expected.zoom)) and Vector2(a[0],a[1]).distance_to(Vector2(b[0],b[1]))<0.001

func _run() -> void:
	create_timer(100).timeout.connect(func():quit(2))
	root.content_scale_size=Vector2i.ZERO
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(UNIFIED_OUT+"normal.json"))
	check(OS.get_process_id()!=int(normal.pid),"new OS process")
	for record: Dictionary in normal.records:
		root.size=Vector2i(int(record.resolution),720 if int(record.resolution)==1280 else 1080)
		await load_from_title(str(record.slot))
		check(full_state()==record.state,"new process restores campaign state")
		check(ui.visible and ui.selected=="dalgubeol" and same_camera(record.camera),"new process restores atlas camera and selection")
		check(not ui.map.detail_auto_allowed(),"automatic LOD remains off")
		var before: int=stamp()
		await click(ui.buttons.month);await settle_events();c.merit_overlay.hide();await pause()
		check(stamp()==before+1 and c.Army.units(c.strategy_state)[record.unit].location=="dalgubeol","new process support completes once")
		check(c.pending_transfer_orders.filter(func(o):return o.unit_ids.has(record.unit)).is_empty(),"completed support has no reservation")
		await capture_atlas(str(record.resolution)+"-restart")
		# Compatibility fixture derived from our own save; never touches user slots.
		var legacy: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(record.slot))
		legacy.erase("atlas_view")
		var fixture: String="user://unified_atlas_legacy_%d_%d.json" % [OS.get_process_id(),record.resolution]
		var f:=FileAccess.open(fixture,FileAccess.WRITE);f.store_string(JSON.stringify(legacy));f.close()
		await load_from_title(fixture)
		check(full_state()==record.state and ui.visible and ui.selected=="dalgubeol","save without atlas data opens atlas preserving simulation")
		await click(ui.buttons.menu);c.navigation_menu.get_popup().hide();c.navigation_menu.get_popup().id_pressed.emit(9);await pause()
		check(c.ending_load_dialog.visible,"campaign menu load picker opens over atlas")
		c.ending_load_dialog.hide();c.ending_load_dialog.file_selected.emit(ProjectSettings.globalize_path(str(record.slot)));await pause()
		check(full_state()==record.state and same_camera(record.camera) and ui.visible,"campaign menu load restores atlas")
		var camera: Dictionary=ui.map.get_view_state()
		c._on_transfer_button_pressed();await pause()
		check(c.transfer_panel.visible and c.transfer_panel.get_parent().name=="ProductionLayer" and ui.suspended,"shared transfer panel is above atlas")
		await escape();await pause()
		check(not c.transfer_panel.visible and ui.map.get_view_state()==camera,"shared transfer returns to same camera")
		# Presentation-only fixture, not a naturally occurring enemy declaration.
		var presentation: Node=c.event_presentation
		presentation.play("enemy_invasion_alert",{"target_province_id":"dalgubeol","target_province_name":"달구벌","enemy_faction_name":"백제","enemy_troops":15000},"atlas-fixture-"+str(record.resolution))
		await create_timer(1).timeout
		check(presentation.active and presentation.adapter.map==ui.map and ui.map.input_locked,"GUI event uses and locks atlas")
		await capture_atlas(str(record.resolution)+"-event-fixture")
		presentation.skip();await pause()
		check(ui.map.get_view_state()==camera and not ui.map.input_locked,"event restores camera and input")
		await click(ui.buttons.zoom_in)
		camera=ui.map.get_view_state()
		c.select_province(c.selected_province_id);await pause()
		check(ui.map.get_view_state()==camera,"same-city command refresh preserves changed zoom and pan")
		root.warp_mouse(Vector2(10,10))
		var motion:=InputEventMouseMotion.new();motion.position=Vector2(10,10);root.push_input(motion,true)
		await pause()
	print("UNIFIED ATLAS RESTART: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
