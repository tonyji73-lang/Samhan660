extends "res://tests/ai_military_planning_audit.gd"
const Power=preload("res://noble_power_constraints.gd")
func setup() -> void:
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 # Boundary fixture: relocate existing armies, never add troops/equipment/money.
 for u: Dictionary in c.strategy_state.unit_rosters.values():
  if u.faction_id=="silla" and int(u.troops)>0: u.location="geumseong"; u.commander_id="historical:004"
 c.officer_registry.posts["governor:geumseong"]="historical:004"
 c.Army.sync(c.strategy_state,c.provinces)
func request() -> Dictionary:
 return {"kind":"governor","target":"geumseong","officer_id":"historical:001","faction_id":"silla"}
func _run() -> void:
 DIR="res://.godot/noble-power-results/"; DirAccess.make_dir_recursive_absolute(DIR)
 for choice: String in ["compensate","wait","force"]:
  await setup()
  var req: Dictionary=request(); var q: Dictionary=Power.quote(c,req)
  check(q.ok and q.required,"boundary actual influence triggers "+choice)
  var money: int=c.gold; var old: String=c.officer_registry.posts["governor:geumseong"]
  var loyalty: int=c.officer_registry.people[old].loyalty
  var coop: int=c.officer_registry.politics.groups["silla:military"].cooperation
  var case_offer: Dictionary=Power.intercept(c,req)
  check(not case_offer.ok and c.gold==money and c.officer_registry.posts["governor:geumseong"]==old,"offer is nonmutating authority and money")
  var id: String=case_offer.negotiation_id
  check(Power.resolve(c,id,choice).ok,"choice accepted "+choice)
  if choice=="wait":
   check(c.officer_registry.posts["governor:geumseong"]==old,"wait retains governor")
   var due: int=Power.records(c.strategy_state).requests[id].due_month
   c.year=int((due-1)/12.0); c.month=(due-1)%12+1
   Power.begin_month(c)
  check(c.officer_registry.posts["governor:geumseong"]=="historical:001","handover applied "+choice)
  check(c.gold==money-(int(q.gold) if choice=="compensate" else 0),"exact once fee "+choice)
  check(c.officer_registry.people[old].loyalty==loyalty-(20 if choice=="force" else 4),"retiree exact loss "+choice)
  check(c.officer_registry.politics.groups["silla:military"].cooperation==coop-(12 if choice=="force" else 2),"group exact loss "+choice)
  var data: Variant=canonical(Power.records(c.strategy_state)); var balance: int=c.gold
  check(not Power.resolve(c,id,choice).ok and c.gold==balance and canonical(Power.records(c.strategy_state))==data,"repeat choice no effects")
  check(c._on_save_button_pressed(DIR+"boundary-"+choice+".json"),"save "+choice)
  for n: int in range(2):
   c._on_load_button_pressed(DIR+"boundary-"+choice+".json"); events()
   check(c.gold==balance and canonical(Power.records(c.strategy_state))==data,"repeat restore "+choice)
  if choice=="force":
   check(Power.city_factor(c.strategy_state,"geumseong")==0.8,"city work reduced")
   var stamp: int=c.year*12+c.month
   for n: int in range(1,3):
    var next: int=stamp+n; c.year=int((next-1)/12.0); c.month=(next-1)%12+1
    Power.finish_month(c); Power.finish_month(c)
    check(Power.records(c.strategy_state).cities.geumseong.remaining==2-n,"city exact monthly countdown "+str(n))
  print("EVIDENCE ",choice," ",JSON.stringify(q)," money ",money,"->",balance)
 await setup()
 var uid: String=Army.at_city(c.strategy_state,"geumseong","silla")[0]
 var offer: Dictionary=Power.intercept(c,{"kind":"commander","target":uid,"officer_id":"","faction_id":"silla"})
 check(not offer.ok and offer.has("negotiation_id"),"commander authority negotiation")
 check(not Army.split(c.strategy_state,c.provinces,"silla",uid,100).ok,"pending split blocked")
 check(Power.resolve(c,offer.negotiation_id,"force").ok,"forced command retrieval")
 check(not Army.attack_units(c.strategy_state,"geumseong","silla").has(uid) and Army.at_city(c.strategy_state,"geumseong","silla").has(uid),"attack blocked defense retains unit")
 var part: Dictionary=Army.split(c.strategy_state,c.provinces,"silla",uid,100)
 check(part.ok and not Power.unit_reason(c.strategy_state,part.unit_id).is_empty(),"split inherits disruption")
 var combinations: int=0
 for scenario: Dictionary in Scenarios.SCENARIOS:
  for faction: Dictionary in Scenarios.get_scenario(scenario.id).factions:
   if not Scenarios.is_faction_playable_by_default(scenario.id,faction.id): continue
   await start(scenario,faction.id,"historical"); events(); combinations+=1
   check(Power.records(c.strategy_state).get("requests",{}).is_empty() and not c.Ending.finished(c.strategy_state),"initial no requests/ending "+scenario.id+faction.id)
   var cities: Array=P.owned(c,faction.id)
   if not cities.is_empty():
    var access: Dictionary=Power.quote(c,{"kind":"governor","target":cities[0],"officer_id":"","faction_id":faction.id})
    check(access.ok and not access.required,"initial common personnel path "+scenario.id+faction.id)
 check(combinations==12,"twelve supported combinations")
 print("NOBLE POWER: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)