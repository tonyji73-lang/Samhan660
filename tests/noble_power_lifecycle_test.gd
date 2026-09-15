extends "res://tests/noble_power_constraints_test.gd"
const SaveFixtures=preload("res://tests/test_save_fixtures.gd")
func _run() -> void:
 DIR=SaveFixtures.directory("noble-power-results")
 if not SaveFixtures.available([DIR+"normal-concentrated.json"]):
  quit(77); return
 await setup()
 var offer: Dictionary=Power.intercept(c,request()); var id: String=offer.negotiation_id
 c.gold=0
 var snap: Variant=canonical({"people":c.officer_registry.people,"posts":c.officer_registry.posts,"gold":c.gold})
 check(not Power.resolve(c,id,"compensate").ok and canonical({"people":c.officer_registry.people,"posts":c.officer_registry.posts,"gold":c.gold})==snap,"insufficient funds no personnel or money changes")
 check(Power.resolve(c,id,"wait").ok,"unfunded wait allowed")
 var due: int=Power.records(c.strategy_state).requests[id].due_month
 c.officer_registry.people["historical:001"].location="geumgwan" # explicitly invalid successor boundary
 c.year=int((due-1)/12.0); c.month=(due-1)%12+1; Power.begin_month(c)
 check(Power.records(c.strategy_state).requests[id].status=="successor_needed" and c.officer_registry.posts["governor:geumseong"]=="historical:004","invalid successor retains actual incumbent")
 check(Power.retarget(c,id,"historical:003").ok and Power.records(c.strategy_state).requests[id].due_month==due,"eligible new successor completes without restarting wait")
 await setup(); offer=Power.intercept(c,request()); id=offer.negotiation_id
 snap=canonical(c.officer_registry.people)
 check(Power.resolve(c,id,"withdraw").ok and canonical(c.officer_registry.people)==snap,"withdraw no appointment effects")
 await setup(); offer=Power.intercept(c,request()); id=offer.negotiation_id
 var gold: int=c.gold; c.provinces.geumseong.faction="백제"; Power.begin_month(c)
 check(Power.records(c.strategy_state).requests[id].status=="invalid" and c.gold==gold,"captured pending no cost or refund")
 check(Registry.set_location(c.officer_registry,"historical:004","geumgwan"),"involuntary base loss does not charge royal handover to escape")
 await setup(); offer=Power.intercept(c,request()); id=offer.negotiation_id
 c.officer_registry.people["historical:004"].alive=false; snap=canonical(c.officer_registry.politics.history)
 Power.begin_month(c)
 check(Power.records(c.strategy_state).requests[id].status=="invalid" and canonical(c.officer_registry.politics.history)==snap,"death ends negotiation without royal penalty")
 await setup()
 var uid: String=Army.at_city(c.strategy_state,"geumseong","silla")[0]
 var split: Dictionary=Army.split(c.strategy_state,c.provinces,"silla",uid,1000); uid=split.unit_id
 check(Army.train(c.strategy_state,c.provinces,"silla",uid,"historical:001",c.year*12+c.month).ok,"real training before forced commander retrieval")
 offer=Power.intercept(c,{"kind":"commander","target":uid,"officer_id":"","faction_id":"silla"}); id=offer.negotiation_id
 check(Power.resolve(c,id,"force").ok,"force with ongoing training")
 gold=c.gold; var trained: float=Army.training(c.strategy_state.unit_rosters[uid])
 c.month+=1; Army.process(c.strategy_state,c.provinces,c.year*12+c.month)
 check(c.gold==gold and Army.training(c.strategy_state.unit_rosters[uid])==trained,"blocked ongoing training has zero expense/progress")
 Power.finish_month(c); Army.process(c.strategy_state,c.provinces,c.year*12+c.month)
 check(c.gold==gold,"same month retry after effect expires does not charge training")
 c.month+=1; Army.process(c.strategy_state,c.provinces,c.year*12+c.month)
 check(c.gold<gold and Army.training(c.strategy_state.unit_rosters[uid])>trained,"following month training resumes with real payment")
 await setup()
 uid=Army.at_city(c.strategy_state,"geumseong","silla")[0]
 var part: Dictionary=Army.split(c.strategy_state,c.provinces,"silla",uid,1000); uid=part.unit_id
 var population: int=c.provinces.geumseong.population
 var disband: Dictionary=c.Mobilization.disband(c.strategy_state,c.provinces,"silla",uid,100,c.year*12+c.month)
 check(not disband.ok and c.provinces.geumseong.population==population and int(c.strategy_state.unit_rosters[uid].troops)==1000,"disband authority loss cannot bypass negotiation")
 Power.resolve(c,disband.negotiation_id,"withdraw")
 var transfer: Dictionary=c.queue_province_transfer({"source_id":"geumseong","target_id":"geumgwan","troops":1000,"unit_ids":[uid],"officer_ids":[]},true,"silla")
 check(not transfer.ok and c.strategy_state.unit_rosters[uid].status=="stationed","troop handover without commander requires negotiation")
 offer=Power.open_request(c.strategy_state,"commander",uid)
 check(Power.resolve(c,offer.id,"force").ok,"force selected unit authority")
 var state_copy: Dictionary=c.strategy_state.duplicate(true); var cities_copy: Dictionary=c.provinces.duplicate(true)
 var fight: Dictionary=Army.combat(state_copy,cities_copy,"sabi","geumseong",50,50,c.year*12+c.month)
 check(fight.defend_units.has(uid) and fight.defender_power>0,"actual combat calculation retains disrupted defending army")
 transfer=c.queue_province_transfer({"source_id":"geumseong","target_id":"geumgwan","troops":1000,"unit_ids":[uid],"officer_ids":[]},true,"silla")
 check(transfer.ok and c.strategy_state.unit_rosters[uid].status=="transit" and not Power.unit_reason(c.strategy_state,uid).is_empty(),"friendly movement allowed with retained unit disruption")
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 c._on_load_button_pressed(DIR+"normal-concentrated.json"); events()
 var build: Dictionary=c.Industry.start(c.strategy_state,c.provinces,c.strategy,"silla","geumseong","build","academy","historical:001",c.year*12+c.month,c.scenario_id,c.iron_supply_rules)
 check(build.ok,"normal funded construction before handover")
 if build.ok:
  offer=Power.intercept(c,request()); Power.resolve(c,offer.negotiation_id,"force")
  var job: Dictionary=c.Industry.jobs(c.strategy_state)[build.job_id]
  var base: int=c.Industry.work(c.get_officer("historical:001"),"build")
  var before: int=job.progress
  for n: int in range(3):
   c._advance_month(); c.Industry.process(c.strategy_state,c.provinces,c.year*12+c.month)
   check(int(job.progress)-before==mini(int(job.required)-before,floori(base*0.8) if n<2 else base),"construction exact affected monthly work "+str(n))
   before=job.progress; Power.finish_month(c)
  print("CONSTRUCTION POWER EVIDENCE ",base," ",JSON.stringify(job))
 c._on_load_button_pressed(DIR+"normal-concentrated.json"); events()
 # Boundary actor switch ONLY to exercise the existing AI monthly path on the saved normal authority distribution.
 c.player_faction_id="baekje"; c.player_faction="백제"; c.month+=1
 c.run_enemy_ai_turns()
 var history: Array=Power.records(c.strategy_state).get("history",[])
 check(history.any(func(h): return h.has("ai_choice")),"actual AI monthly path nominates and chooses handover")
 snap=canonical(Power.records(c.strategy_state)); gold=c.Economy.balance(c.strategy_state,"silla")
 c.run_enemy_ai_turns()
 check(canonical(Power.records(c.strategy_state))==snap and c.Economy.balance(c.strategy_state,"silla")==gold,"repeated AI monthly path no negotiation or fee replay")
 print("AI POWER EVIDENCE ",JSON.stringify(history))
 c._on_save_button_pressed(DIR+"boundary-ai-selected.json")
 c.ending_busy=true # explicit terminal boundary avoids pending scene presentation on incomplete result fixture
 c.strategy_state.campaign_ending.status="defeat"
 snap=canonical(c.strategy_state)
 Power.ai(c); Power.begin_month(c); Power.finish_month(c)
 check(canonical(c.strategy_state)==snap,"terminal automatic politics frozen")
 print("NOBLE POWER LIFECYCLE: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
