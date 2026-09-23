extends "res://tests/faction_selection_ui_v1_test.gd"

const UNIFIED_OUT="res://.godot/unified-atlas/"
var atlas_records: Array=[]

func mouse(point: Vector2, code: MouseButton, down: bool) -> void:
	# Keep the OS pointer aligned with injected GUI events (native tooltips use it).
	root.warp_mouse(point)
	var motion := InputEventMouseMotion.new(); motion.position=point;root.push_input(motion,true)
	var event := InputEventMouseButton.new();event.position=point;event.button_index=code;event.pressed=down
	root.push_input(event,true);await process_frame

func capture_atlas(name: String) -> void:
	root.warp_mouse(Vector2(10,10))
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(10,10);root.push_input(motion,true)
	await pause();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(UNIFIED_OUT+name+".png")

func load_from_title(path: String) -> void:
	# Drain native tooltip/window updates before replacing the scene.
	root.warp_mouse(Vector2(10,10))
	var motion:=InputEventMouseMotion.new();motion.position=Vector2(10,10);root.push_input(motion,true)
	await pause()
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"));await create_timer(2).timeout
	await click(current_scene.load_game_button)
	check(current_scene.load_picker.visible,"title load picker opens")
	current_scene.load_picker.hide()
	current_scene.load_picker.file_selected.emit(ProjectSettings.globalize_path(path))
	await create_timer(3).timeout
	c=current_scene;ui=c.settlement_overlay
	await settle_events();await pause()

func _run() -> void:
	create_timer(240).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(UNIFIED_OUT)
	root.content_scale_size=Vector2i.ZERO
	for res: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=res
		await enter_setup();await choose("scenario:"+str(Scenarios.SCENARIOS[1].id));await choose("faction:silla");await choose("start")
		await create_timer(3).timeout;c=current_scene;await settle_events();ui=c.settlement_overlay;await pause()
		check(ui.visible and ui.active and not c.get_node("MainVBox").visible,"new campaign directly opens only atlas")
		check(not ui.buttons.has("close") and not ui.buttons.has("view_options") and not ui.buttons.has("detail_r3"),"no legacy screen or review UI")
		check(c.event_presentation.adapter.map==ui.map,"event camera uses actual atlas")
		await capture_atlas(str(res.x)+"-new")
		var before: Dictionary=full_state()
		await click(ui.buttons.overview)
		check(ui.visible and is_equal_approx(ui.map.map_zoom,1.0),"whole map fits same atlas")
		await capture_atlas(str(res.x)+"-whole")
		for city: String in ["dalgubeol","geumseong","siljik","ulleung"]:
			ui.map.focus_on_province(city,4.2);await pause()
			var point: Vector2=ui.map.get_global_transform_with_canvas()*ui.map.anchor(city)
			await mouse(point,MOUSE_BUTTON_LEFT,true);await mouse(point,MOUSE_BUTTON_LEFT,false);await pause()
			check(ui.selected==city and c.selected_province_id==city,"actual map selection "+city)
		ui.select_city("geumseong");ui.map.focus_on_province("geumseong",4.2)
		var focal: Vector2=ui.map.size*Vector2(0.65,0.5)
		var screen_point: Vector2=ui.map.get_global_transform_with_canvas()*focal
		await mouse(screen_point,MOUSE_BUTTON_WHEEL_UP,true);await mouse(screen_point,MOUSE_BUTTON_WHEEL_UP,false)
		check(ui.map.map_zoom>4.2,"wheel zoom works")
		await mouse(screen_point,MOUSE_BUTTON_LEFT,true)
		var motion:=InputEventMouseMotion.new();motion.position=screen_point+Vector2(30,20);motion.button_mask=MOUSE_BUTTON_MASK_LEFT;root.push_input(motion,true)
		await mouse(motion.position,MOUSE_BUTTON_LEFT,false)
		var camera: Dictionary=ui.map.get_view_state()
		for kind: String in ["domestic","army","production","politics","research"]:
			await click(ui.buttons[kind]);await pause()
			check(ui.visible and ui.suspended and ui._modal_shield.visible,"atlas remains locked backdrop for "+kind)
			await escape();await pause()
			check(ui.visible and not ui.suspended and ui.map.get_view_state()==camera and ui.selected=="geumseong","command returns to same atlas "+kind)
		await escape();await pause()
		check(c.navigation_menu.get_popup().visible and ui.visible,"Esc opens menu over atlas")
		await escape();await pause()
		check(not ui.suspended and ui.map.get_view_state()==camera,"menu returns camera unchanged")
		check(full_state()==before,"map and menu browsing do not change simulation")
		# Old controller entry points must select the visible atlas too.
		c.select_province("siljik");await pause();check(ui.selected=="siljik","external city navigation reaches atlas")
		ui.select_city("dalgubeol");ui.map.focus_region();select_value(ui.sources,"geumseong")
		await click(ui.support);await pause()
		check(c.army_overlay.visible and ui.visible,"support army window above atlas")
		var moved: String=c.army_overlay.id()
		await capture_atlas(str(res.x)+"-support-command")
		print("MOVE RECT ",c.army_overlay.move_button.get_global_rect()," viewport ",root.size)
		await click(c.army_overlay.move_button);print("MOVE RESULT ",c.army_overlay.result.text);await escape();await pause()
		check(not c.pending_transfer_orders.is_empty(),"normal support queued")
		var slot: String="user://unified_atlas_%d_%d_%d.json" % [Time.get_unix_time_from_system(),OS.get_process_id(),res.x]
		await click(ui.buttons.menu)
		c.navigation_menu.get_popup().hide();c.navigation_menu.get_popup().id_pressed.emit(15);await pause()
		check(ui.save_picker.visible,"atlas menu exposes native save picker")
		ui.save_picker.hide();ui.save_picker.file_selected.emit(ProjectSettings.globalize_path(slot));await pause()
		check(FileAccess.file_exists(slot),"separate save written")
		var saved: Dictionary=full_state();camera=ui.map.get_view_state()
		atlas_records.append({"slot":slot,"state":saved,"camera":camera,"unit":moved,"resolution":res.x})
		await load_from_title(slot)
		check(ui.visible and full_state()==saved and ui.map.get_view_state()==camera,"title load directly restores atlas and state")
		await capture_atlas(str(res.x)+"-loaded")
		var prior: int=stamp()
		await click(ui.buttons.month);await settle_events();c.merit_overlay.hide();await pause()
		check(stamp()==prior+1 and c.Army.units(c.strategy_state)[moved].location=="dalgubeol","restored support arrives normally")
		await capture_atlas(str(res.x)+"-arrival")
	var file:=FileAccess.open(UNIFIED_OUT+"normal.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"pid":OS.get_process_id(),"records":atlas_records,"checks":checks,"failures":failures},"\t"));file.close()
	print("UNIFIED ATLAS: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
