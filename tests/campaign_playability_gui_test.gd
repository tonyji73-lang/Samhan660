extends "res://tests/project_foundation_test.gd"
const DIR="res://.godot/playability-results/"
func screen(label: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(DIR+label+".png")==OK,"capture "+label)
func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await finish_events()
	var before: Dictionary=state()
	c.navigation_menu.get_popup().id_pressed.emit(6); await settle()
	check(c.playability_dialog.visible and c.map_area.modal_input_locked,"actual menu briefing locks map")
	var month_before: int=c.year*12+c.month; c._on_end_turn_button_pressed(); check(c.year*12+c.month==month_before,"briefing prevents hidden month advance")
	await screen("campaign-objectives")
	check(state()==before,"briefing is read-only")
	await escape(); check(not c.playability_dialog.visible and not c.map_area.modal_input_locked,"briefing Esc restores input")
	for mode: String in ["A","B","C"]:
		c._on_load_button_pressed(DIR+"politics-"+mode+"-12months.json"); await settle(); await finish_events()
		c.open_politics(); await screen("politics-"+mode+"-12months"); await escape()
		c._on_city_card_production_requested("geumseong"); await screen("production-"+mode+"-12months"); await escape()
	for case_name: String in ["defeat-recovery","victory-recovery"]:
		c._on_load_button_pressed(DIR+case_name+".json"); await settle(); await finish_events()
		var battle: Dictionary=c.strategy_state.army.battles.back()
		c.open_army(battle.source); await screen(case_name); await escape()
	print("PLAYABILITY GUI: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
