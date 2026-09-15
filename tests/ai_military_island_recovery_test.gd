extends "res://tests/ai_military_planning_audit.gd"
func _run() -> void:
 create_timer(180).timeout.connect(func(): quit(2))
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 c._on_load_button_pressed(DIR+"island-blocked-before.json"); events()
 var plan: Dictionary=c.strategy_state.military_planning.factions.goguryeo
 var id: String=plan.cohort; var unit: Dictionary=Army.units(c.strategy_state)[id]
 check(c.Supply.route(c.strategy_state,c.provinces,"goguryeo",plan.hub,unit.location).is_empty(),"reused normal save: land cargo cannot reach island")
 check(not P.military_route(c,"goguryeo",unit.location,plan.hub).is_empty(),"existing troop route offers real recovery")
 for i: int in range(10):
  c._on_end_turn_button_pressed(); events(); await process_frame
  if i==0: check(c.strategy_state.military_planning.factions.goguryeo.actions.any(func(a): return a.action=="return_to_training" and a.result.ok),"same normal state issues real return move")
 var restored: Dictionary=Army.units(c.strategy_state)[id]
 check(Army.ratio(restored)>=1 and Army.training(restored)>=70,"stranded unit actually equipped and trained after return")
 c._on_save_button_pressed(DIR+"island-recovered-after.json")
 print("ISLAND RECOVERY ",checks," checks, ",failures," failures; ",restored)
 quit(1 if failures else 0)
