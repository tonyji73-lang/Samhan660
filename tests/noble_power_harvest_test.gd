extends "res://tests/ai_military_planning_audit.gd"
const Power=preload("res://noble_power_constraints.gd")
func _run() -> void:
 var rows: Array=[]
 for choice: String in ["compensate","force"]:
  await start(Scenarios.SCENARIOS[0],"silla","historical"); events()
  c._on_load_button_pressed("res://.godot/noble-power-results/normal-concentrated.json"); events()
  # Calendar boundary only: use unchanged saved quantities, no claimed normal autumn progression.
  c.year=637; c.month=9
  var offer: Dictionary=Power.intercept(c,{"kind":"governor","target":"geumseong","officer_id":"historical:001","faction_id":"silla"})
  check(Power.resolve(c,offer.negotiation_id,choice).ok,"harvest boundary handover")
  c.month=10
  var before: int=c.provinces.geumseong.food_stock
  var expected: int=roundi(c.calculate_collected_harvest(c.provinces.geumseong)*0.30)
  c.process_seasonal_harvest()
  var amount: int=int(c.provinces.geumseong.food_stock)-before
  check(amount==expected,"actual seasonal harvest credited once "+choice)
  c.process_seasonal_harvest()
  check(c.provinces.geumseong.food_stock==before+amount,"same seasonal harvest no double credit")
  rows.append({"choice":choice,"before":before,"amount":amount,"after":c.provinces.geumseong.food_stock,"quote":c.city_operation_quote("geumseong")})
 print("HARVEST POWER ",JSON.stringify(rows))
 var f:=FileAccess.open("res://.godot/noble-power-results/boundary-harvest.json",FileAccess.WRITE); f.store_string(JSON.stringify(rows,"\t")); f.close()
 print("NOBLE HARVEST: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)