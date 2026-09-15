extends "res://tests/military_supply_expansion_gui_test.gd"
func _run() -> void:
 DIR="res://.godot/supply-expansion-results/"
 root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
 change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; events()
 c._on_load_button_pressed(DIR+"silla-60months.json"); await settle(); events()
 c.open_ai_military_brief(); await settle()
 check(c.playability_dialog.size.y<=900,"network report bounded height")
 check(c.military_brief_details.get_v_scroll_bar().max_value>c.military_brief_details.get_v_scroll_bar().page,"long report actually scrolls")
 await screen("ai-network-report")
 c.military_brief_details.scroll_to_line(25); await settle(); await screen("ai-network-report-lower")
 await click(c.playability_dialog.get_ok_button()); await settle()
 check(not c.map_area.modal_input_locked,"report closes and unlocks")
 c.open_campaign_brief(); await settle()
 check(not c.military_brief_details.visible and c.playability_dialog.get_label().visible,"objectives screen restored after military report")
 await click(c.playability_dialog.get_ok_button()); await settle()
 print("NETWORK GUI REVIEW: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)