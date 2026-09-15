extends "res://tests/ai_military_planning_test.gd"
func _run() -> void:
 DIR="res://.godot/normal-completion-final/"
 var paths: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"restart-paths.json"))
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 c._on_load_button_pressed(paths.ongoing); events(); await process_frame
 check(not c.Ending.finished(c.strategy_state),"fresh process restores normal progress")
 var saved: Variant=full()
 for n: int in range(3):
  c._on_load_button_pressed(paths.ongoing); events(); await process_frame
  check(full()==saved,"repeat progress restore preserves every ledger "+str(n))
 var stamp: int=c.year*12+c.month
 c._on_end_turn_button_pressed(); events(); await process_frame
 check(c.year*12+c.month==stamp+1,"restored progress accepts real monthly command")
 invariant("restored month")
 c._on_load_button_pressed(paths.ending); events(); await process_frame
 check(c.Ending.finished(c.strategy_state),"fresh process restores victory")
 saved=full()
 for n: int in range(3):
  c._on_load_button_pressed(paths.ending); events(); await process_frame
  check(full()==saved,"repeat ending restore no ledger changes "+str(n))
 c._on_end_turn_button_pressed(); c.run_enemy_ai_turns(); P.run(c,"silla"); P.run(c,"baekje")
 check(full()==saved,"ended restart blocks all monthly and planning effects")
 var file:=FileAccess.open(DIR+"restart-result.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"profile":"isolated","user_dir":ProjectSettings.globalize_path("user://"),"paths":paths})); file.close()
 print("NORMAL RESTART ",checks," checks, ",failures," failures"); quit(1 if failures else 0)
