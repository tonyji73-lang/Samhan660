extends "res://tests/campaign_ending_gui_test.gd"
const P=preload("res://ai_military_planning.gd")
var worker: String=""
var evidence: Array=[]
func click(control: Control) -> void:
 await settle()
 var parent: Node=control.get_parent()
 while parent!=null:
  if parent is ScrollContainer: parent.ensure_control_visible(control)
  parent=parent.get_parent()
 await settle()
 await super.click(control)
func events() -> void:
 c.event_presentation.queue.clear()
 if c.event_presentation.active: c.event_presentation._finish()
 var pending: Dictionary=c.crop_failure_events.get("pending",{})
 if not pending.is_empty(): c.resolve_event_choice(c.CropFailure.EVENT_ID,pending.occurrence_id,"maintain_tax")
 pending=c.officer_registry.get("politics",{}).get("pending",{})
 if not pending.is_empty(): c.Noble.resolve(c,pending.occurrence_id,"reject")
func escape() -> void:
 for down: bool in [true,false]:
  var key:=InputEventKey.new(); key.keycode=KEY_ESCAPE; key.pressed=down; Input.parse_input_event(key)
 await settle()
func pick(selector: OptionButton, id: String) -> void:
 for n: int in range(selector.item_count):
  if str(selector.get_item_metadata(n))==id: selector.select(n); selector.item_selected.emit(n); return
func month_step() -> void:
 await click(c.end_turn_button); events(); await settle()
func build(requirement: String) -> void:
 c.open_industry("geumgwan","build",requirement); await settle()
 pick(c.industry_overlay.officer_selector,worker); await settle()
 check(not c.industry_overlay.execute_button.disabled,"actual second-site building quote "+requirement)
 await screen("second-"+requirement+"-quote")
 var before: int=c.gold
 await click(c.industry_overlay.execute_button)
 var job: Dictionary=c.Industry.active(c.strategy_state,"build","geumgwan","silla")
 check(not job.is_empty() and before-c.gold==job.cost_paid,"second-site building paid exactly once "+requirement)
 if job.is_empty(): quit(1); return
 await screen("second-"+requirement+"-pending"); await escape()
 var months: int=0
 while not c.Industry.active(c.strategy_state,"build","geumgwan","silla").is_empty() and months<20: await month_step(); months+=1
 check(job.status=="completed","real monthly construction completed "+requirement)
 evidence.append({"kind":"build","requirement":requirement,"months":months,"paid":job.cost_paid,"worker":worker})
func _run() -> void:
 create_timer(360).timeout.connect(func(): quit(2))
 DIR="res://.godot/supply-expansion-results/"
 root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
 change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; events()
 c._on_load_button_pressed("res://.godot/mobilization-results/silla-final.json"); await settle(); events()
 c._on_save_button_pressed(DIR+"gui-normal-start.json")
 check(int(c.strategy_state.province_buildings.geumseong.forge)>0 and int(c.strategy_state.province_buildings.geumgwan.forge)==0,"normal prior player base exists, second base unbuilt")
 var people: Array=P.staff(c,"silla","geumseong")
 check(not people.is_empty(),"existing available officer, no injection")
 worker=str(people[0])
 check(c.queue_province_transfer({"source_id":"geumseong","target_id":"geumgwan","officer_ids":[worker],"troops":0},true).ok,"real paid-rules officer relocation")
 await month_step()
 await build("smelter"); await build("forge")
 c._on_city_card_production_requested("geumgwan"); await settle()
 var p: Node=c.production_overlay
 for recipe: int in [0,1]: p.recipe_selector.select(recipe); p.recipe_selector.item_selected.emit(recipe); await click(p.start_button)
 await screen("second-site-production-start"); await escape()
 var before_gold: int=c.gold
 await month_step(); await month_step()
 print("GUI PRODUCTION ",c.strategy_state.city_production.geumgwan," FP ",c.strategy_state.facility_progress.geumgwan)
 check(int(c.strategy_state.city_inventory.geumgwan.sword)==2,"second site made two real bundles")
 c._on_city_card_production_requested("geumgwan"); await screen("second-site-produced")
 for recipe: int in [0,1]: p.recipe_selector.select(recipe); p.recipe_selector.item_selected.emit(recipe); await click(p.stop_button)
 await escape()
 c.open_supply("geumgwan"); await settle()
 var freight: Node=c.supply_overlay
 pick(freight.destination,"geumseong"); freight.amounts.sword.value=2; await settle()
 await screen("second-site-shipping-quote")
 check(not freight.execute_button.disabled,"real produced stock dispatch allowed")
 var ship_gold: int=c.gold; await click(freight.execute_button)
 var order: Dictionary=freight.selected_order()
 check(not order.is_empty() and ship_gold-c.gold==order.cost_paid,"actual fee and stock dispatch")
 if order.is_empty(): quit(1); return
 await screen("second-site-transit"); await escape()
 c._on_save_button_pressed(DIR+"gui-normal-transit.json")
 await month_step()
 check(order.status=="arrived" and c.strategy_state.city_inventory.geumseong.sword==2,"secondary weapons arrived, no base stock mixed")
 c.open_supply("geumseong"); c.supply_overlay.rebuild(order.id); await screen("second-site-arrived"); await escape()
 c.select_province("geumseong"); c._on_recruit_button_pressed(); await settle()
 c.recruitment_overlay.quantity.value=200; await settle()
 var ids: Array=c.Army.at_city(c.strategy_state,"geumseong","silla")
 check(not c.recruitment_overlay.execute_button.disabled,"normal population/gold/grain permits200")
 await click(c.recruitment_overlay.execute_button)
 var uid: String=""
 for id: String in c.Army.at_city(c.strategy_state,"geumseong","silla"):
  if not ids.has(id): uid=id
 await click(c.recruitment_overlay.army_button); pick(c.army_overlay.selector,uid)
 c.army_overlay.bundles.value=2; await settle(); await click(c.army_overlay.equip_button)
 check(c.strategy_state.unit_rosters[uid].equipment==200 and c.strategy_state.city_inventory.geumseong.sword==0,"exact additional production -> transit -> real200-person equipment")
 await screen("second-site-equipped"); await escape()
 evidence.append({"production_gold_per_batch":16,"production_bundles":2,"transport":order.duplicate(true),"new_unit":c.strategy_state.unit_rosters[uid].duplicate(true),"gold_before_production":before_gold,"final_gold":c.gold})
 c._on_save_button_pressed(DIR+"gui-normal-equipped.json")
 # Existing normal AI campaign, information only: no actor/stock changes.
 c._on_load_button_pressed(DIR+"silla-60months.json"); await settle(); events()
 c.open_ai_military_brief(); await settle()
 check(c.military_brief_details.visible and c.military_brief_details.text.contains("군수망"),"scrollable real AI multiple-site report")
 await screen("ai-network-report")
 c.military_brief_details.scroll_to_line(18); await settle(); await screen("ai-network-report-lower")
 await click(c.playability_dialog.get_ok_button()); await settle()
 check(not c.map_area.modal_input_locked,"closing network report restores map")
 var file:=FileAccess.open(DIR+"gui-evidence.json",FileAccess.WRITE); file.store_string(JSON.stringify(evidence,"\t")); file.close()
 print("SUPPLY EXPANSION GUI: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)