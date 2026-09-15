extends "res://tests/ai_military_planning_audit.gd"
const Power=preload("res://noble_power_constraints.gd")
func _run() -> void:
 DIR="res://.godot/noble-power-results/"; DirAccess.make_dir_recursive_absolute(DIR)
 seed(63220260915)
 await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
 c._on_load_button_pressed("res://.godot/playability-results/politics-B-12months.json"); events()
 var actions: Array=[]
 var start_stamp: int=c.year*12+c.month
 for step: int in range(18):
  # Dispatch actual existing unassigned troops along the normal friendly movement graph.
  var capital: Array=Army.at_city(c.strategy_state,"geumseong","silla")
  var main: String=""
  for uid: String in capital:
   if c.strategy_state.unit_rosters[uid].commander_id=="historical:004": main=uid; break
  if not main.is_empty():
   for uid: String in capital:
    if uid==main: continue
    var result: Dictionary=Army.merge(c.strategy_state,c.provinces,"silla",main,uid)
    actions.append({"month":step,"merge":uid,"result":result})
  var influence: Dictionary=Power.Core.influence(c.strategy_state,c.provinces,"silla")
  print("NORMAL CONCENTRATION ",step," ",influence.groups["silla:military"])
  if float(influence.groups["silla:military"].influence)>=40:
   check(c._on_save_button_pressed(DIR+"normal-concentrated.json"),"normal concentration saved")
   var f:=FileAccess.open(DIR+"normal-concentration-actions.json",FileAccess.WRITE); f.store_string(JSON.stringify({"source":"politics-B-12months","months":c.year*12+c.month-start_stamp,"actions":actions,"influence":influence},"\t")); f.close()
   print("NORMAL REACH ",step); quit(); return
  for city: String in P.owned(c,"silla"):
   if city in ["geumseong","gukwon"]: continue
   var path: Array=P.military_route(c,"silla",city,"geumseong")
   if path.size()<2: continue
   var ids: Array=Army.at_city(c.strategy_state,city,"silla",true)
   var remaining: int=Army.count(c.strategy_state,ids)-1000
   for uid: String in ids:
    var unit: Dictionary=c.strategy_state.unit_rosters[uid]
    if not str(unit.commander_id).is_empty() or remaining<=0: continue
    if int(unit.troops)>remaining:
     var divided: Dictionary=Army.split(c.strategy_state,c.provinces,"silla",uid,remaining)
     if not divided.ok: continue
     uid=divided.unit_id; unit=c.strategy_state.unit_rosters[uid]
    var result: Dictionary=c.queue_province_transfer({"source_id":city,"target_id":path[1],"troops":int(unit.troops),"officer_ids":[],"unit_ids":[uid]},false,"silla")
    actions.append({"month":step,"move":uid,"source":city,"target":path[1],"result":result})
    if result.ok: remaining-=int(unit.troops)
  c.power_dialog.hide(); c._on_end_turn_button_pressed(); events(); await process_frame
 print("NORMAL NOT REACHED ",JSON.stringify(actions)); quit(1)