extends "res://tests/ai_military_planning_audit.gd"
const Power=preload("res://noble_power_constraints.gd")
func _run() -> void:
 DIR="res://.godot/noble-power-results/"; seed(63220260915)
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 c._on_load_button_pressed(DIR+"normal-concentrated.json"); events()
 var offer: Dictionary=Power.intercept(c,{"kind":"governor","target":"geumseong","officer_id":"","faction_id":"silla"})
 check(Power.resolve(c,offer.negotiation_id,"compensate").ok,"paid governor retirement before commander deployment")
 var job: Dictionary=c.Industry.active(c.strategy_state,"production","geumseong","silla")
 if not job.is_empty(): c.Industry.pause(c.strategy_state,"silla",job.id,c.year*12+c.month)
 var uid: String=""
 for id: String in Army.at_city(c.strategy_state,"geumseong","silla"):
  if c.strategy_state.unit_rosters[id].commander_id=="historical:004": uid=id; break
 var steps: Array=[]
 for n: int in range(10):
  var source: String=c.strategy_state.unit_rosters[uid].location
  var front: bool=c.province_connections.get(source,[]).any(func(city): return c.provinces[city].faction!="신라")
  if front:
   var manager: Dictionary=c.Industry.start(c.strategy_state,c.provinces,c.strategy,"silla",source,"production","","historical:004",c.year*12+c.month,c.scenario_id,c.iron_supply_rules)
   check(manager.ok,"actual production duty exposes alternate commander requirement")
   check(c._on_save_button_pressed(DIR+"normal-front-concentrated.json"),"normal real deployment saved")
   var f:=FileAccess.open(DIR+"normal-front-actions.json",FileAccess.WRITE); f.store_string(JSON.stringify({"steps":steps,"unit":uid,"city":source,"influence":Power.Core.influence(c.strategy_state,c.provinces,"silla")},"\t")); f.close()
   print("NORMAL FRONT READY ",source," ",n); quit(0 if failures==0 else 1); return
  var best: Array=[]
  for city: String in P.owned(c,"silla"):
   if not c.province_connections.get(city,[]).any(func(next): return c.provinces[next].faction!="신라"): continue
   var path: Array=P.military_route(c,"silla",source,city)
   if path.size()>1 and (best.is_empty() or path.size()<best.size()): best=path
  check(not best.is_empty(),"real friendly route to front")
  if best.is_empty(): quit(1); return
  var result: Dictionary=c.queue_province_transfer({"source_id":source,"target_id":best[1],"troops":int(c.strategy_state.unit_rosters[uid].troops),"unit_ids":[uid],"officer_ids":["historical:004","historical:001"]},true,"silla")
  check(result.ok,"real commander/army/queen transfer "+str(best)); steps.append({"source":source,"target":best[1],"result":result})
  if not result.ok: print(result); quit(1); return
  c.power_dialog.hide(); c._on_end_turn_button_pressed(); events(); await process_frame
 print("NO FRONT"); quit(1)