extends "res://tests/campaign_ending_gui_test.gd"
func show_plan() -> void:
 var menu: PopupMenu=c.navigation_menu.get_popup()
 await click(c.navigation_menu)
 await settle(); menu.grab_focus(); menu.set_focused_item(menu.get_item_index(7)); await settle()
 for down: bool in [true,false]:
  var key:=InputEventKey.new(); key.keycode=KEY_ENTER; key.pressed=down; Input.parse_input_event(key)
 await settle()
 check(c.playability_dialog.visible,"actual navigation item opens military planning")
func _run() -> void:
 create_timer(200).timeout.connect(func(): quit(2))
 DIR="res://.godot/ai-planning-results/"
 root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
 change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await finish_events()
 for item: Array in [["silla-baekje-production.json","normal-first-production"],["silla-baekje-new-ready.json","normal-new-ready"],["silla-baekje-front.json","normal-front-arrival"],["recovery-new-front.json","normal-defeat-replacement"]]:
  c._on_load_button_pressed(DIR+item[0]); await settle(); await finish_events()
  await show_plan(); await screen(item[1])
  check(c.map_area.modal_input_locked,"plan modal locks map")
  await click(c.playability_dialog.get_ok_button()); await settle()
  check(not c.map_area.modal_input_locked,"plan close restores map")
 var month: int=c.year*12+c.month
 await click(c.end_turn_button); await finish_events(); await settle()
 check(c.year*12+c.month==month+1,"real GUI advances AI month after restored plan")
 await show_plan(); await screen("normal-next-month")
 await click(c.playability_dialog.get_ok_button()); await settle()
 c._on_save_button_pressed(DIR+"gui-restored-next-month.json")
 print("AI PLANNING GUI ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
