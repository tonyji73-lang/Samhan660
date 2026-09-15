extends "res://tests/ai_military_planning_audit.gd"
func full() -> Variant:
 return canonical({"state":c.strategy_state,"provinces":c.provinces,"orders":c.pending_transfer_orders,"year":c.year,"month":c.month})
func invariant(label: String) -> void:
 for faction: String in c.strategy_state.faction_economy.accounts:
  var a: Dictionary=c.strategy_state.faction_economy.accounts[faction]
  check(int(a.opening)+int(a.income)-int(a.expense)==int(a.balance),label+" treasury identity "+faction)
 for u: Dictionary in Army.units(c.strategy_state).values():
  var origins: int=0
  for count in u.origins.values(): origins+=int(count)
  if origins!=int(u.troops) or int(u.equipment)<0 or int(u.troops)<0: check(false,label+" unit origin/resource conservation "+u.id)
func _run() -> void:
 create_timer(240).timeout.connect(func(): quit(2))
 DirAccess.make_dir_recursive_absolute(DIR)
 var combos: Array=[]
 for scenario: Dictionary in Scenarios.SCENARIOS:
  for faction: Dictionary in Scenarios.get_scenario(scenario.id).factions:
   if not Scenarios.is_faction_playable_by_default(scenario.id,faction.id): continue
   await start(scenario,faction.id,"historical"); events()
   c._on_end_turn_button_pressed(); events(); await process_frame
   check(not c.Ending.finished(c.strategy_state),"initial real month "+scenario.id+"/"+faction.id)
   var before: Variant=full()
   for ai: String in c.strategy_state.get("military_planning",{}).get("factions",{}): P.run(c,ai)
   check(full()==before,"same month national planning is inert "+scenario.id+"/"+faction.id)
   invariant(scenario.id+"/"+faction.id)
   combos.append({"scenario":scenario.id,"player":faction.id,"plans":c.strategy_state.get("military_planning",{}).duplicate(true)})
 var out:=FileAccess.open(DIR+"initial-combinations.json",FileAccess.WRITE); out.store_string(JSON.stringify(combos)); out.close()
 check(combos.size()==12,"actual 12 selectable combinations")
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 check(not c.strategy_state.has("military_planning"),"new campaign has no previous plan")
 c._on_save_button_pressed(DIR+"legacy-no-plan.json")
 c._on_load_button_pressed(DIR+"legacy-no-plan.json"); events()
 check(not c.strategy_state.has("military_planning"),"legacy load does not execute planner")
 c._on_end_turn_button_pressed(); events(); await process_frame
 c._on_save_button_pressed(DIR+"pending-plan.json")
 var saved: Variant=full()
 for i: int in range(3):
  c._on_load_button_pressed(DIR+"pending-plan.json"); events(); await process_frame
  check(full()==saved,"repeated full plan restore no commands/costs "+str(i))
 var before: Variant=full(); P.run(c,"baekje"); P.run(c,"goguryeo")
 check(full()==before,"loaded processed month remains inert")
 # Boundary fixtures, clearly separate from normal campaign runs.
 for resource: String in ["gold","food","population","staff"]:
  await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
  var s: Dictionary=c.strategy_state
  if resource=="gold": s.faction_economy.accounts.baekje.balance=0
  for city: String in P.owned(c,"baekje"):
   if resource=="food": c.provinces[city].food_stock=0
   if resource=="population": c.provinces[city].population=0
   if resource=="staff":
    for id: String in c.get_city_officer_ids(city): c.officer_registry.people[id].active=false
  var troops: int=0
  for u: Dictionary in Army.units(s).values():
   if u.faction_id=="baekje": troops+=int(u.troops)
  P.run(c,"baekje")
  var after_troops: int=0
  for u: Dictionary in Army.units(s).values():
   if u.faction_id=="baekje": after_troops+=int(u.troops)
  if resource!="staff": check(after_troops==troops,"boundary "+resource+" blocks paid recruitment")
  else: check(not s.military_planning.factions.baekje.actions.any(func(a): return a.action=="planned_recruit"),"no trainer blocks general recruitment")
  check(int(s.faction_economy.accounts.baekje.balance)>=0,"shared treasury cannot overdraw "+resource)
  var state: Variant=full(); P.run(c,"baekje"); check(full()==state,"failed constraints same month inert "+resource)
 # Terminal boundary: planner must not even create metadata after victory.
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 c.strategy_state.campaign_ending.status="victory"
 before=full(); P.run(c,"baekje"); c.IronAI.run(c,"baekje",0); c.run_enemy_ai_turns()
 check(full()==before,"terminal blocks planner, old iron AI and monthly AI")
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 check(not c.Ending.finished(c.strategy_state) and not c.strategy_state.has("military_planning"),"new game clears ending and plans")
 print("AI MILITARY RISK RESULT ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
