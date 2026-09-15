extends "res://tests/ai_military_planning_audit.gd"
const Power=preload("res://noble_power_constraints.gd")
func _run() -> void:
 for label: String in ["politics-normal-baseline","politics-A-12months","politics-B-12months","politics-C-12months"]:
  await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
  c._on_load_button_pressed("res://.godot/playability-results/"+label+".json"); events()
  print("NORMAL ",label," ",Power.Core.influence(c.strategy_state,c.provinces,"silla"))
  for city: String in c.Economy.city_ids(c.strategy_state,c.provinces):
   if c.provinces[city].faction!="신라": continue
   for person: String in c.get_city_officer_ids(city):
    for req: Dictionary in [{"kind":"governor","target":city,"officer_id":person,"faction_id":"silla"}]:
     var q: Dictionary=Power.quote(c,req)
     if q.get("required",false): print("QUALIFY ",req," ",q)
 var rows: Array=[]
 for path: String in ["res://.godot/playability-results/politics-A-12months.json","res://.godot/playability-results/politics-B-12months.json","res://.godot/noble-power-results/normal-concentrated.json"]:
  await start(Scenarios.SCENARIOS[0],"silla","historical"); events(); c._on_load_button_pressed(path); events()
  var req: Dictionary={"kind":"commander","target":"unit:14","officer_id":"historical:003","faction_id":"silla"}
  var q: Dictionary=Power.quote(c,req)
  var gold: int=c.gold
  var applied: Dictionary=Army.appoint(c.strategy_state,c.provinces,"silla","unit:14","historical:003")
  var concentrated: bool=path.contains("normal-concentrated")
  check(q.ok and q.required==concentrated and applied.ok!=concentrated and c.gold==gold,"same real command handover across normal authority distributions "+path)
  rows.append({"source":path,"quote":q,"actual":applied})
 var f:=FileAccess.open("res://.godot/noble-power-results/threshold-comparison.json",FileAccess.WRITE); f.store_string(JSON.stringify(rows,"\t")); f.close()
 print("POWER THRESHOLD: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
