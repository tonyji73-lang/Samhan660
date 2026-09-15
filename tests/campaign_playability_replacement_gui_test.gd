extends "res://tests/project_foundation_test.gd"
const DIR="res://.godot/playability-results/"
func _run() -> void:
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await finish_events()
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"replacement.json"))
	for name: String in ["defeat-replacement-ready","defeat-replacement-battle"]:
		c._on_load_button_pressed(DIR+name+".json"); await settle(); await finish_events(); c.open_army("siljik")
		var selector: OptionButton=c.army_overlay.selector
		for n: int in range(selector.item_count):
			if str(selector.get_item_metadata(n))==str(evidence.ready.id): selector.select(n); selector.item_selected.emit(n); break
		await settle(); await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(DIR+name+".png")==OK,"actual replacement state capture "+name)
		await escape()
	print("PLAYABILITY REPLACEMENT GUI: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
