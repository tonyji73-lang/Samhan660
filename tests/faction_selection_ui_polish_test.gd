extends "res://tests/settlement_ui_test.gd"
const FACTION_OUT="res://.godot/faction-ui-polish/"
var setup: Control
func choose(key: String) -> void:
	var view: Control=setup.faction_view
	var b: Button=view._focus_controls[key]
	if key.begins_with("faction:"): view._faction_scroll.ensure_control_visible(b)
	if key.begins_with("scenario:"): view._scenario_scroll.ensure_control_visible(b)
	await click(b)
func capture_ui(name: String) -> void:
	await pause();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(FACTION_OUT+name+".png")
func enter_setup() -> void:
	change_scene_to_file(ProjectSettings.get_setting("application/run/main_scene"))
	await create_timer(2).timeout
	await click(current_scene.new_game_button);await create_timer(2).timeout
	setup=current_scene
func _run() -> void:
	create_timer(300).timeout.connect(func():quit(2))
	DirAccess.make_dir_recursive_absolute(FACTION_OUT)
	root.content_scale_size=Vector2i.ZERO
	await enter_setup()
	for res: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=res;await pause()
		check(setup.faction_view._model.leader==setup._get_selected_faction_data().ruler,"632 ruler bound")
		check(setup.faction_view._model.scenario_title=="선덕여왕 즉위","title excludes duplicate year")
		check(not "게임상" in setup.faction_view._model.key_people,"people names concise")
		check("게임상" in setup.faction_view._model.key_people_detail,"ages available in tooltip")
		var fs: Control=setup.faction_view._faction_scroll
		var buttons: Array=fs.get_child(0).get_children()
		for i: int in range(mini(6,buttons.size())):
			check(fs.get_global_rect().encloses(buttons[i].get_global_rect()),"first two faction rows fully visible")
		for label: Node in setup.faction_view._details.get_child(0).get_children():
			if label.text==setup.faction_view._model.description:
				check(label.get_global_rect().end.y<=setup.faction_view._details.get_global_rect().end.y,"632 introduction fully visible initially")
		await capture_ui(str(res.x)+"-632-silla")
		for id: String in ["baekje","goguryeo","silla"]:
			await choose("faction:"+id)
			check(setup.faction_view._focus_controls.start.text==setup._get_selected_faction_data().name+"로 시작","start label follows faction")
		var view: Control=setup.faction_view
		check(view._focus_controls.start.get_global_rect().end.y<=res.y,"start fits "+str(res))
		var pt: Vector2=view._details.get_global_rect().get_center()
		for i in range(8):
			await mouse(pt,MOUSE_BUTTON_WHEEL_DOWN,true);await mouse(pt,MOUSE_BUTTON_WHEEL_DOWN,false)
		check(view._details.scroll_vertical>0,"actual detail scrolling")
		await choose("difficulty:hard");await choose("difficulty:normal")
		check(setup.selected_difficulty_id=="normal","difficulty GUI")
		await escape();await create_timer(2).timeout
		check(current_scene.scene_file_path=="res://title_screen.tscn","Esc returns title")
		await click(current_scene.new_game_button);await create_timer(2).timeout;setup=current_scene
	for scenario: Dictionary in Scenarios.SCENARIOS:
		await choose("scenario:"+str(scenario.id))
		check(not setup.faction_view._model.scenario_title.begins_with(str(scenario.year)),"all scenario titles omit year")
		var data: Dictionary=setup._get_selected_scenario()
		for faction: Dictionary in data.factions:
			var id: String=str(faction.id)
			var playable: bool=Scenarios.is_faction_playable_by_default(str(scenario.id),id)
			check(setup.faction_view._focus_controls["faction:"+id].disabled==not playable,"availability "+str(scenario.id)+"/"+id)
			if playable:
				await choose("faction:"+id)
				check(setup.faction_view._model.leader==faction.ruler and setup.faction_view._model.capital==faction.capital,"live ruler/capital "+id)
				check(setup.selected_faction_id==id,"controller selection "+id)
	await choose("scenario:"+str(Scenarios.SCENARIOS[0].id));await choose("faction:silla")
	await choose("start");setup._on_start_pressed();await create_timer(3).timeout
	c=current_scene;c.event_presentation.display_level="minimal";await settle_events()
	check(c.year==632 and c.player_faction_id=="silla","632 campaign starts through existing path")
	await click(c.settlement_button);await pause()
	check(not c.settlement_overlay.map.detail_auto_allowed(),"map automatic LOD remains off")
	await capture_ui("632-campaign-map")
	await enter_setup()
	await choose("scenario:"+str(Scenarios.SCENARIOS[1].id));await choose("faction:baekje")
	await choose("modes:fictional");await choose("difficulty:hard")
	await choose("start");await create_timer(3).timeout
	c=current_scene;c.event_presentation.display_level="minimal";await settle_events()
	check(c.year==642 and c.player_faction_id=="baekje","642 Baekje campaign")
	check(c.play_style=="fictional" and c.difficulty=="hard","selected mode/difficulty reach campaign")
	print("FACTION POLISH: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
