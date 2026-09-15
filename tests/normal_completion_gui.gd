extends "res://tests/military_supply_expansion_gui_test.gd"
func _run() -> void:
 create_timer(120).timeout.connect(func(): quit(2))
 DIR="res://.godot/normal-completion-final/"
 root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
 change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; events()
 c._on_load_button_pressed("res://.godot/completion-training-results/baekje-after24.json"); await settle(); events()
 c.open_ai_military_brief(); await settle(); await screen("parallel-training-and-front"); c.military_brief_details.get_v_scroll_bar().value=c.military_brief_details.get_v_scroll_bar().max_value
 await settle(); await screen("parallel-training-detail"); await click(c.playability_dialog.get_ok_button())
 c._on_load_button_pressed(DIR+"before-battle-106.json"); await settle(); events()
 check(not c.Ending.finished(c.strategy_state),"normal final battle save is ongoing")
 c.open_army("bireyeolhol"); await settle(); await screen("normal-final-front")
 await click(c.army_overlay.attack_button)
 check(c.attack_source_id=="bireyeolhol","actual attack button selects normal source")
 c.select_province("gungnae",true); await settle(); await screen("normal-final-attack-target")
 await click(c.map_area.floating_city_card.sortie_button); await settle(); events(); await settle()
 check(c.strategy_state.campaign_ending.status=="victory" and c.ending_dialog.visible,"normal saved final battle reaches actual victory GUI")
 if not c.Ending.finished(c.strategy_state): quit(1); return
 check(c.strategy_state.campaign_ending.result.evaluation.achieved.size()==35,"unchanged35 direct-ownership targets achieved")
 await screen("normal-victory")
 await click(button_named(c.ending_dialog,"결과 저장·재시도")); await settle()
 check(c.ending_save_message.contains("완료"),"isolated profile result saved through real button")
 await screen("normal-victory-saved")
 var ending_path: String="user://normal_completion_v1_ending_"+str(Time.get_ticks_usec())+".json"
 check(c.save_ending_result(ending_path),"dedicated isolated restart ending slot")
 c._on_load_button_pressed(DIR+"month-037.json"); await settle(); events()
 var progress_path: String="user://normal_completion_v1_progress_"+str(Time.get_ticks_usec())+".json"
 check(c._on_save_button_pressed(progress_path),"isolated restart ongoing slot")
 var file:=FileAccess.open(DIR+"restart-paths.json",FileAccess.WRITE); file.store_string(JSON.stringify({"ending":ending_path,"ongoing":progress_path,"user_dir":ProjectSettings.globalize_path("user://")})); file.close()
 c._on_load_button_pressed(ending_path); await settle()
 await click(button_named(c.ending_dialog,"새 캠페인")); await settle()
 check(current_scene!=c and current_scene.has_method("_on_start_pressed"),"victory new campaign enters actual selection")
 var setup: Node=current_scene; await click(setup.start_button); await create_timer(1.5).timeout; await settle(); c=current_scene; events(); await settle()
 check(not c.Ending.finished(c.strategy_state) and not c.strategy_state.has("military_planning") and not c.map_area.modal_input_locked,"new campaign clears all old plans and ending lock")
 var stamp: int=c.year*12+c.month; await click(c.end_turn_button); events(); await settle()
 check(c.year*12+c.month==stamp+1,"next campaign month button works")
 await screen("normal-next-campaign")
 print("NORMAL COMPLETION GUI: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)