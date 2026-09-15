extends "res://tests/ai_military_planning_audit.gd"
const Power=preload("res://noble_power_constraints.gd")
func _run() -> void:
 DIR="res://.godot/noble-power-results/"
 var rows: Array=[]
 for choice: String in ["compensate","wait","force"]:
  seed(63220260915)
  await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
  c._on_load_button_pressed(DIR+"normal-concentrated.json"); events()
  var before: Dictionary=metrics("silla")
  var offer: Dictionary=Power.intercept(c,{"kind":"governor","target":"geumseong","officer_id":"historical:001","faction_id":"silla"})
  check(offer.has("negotiation_id"),"normal threshold requires actual handover "+choice)
  if not offer.has("negotiation_id"): continue
  var id: String=offer.negotiation_id
  var quote: Dictionary=Power.records(c.strategy_state).requests[id].duplicate(true)
  check(Power.resolve(c,id,choice).ok,"normal selected "+choice)
  c._on_save_button_pressed(DIR+"normal-"+choice+"-accepted.json")
  var months: Array=[]
  for n: int in range(4):
   c.power_dialog.hide(); c._on_end_turn_button_pressed(); events(); await process_frame
   months.append({"metrics":metrics("silla"),"city":c.city_operation_quote("geumseong"),"facility":c.strategy_state.facility_progress.get("geumseong",{}).duplicate(true),"handover":Power.records(c.strategy_state).duplicate(true)})
  check(Power.records(c.strategy_state).requests[id].status=="completed","normal handover completed "+choice)
  c._on_save_button_pressed(DIR+"normal-"+choice+"-4months.json")
  rows.append({"choice":choice,"before":before,"quote":quote,"months":months,"after":metrics("silla")})
 var f:=FileAccess.open(DIR+"normal-comparison.json",FileAccess.WRITE); f.store_string(JSON.stringify(rows,"\t")); f.close()
 print("NOBLE POWER NORMAL COMPARISON: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)