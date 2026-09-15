extends "res://tests/ai_military_planning_test.gd"
func _run() -> void:
 DIR="res://.godot/completion-preparation-risk/"; DirAccess.make_dir_recursive_absolute(DIR)
 for player: String in ["silla","baekje"]:
  await start(Scenarios.SCENARIOS[0],player,"historical"); events()
  c._on_load_button_pressed("res://.godot/completion-training-results/"+player+"-after24.json"); events()
  for n: int in range(6):
   c._on_end_turn_button_pressed(); events(); await process_frame
   var workers: Array=[]; var trainees: Array=[]; var reserved: Array=[]
   for job: Dictionary in Army.Domestic.ensure(c.strategy_state).jobs.values():
    if job.kind!="training" or job.status!="pending": continue
    check(not workers.has(job.officer_id),"trainer uniquely assigned "+job.officer_id); workers.append(job.officer_id)
    check(not trainees.has(job.unit_id),"unit has one training job "+job.unit_id); trainees.append(job.unit_id)
   for faction: String in c.strategy_state.military_planning.factions:
    var plan: Dictionary=c.strategy_state.military_planning.factions[faction]
    for uid: String in P.Preparation.ids(plan):
     if uid.is_empty(): continue
     check(not reserved.has(uid),"preparation unit reserved only once "+uid); reserved.append(uid)
     var u: Dictionary=Army.units(c.strategy_state).get(uid,{})
     if not u.is_empty() and u.status=="transit": check(not trainees.has(uid),"training and transit mutually exclusive "+uid)
   invariant("preparation month")
   var state: Variant=full()
   for faction: String in c.strategy_state.military_planning.factions: P.run(c,faction)
   check(full()==state,"preparation duplicate month inert")
  c._on_save_button_pressed(DIR+player+".json"); var saved: Variant=full()
  c._on_load_button_pressed(DIR+player+".json"); events(); await process_frame
  check(full()==saved,"parallel preparation and jobs restore without effects")
 print("PREPARATION RISKS ",checks," checks, ",failures," failures"); quit(1 if failures else 0)
