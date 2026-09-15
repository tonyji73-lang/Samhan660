extends "res://tests/ai_military_planning_audit.gd"
const Power=preload("res://noble_power_constraints.gd")
func _run() -> void:
 DIR="res://.godot/noble-power-results/"
 var rows: Array=[]
 for choice: String in ["compensate","wait","force"]:
  seed(63220260915); await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
  c._on_load_button_pressed(DIR+"normal-front-concentrated.json"); events()
  var source: String=str(JSON.parse_string(FileAccess.get_file_as_string(DIR+"normal-front-actions.json")).city)
  var uid: String=""
  for candidate: String in Army.at_city(c.strategy_state,source,"silla"):
   if c.strategy_state.unit_rosters[candidate].commander_id=="historical:004": uid=candidate; break
  var quote: Dictionary=Power.quote(c,{"kind":"commander","target":uid,"officer_id":"historical:001","faction_id":"silla"})
  var target: String=""
  for city: String in c.province_connections.get(source,[]):
   if c.provinces[city].faction!="신라": target=city; break
  check(not target.is_empty(),"normal nearby actual enemy exists")
  var food: int=c.provinces[source].food_stock
  var before: Dictionary=c.resolve_army_battle(source,target,"silla")
  check(not before.ok and c.provinces[source].food_stock==food,"automatic alternate attack leader cannot bypass handover before cost")
  var offer: Dictionary=Power.intercept(c,quote.request)
  check(Power.resolve(c,offer.negotiation_id,choice).ok,"normal commander handover "+choice)
  var result: Dictionary=c.resolve_army_battle(source,target,"silla") if Army.attack_units(c.strategy_state,source,"silla").has(uid) else {"ok":false,"reason":Power.unit_reason(c.strategy_state,uid)}
  check(result.ok==(choice=="compensate"),"requested army immediate attack availability "+choice)
  var delay: int=0
  while not result.ok and delay<4:
   c.power_dialog.hide(); c._on_end_turn_button_pressed(); events(); await process_frame; delay+=1
   result=c.resolve_army_battle(source,target,"silla")
  check(result.ok,"real attack resumes after required handover/month "+choice)
  c._on_save_button_pressed(DIR+"normal-command-"+choice+"-battle.json")
  rows.append({"choice":choice,"quote":quote,"delay":delay,"battle":result,"state":metrics("silla")})
 var f:=FileAccess.open(DIR+"normal-command-comparison.json",FileAccess.WRITE); f.store_string(JSON.stringify(rows,"\t")); f.close()
 print("NOBLE COMMAND NORMAL: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)