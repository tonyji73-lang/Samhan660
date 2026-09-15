extends "res://tests/officer_registry_test.gd"
const Ending=preload("res://campaign_ending.gd")
const Army=preload("res://army_readiness.gd")
const Economy=preload("res://faction_economy.gd")
const Industry=preload("res://industry_assignment.gd")
const Supply=preload("res://supply_transport.gd")
const Production=preload("res://production_system.gd")
var DIR="res://.godot/ending-results/"
var rows: Array=[]
func idle() -> void:
 c.event_presentation.queue.clear()
 if c.event_presentation.active: c.event_presentation._finish()
 await process_frame
 await process_frame
func full() -> Variant:
 return canonical({"state":c.strategy_state,"provinces":c.provinces,"orders":c.pending_transfer_orders,"crop":c.crop_failure_events,"year":c.year,"month":c.month})
func _run() -> void:
 create_timer(240).timeout.connect(func(): quit(2))
 DIR+=str(Time.get_unix_time_from_system()).replace(".","-")+"/"
 DirAccess.make_dir_recursive_absolute(DIR)
 var latest:=FileAccess.open("res://.godot/ending-results/latest.txt",FileAccess.WRITE); latest.store_string(DIR); latest.close()
 for scenario: Dictionary in Scenarios.SCENARIOS:
  for faction: Dictionary in Scenarios.get_scenario(scenario.id).factions:
   if not Scenarios.is_faction_playable_by_default(scenario.id,faction.id): continue
   await start(scenario,faction.id,"historical"); await idle()
   var evaluation: Dictionary=Ending.evaluate(c.strategy_state,c.provinces)
   check(evaluation.status=="ongoing","actual selection initial ongoing "+scenario.id+"/"+faction.id)
   var reached: Array=[c._get_starting_province_id()]; var pos: int=0
   while pos<reached.size():
    for target: String in c.province_connections.get(reached[pos],[]):
     if not reached.has(target): reached.append(target)
    pos+=1
   check(Ending.TARGETS.all(func(case_id): return reached.has(case_id)),"all fixed target cities connected by actual attack graph")
   rows.append({"scenario":scenario.id,"faction":faction.id,"rule":c.strategy_state.campaign_ending.definition.duplicate(true),"initial":evaluation})
 check(rows.size()==12,"exactly twelve actual playable combinations")
 await start(Scenarios.SCENARIOS[0],"silla","historical"); await idle()
 check(c._on_save_button_pressed(DIR+"normal-before.json"),"save normal ongoing campaign")
 var rule: Dictionary=c.strategy_state.campaign_ending.definition
 var original: Array=rule.targets.duplicate()
 rule.targets=[]; check(Ending.evaluate(c.strategy_state,c.provinces).status=="configuration_error","empty targets error")
 rule.targets=["foreign_trade_node"]; check(Ending.evaluate(c.strategy_state,c.provinces).status=="configuration_error","invalid target error")
 rule.targets=original
 c.ending_busy=true
 check(c.evaluate_campaign_ending("partial_load").status=="deferred","partial restoration never evaluates")
 c.ending_busy=false
 # Boundary fixture: preserve genuine troops/stats/costs. Only ownership of
 # other targets is changed to stage the LAST objective before actual battle.
 c.resolve_army_battle("bukhansan","goksan","silla")
 c.resolve_army_battle("bukhansan","hwanghae","silla")
 for city: String in Ending.TARGETS:
  if city!="hwanghae": c.provinces[city].faction="신라"
 check(c._on_save_button_pressed(DIR+"boundary-before-victory.json"),"save explicitly labeled last-objective fixture")
 var battle: Dictionary=c.resolve_army_battle("danghangseong","hwanghae","silla")
 check(battle.ok and battle.won,"actual unchanged combat captures final objective")
 await idle()
 check(c.strategy_state.campaign_ending.status=="victory","stable battle callback confirms victory")
 check(c.ending_dialog.visible,"result presentation visible")
 var final: Variant=full(); var id: String=c.strategy_state.campaign_ending.result.result_id
 c.evaluate_campaign_ending("repeat")
 c._on_end_turn_button_pressed()
 check(not c.request_recruitment("geumseong",1000).ok,"terminal recruitment blocked")
 check(not c.request_production_command("geumseong","iron_procurement","start").ok,"terminal production command blocked")
 check(not c.resolve_army_battle("bukhansan","goksan","silla").ok,"terminal actual combat blocked")
 check(not c.dismiss_governor("geumseong"),"terminal dismissal blocked")
 check(not Economy.post(c.strategy_state,"silla",100,"test",9999),"terminal treasury cannot receive automatic grants")
 Supply.process(c.strategy_state,c.provinces,9999); Industry.process(c.strategy_state,c.provinces,9999)
 Army.process(c.strategy_state,c.provinces,9999); c.run_enemy_ai_turns(); c.process_pending_transfer_orders()
 check(full()==final,"repeat evaluation and backend commands preserve every resource and roster")
 check(not c.save_ending_result(DIR+"normal-before.json"),"existing manual save never overwritten by ending writer")
 check(c.save_ending_result(DIR+"victory.json"),"dedicated complete result serialization")
 for n: int in range(3):
  c._on_load_button_pressed(DIR+"victory.json"); await idle()
  check(c.strategy_state.campaign_ending.result.result_id==id and full()==final,"terminal repeat load identity/state "+str(n))
 check(not c.save_ending_result(DIR+"missing-parent/result.json"),"write failure reported and retry remains available")
 check(c.ending_save_message.contains("실패") and c.strategy_state.campaign_ending.status=="victory","failed save retains visible terminal result")
 check(c.save_ending_result(DIR+"victory.json"),"retry succeeds without reconfirmation")
 c._on_load_button_pressed(DIR+"normal-before.json"); await idle()
 check(not Ending.finished(c.strategy_state) and not c.end_turn_button.disabled,"pre-ending load resumes ongoing state")
 var stamp: int=c.year*12+c.month
 c._on_end_turn_button_pressed(); await idle()
 check(c.year*12+c.month==stamp+1,"restored ongoing game can advance")
 # Last base defeat via actual enemy combat; inert/transit units do not give
 # an unavailable mobile recapture command.
 c._on_load_button_pressed(DIR+"normal-before.json"); await idle()
 c.resolve_army_battle("bukhansan","goksan","silla")
 c.resolve_army_battle("bukhansan","hwanghae","silla")
 for city: String in Ending.TARGETS:
  if c.provinces[city].faction=="신라" and city!="bukhansan": c.provinces[city].faction="백제"
 c._on_save_button_pressed(DIR+"boundary-before-defeat.json")
 var defeat: Dictionary=c.resolve_army_battle("goksan","bukhansan","goguryeo")
 check(defeat.ok and defeat.won,"actual AI combat takes last player base")
 await idle()
 check(c.strategy_state.campaign_ending.status=="defeat","inert surviving unit records do not defer defeat")
 check(c.strategy_state.campaign_ending.result.result_id!=id,"divergent outcome from same pre-ending save has distinct result identity")
 check(FileAccess.file_exists("user://campaign_endings/"+id.replace(":","-")+".json"),"prior victory dedicated save survives defeat branch")
 check(c.strategy_state.campaign_ending.result.snapshot.troops>0,"defeat distinguishes surviving records from actionable recovery")
 c.save_ending_result(DIR+"defeat.json")
 await start(Scenarios.SCENARIOS[0],"silla","historical"); await idle()
 check(not Ending.finished(c.strategy_state) and not c.ending_dialog.visible and not c.map_area.modal_input_locked,"same process fresh campaign clears terminal UI/state/locks")
 stamp=c.year*12+c.month; c._on_end_turn_button_pressed(); await idle()
 check(c.year*12+c.month==stamp+1,"fresh campaign monthly processing works")
 var file:=FileAccess.open(DIR+"conditions.json",FileAccess.WRITE); file.store_string(JSON.stringify(rows,"\t")); file.close()
 print("CAMPAIGN ENDING: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
