extends "res://tests/project_foundation_test.gd"
const DIR="res://.godot/playability-results/"
func _run() -> void:
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await finish_events()
	var losses: Array=[]
	for pair: Array in [["bukhansan","goksan"],["bukhansan","hwanghae"],["danghangseong","hwanghae"]]:
		c.resolve_attack(pair[0],pair[1]); await settle(); await finish_events()
		losses.append(c.strategy_state.army.battles.back().attacker_losses)
	check(losses==[3960,2178,3317],"same normal combat conditions retain pre-change losses exactly")
	check(c.log_label.text.contains("점령지 군량"),"actual conquest handler preserves local stock and garrison guidance")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR+"conquest-supply-notice.png")
	c._on_save_button_pressed(DIR+"after-notice-battle.json")
	c._on_load_button_pressed(DIR+"victory-recovery.json"); await settle(); c.select_province("hwanghae")
	c.open_campaign_brief(); await settle(); await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR+"isolated-conquest-brief.png")
	await escape(); check(not c.map_area.modal_input_locked,"new notice and briefing restore map input")
	print("PLAYABILITY AFTER: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
