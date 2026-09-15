extends "res://tests/officer_registry_test.gd"
const Ending=preload("res://campaign_ending.gd")
var DIR="res://.godot/ending-results/"
func idle() -> void:
 await process_frame; await process_frame
func close_opening() -> void:
 c.event_presentation.queue.clear()
 if c.event_presentation.active: c.event_presentation._finish()
 await idle()
func _run() -> void:
 create_timer(120).timeout.connect(func(): quit(2))
 DIR=FileAccess.get_file_as_string(DIR+"latest.txt")
 await start(Scenarios.SCENARIOS[0],"silla","historical"); await close_opening()
 # Existing normal save: neither resources nor ownership injected here.
 var legacy: String="res://.godot/playability-results/defeat-replacement-ready.json"
 c._on_load_button_pressed(legacy); await close_opening()
 var before: Variant=canonical({"provinces":c.provinces,"army":c.strategy_state.army,"units":c.strategy_state.unit_rosters,"finance":c.strategy_state.faction_economy})
 var legacy_id: String=c.strategy_state.campaign_ending.campaign_id
 for n: int in range(2):
  c._on_load_button_pressed(legacy); await close_opening()
  check(c.strategy_state.campaign_ending.campaign_id==legacy_id,"legacy migration stable identity")
  check(canonical({"provinces":c.provinces,"army":c.strategy_state.army,"units":c.strategy_state.unit_rosters,"finance":c.strategy_state.faction_economy})==before,"legacy normal resources and readiness unchanged")
 check(Ending.evaluate(c.strategy_state,c.provinces).status=="ongoing","normal completed 1000-person readiness does not imply final victory")
 var poor_state: Dictionary=c.strategy_state.duplicate(true)
 var poor_cities: Dictionary=c.provinces.duplicate(true)
 poor_state.faction_economy.accounts.silla.balance=0
 for city: String in poor_cities: poor_cities[city]["food_stock"]=0
 check(Ending.evaluate(poor_state,poor_cities).status=="ongoing","zero treasury and grain alone never cause defeat")
 for city: String in Ending.TARGETS: poor_cities[city].faction="신라"
 poor_cities.hwanghae.faction="백제"
 for relation: Dictionary in poor_state.relations.values(): relation["status"]="동맹"
 check(Ending.evaluate(poor_state,poor_cities).status=="ongoing","allied city is not direct ownership")
 c._on_load_button_pressed(DIR+"normal-before.json"); await close_opening()
 # Explicit event boundary: ownership only, real mandatory-choice effect.
 for city: String in Ending.TARGETS: c.provinces[city].faction="신라"
 var pending: Dictionary={"event_id":c.CropFailure.EVENT_ID,"occurrence_id":"ending-choice-boundary-v1","province_id":"geumseong","payload":{"province_name":"금성","harvest_loss":0}}
 c.crop_failure_events.pending=pending.duplicate(true)
 var grain: int=c.provinces.geumseong.food_stock
 c._present_pending_choice(true); await idle()
 check(c.event_presentation.awaiting_choice(),"real mandatory choice displayed")
 check(c.evaluate_campaign_ending("before_choice").status=="deferred" and not Ending.finished(c.strategy_state),"final goal waits for required choice")
 c._on_save_button_pressed(DIR+"boundary-required-choice.json")
 c._on_load_button_pressed(DIR+"boundary-required-choice.json"); await idle()
 check(c.event_presentation.awaiting_choice() and not Ending.finished(c.strategy_state),"complete load restores pending choice before ending")
 c.event_presentation._choose("force_requisition"); await idle()
 check(c.provinces.geumseong.food_stock==grain+500,"actual event effect applies once before ending")
 check(not Ending.finished(c.strategy_state) and c.event_presentation.active,"event result and final result do not overlap")
 c.event_presentation.view.complete_text(); c.event_presentation.next(); await idle()
 if c.event_presentation.active: c.event_presentation.next(); await idle()
 check(Ending.finished(c.strategy_state) and c.ending_dialog.visible,"event presentation completion confirms ending")
 check(c.save_ending_result(DIR+"event-victory.json"),"event ending dedicated save")
 var manual: String=FileAccess.get_file_as_string(DIR+"normal-before.json")
 check(not c._on_save_button_pressed(DIR+"normal-before.json") and FileAccess.get_file_as_string(DIR+"normal-before.json")==manual,"existing Save entrypoint cannot overwrite manual progress after ending")
 var terminal_state: Variant=canonical(c.strategy_state)
 var terminal_cities: Variant=canonical(c.provinces)
 var old_month: int=c.month
 c.month=9; c.process_seasonal_harvest(); c.process_monthly_commerce_income(); c.process_monthly_troop_food_upkeep(); c.process_monthly_storage_losses(); c.month=old_month
 check(canonical(c.strategy_state)==terminal_state and canonical(c.provinces)==terminal_cities,"terminal direct seasonal/tax/upkeep/storage callbacks do not alter resources")
 for n: int in range(2):
  c._on_load_button_pressed(DIR+"event-victory.json"); await idle()
  c.resolve_event_choice(c.CropFailure.EVENT_ID,pending.occurrence_id,"force_requisition")
  c._on_end_turn_button_pressed()
  check(c.provinces.geumseong.food_stock==grain+500,"terminal repeated load/choice/month never grants grain again")
 # Last city lost while troop transfer is in transit: actual transfer resolver
 # cannot capture enemy destination or return to an enemy source.
 c._on_load_button_pressed(DIR+"normal-before.json"); await close_opening()
 check(c.queue_province_transfer({"source_id":"geumgwan","target_id":"geumseong","troops":1000,"officer_ids":[]}).ok,"actual troop transfer starts")
 for city: String in Ending.TARGETS:
  if c.provinces[city].faction=="신라": c.provinces[city].faction="백제"
 check(Ending.evaluate(c.strategy_state,c.provinces).status=="defeat","in-transit survivors cannot recapture enemy-owned destination")
 check(not c.resolve_army_battle("geumgwan","geumseong","silla").ok,"actual surviving army attack rejected without owned departure base")
 # All-target control during an unstable phase is deferred even if no event.
 c.ending_busy=true; check(c.evaluate_campaign_ending("unstable").status=="deferred","unstable transient zero cities is not confirmed")
 c.ending_busy=false
 c._on_load_button_pressed(DIR+"normal-before.json"); await close_opening()
 c.strategy_state.campaign_ending.definition.targets=["geumseong"]
 check(Ending.evaluate(c.strategy_state,c.provinces).status=="configuration_error","truncated fixed definition is a configuration error")
 c._on_save_button_pressed(DIR+"boundary-invalid-rule.json")
 c._on_load_button_pressed(DIR+"boundary-invalid-rule.json"); await idle()
 check(not Ending.finished(c.strategy_state) and c.log_label.text.contains("설정 오류"),"invalid saved definition visible without false victory")
 var autumn: Dictionary=Scenarios.SCENARIOS[0].duplicate(true); autumn.season="autumn"
 await start(autumn,"silla","historical"); await close_opening()
 check(c.month==7 and c.strategy_state.campaign_ending.start_month==c.year*12+c.month,"new campaign elapsed time begins at actual selected start season")
 print("ENDING EVENTS: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
