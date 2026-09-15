extends "res://tests/ai_military_planning_audit.gd"
func _run() -> void:
 create_timer(300).timeout.connect(func(): quit(2))
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 c._on_load_button_pressed(DIR+"silla-initial.json"); events()
 var battle: Dictionary=c.resolve_army_battle("danghangseong","hwanghae","silla")
 print("RECOVERY ACTUAL PLAYER ATTACK ",battle)
 check(battle.ok,"normal initial campaign real player battle")
 events(); await process_frame
 c._on_save_button_pressed(DIR+"normal-ai-defeat.json")
 var rows: Array=[]; var marks: Dictionary={}
 for step: int in range(90):
  if c.Ending.finished(c.strategy_state): break
  c._on_end_turn_button_pressed(); events(); await process_frame
  var row: Dictionary=metrics("goguryeo"); rows.append(row)
  var triggers: Dictionary={"new-ready":row.new_ready>=1000,"new-front":row.plan.get("completed",[]).any(func(x): return x.creation_reason=="recruitment"),"counterattack":row.battles>1}
  for mark: String in triggers:
   if triggers[mark] and not marks.has(mark):
    marks[mark]=step+1; c._on_save_button_pressed(DIR+"recovery-"+mark+".json")
  if step%18==0: print("RECOVERY MONTH ",step+1," recruited ",row.recruits," ready ",row.new_ready," losses ",row.losses," battles ",row.battles)
 c._on_save_button_pressed(DIR+"recovery-final.json")
 var out:=FileAccess.open(DIR+"recovery-months.json",FileAccess.WRITE); out.store_string(JSON.stringify({"initial_battle":battle,"milestones":marks,"rows":rows})); out.close()
 check(marks.has("new-ready"),"normal defeat followed by paid new equipment and training")
 check(marks.has("new-front"),"new replacement reaches actual front")
 print("RECOVERY RESULT ",checks," checks, ",failures," failures; ",marks)
 quit(1 if failures else 0)
