extends "res://tests/mobilization_gui_test.gd"
func _run() -> void:
	for f: String in ["silla","baekje","goguryeo"]:
		nation=f; home_city={"silla":"geumseong","baekje":"sabi","goguryeo":"pyongyang"}[f]
		root.set_meta("new_game_settings",{"faction":f,"play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
		change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await events()
		c._on_load_button_pressed(DIR+f+"-final.json"); await settle(); await events()
		c._on_city_card_production_requested(home_city)
		var p: Node=c.production_overlay; p.recipe_selector.select(2); p.recipe_selector.item_selected.emit(2); await settle()
		check(p.details.text.contains("운영비 금 18") and p.details.text.contains("광산·역사 생산량 아님"),"common recipe explanation and cost visible "+f)
		await screen("common-iron-detail"); await escape()
		c.select_province(home_city); c._on_recruit_button_pressed(); await settle()
		check(c.recruitment_overlay.details.text.contains("다음 수확") and c.recruitment_overlay.details.text.contains("민간 인구"),"next harvest/civilian forecast visible "+f)
		await screen("saved-recruit-forecast"); await escape()
		check(not c.map_area.modal_input_locked,"loaded economy screens restore map input "+f)
	print("MOBILIZATION REVIEW GUI TESTS: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
