extends "res://tests/player_playtest_ui.gd"
func _run() -> void:
 create_timer(240).timeout.connect(func(): quit(2))
 var file: String="user://campaign_save_35_regions_v1.json"
 var original: String=FileAccess.get_file_as_string(file)
 var saved: Dictionary=JSON.parse_string(original)
 await boot(); await click(c.load_game_button); await pick_file(c.load_picker,"campaign_save_35_regions_v1.json"); await events()
 check(c.year==633 and c.month==1,"launcher restart restores12month user progress")
 check(c.gold==saved.gold,"restart preserves treasury")
 var signature: String=JSON.stringify(c.strategy_state)
 for n: int in range(2):
  await click(c.load_button); await events()
  check(JSON.stringify(c.strategy_state)==signature,"repeat UI load preserves complete strategy state")
 check(FileAccess.get_file_as_string(file)==original,"launcher and loads never overwrite progress")
 await screen("restart-restored")
 await click(c.end_turn_button); await events()
 check(c.year==633 and c.month==2,"restored campaign accepts next month UI")
 await menu("저장 파일 선택")
 await pick_file(c.ending_load_dialog,ProjectSettings.globalize_path("res://.godot/normal-completion-final/final.json")); await events()
 check(c.Ending.finished(c.strategy_state) and c.ending_dialog.visible,"normal ending loads via file picker")
 await screen("ending-load")
 var next: Button=null
 for node: Node in c.ending_dialog.find_children("*","Button",true,false):
  if node.text=="새 캠페인": next=node
 check(next!=null,"ending offers actual new campaign button")
 await click(next); await create_timer(1).timeout; c=current_scene; await click(c.start_button); await create_timer(2).timeout; c=current_scene; await events()
 check(c.year==632 and c.month==1 and not c.map_area.modal_input_locked,"new campaign clears old ending and input lock")
 await click(c.end_turn_button); await events(); check(c.month==2,"new game UI monthly command restored")
 await screen("restart-new-game")
 check(FileAccess.get_file_as_string(file)==original,"unsaved new game leaves existing progress intact")
 var report:=FileAccess.open(OUT+"restore-result.json",FileAccess.WRITE)
 report.store_string(JSON.stringify({"failures":failures,"user_dir":ProjectSettings.globalize_path("user://"),"preserved_progress":FileAccess.get_file_as_string(file)==original})); report.close()
 print("PLAYER RESTORE RESULT failures ",failures); quit(1 if failures else 0)
