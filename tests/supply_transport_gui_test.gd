extends "res://tests/industry_assignment_gui_test.gd"
const Supply=preload("res://supply_transport.gd")
const GRESULTS="res://.godot/supply-results/"
var transport_evidence: Array=[]

func screen(label: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(GRESULTS+label+".png")==OK,"capture "+label)

func select_destination(panel: Node,city: String) -> void:
	for n: int in range(panel.destination.item_count):
		if panel.destination.get_item_metadata(n)==city:
			panel.destination.select(n); panel.destination.item_selected.emit(n); break
	await settle()

func ship(source: String,target: String,cargo: Dictionary,label: String) -> String:
	c.select_province(source); c._on_transfer_button_pressed(); await settle()
	check(c.transfer_panel.visible,"existing support panel open")
	await click(c.transfer_panel.cargo_button)
	var panel: Node=c.supply_overlay
	check(panel.visible and c.map_area.modal_input_locked and not c.transfer_panel.visible,"cargo-only access locks map")
	await select_destination(panel,target)
	for item: String in cargo: panel.amounts[item].value=cargo[item]
	await settle(); check(not panel.execute_button.disabled,"shared quote executable "+label)
	await screen(label+"_quote")
	var before_gold: int=c.gold
	await click(panel.execute_button)
	var order: Dictionary=panel.selected_order()
	check(not order.is_empty() and before_gold-c.gold==order.cost_paid,"UI pays exact shipping cost "+label)
	await screen(label+"_transit")
	transport_evidence.append({"case":label,"order_at_dispatch":order.duplicate(true),"gold_before":before_gold,"gold_after":c.gold})
	await escape(); check(not c.map_area.modal_input_locked,"cargo Esc unlocks map")
	return str(order.id)

func capital_forge() -> void:
	c._on_city_card_production_requested("geumseong")
	var p: Node=c.production_overlay; p.recipe_selector.select(1); p.recipe_selector.item_selected.emit(1)
	await click(p.building_button)
	var panel: Node=c.industry_overlay
	for n: int in range(panel.officer_selector.item_count):
		if not str(panel.officer_selector.get_item_metadata(n)).is_empty():
			panel.officer_selector.select(n); panel.officer_selector.item_selected.emit(n)
			if not panel.execute_button.disabled: break
	check(not panel.execute_button.disabled,"capital actual officer can build forge")
	await click(panel.execute_button); await escape()
	var count: int=0
	while not c.Industry.active(c.strategy_state,"build","geumseong","silla").is_empty() and count<15:
		await month_step(); count+=1
	check(c.strategy_state.province_buildings.geumseong.forge==1,"capital forge completed without facility injection")

func _run() -> void:
	create_timer(540).timeout.connect(func(): push_error("SUPPLY GUI TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(GRESULTS)
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await events()
	worker=c.get_city_officer_ids("geumseong")[0]
	check(c.queue_province_transfer({"source_id":"geumseong","target_id":"geumgwan","officer_ids":[worker],"troops":0},true).ok,"real officer transfer for facilities")
	await month_step()
	await task("build","smelter",0); await task("build","forge",1); await task("research","swordsmithing",1)
	c._on_city_card_production_requested("geumgwan")
	var p: Node=c.production_overlay
	for recipe: int in [0,1]:
		p.recipe_selector.select(recipe); p.recipe_selector.item_selected.emit(recipe); await click(p.start_button)
	await escape(); await month_step(); await month_step()
	check(c.strategy_state.city_inventory.geumgwan.sword==2,"actual production created two swords")
	# Stop swordmaking to retain the next iron supply; no inventory injection.
	c._on_city_card_production_requested("geumgwan"); p.recipe_selector.select(1); p.recipe_selector.item_selected.emit(1); await click(p.stop_button); await escape()
	var sword_id: String=await ship("geumgwan","geumseong",{"sword":1},"sword")
	c._on_save_button_pressed(GRESULTS+"gui-transit.json")
	for n: int in range(3): c._on_load_button_pressed(GRESULTS+"gui-transit.json")
	check(Supply.ensure(c.strategy_state).orders[sword_id].moves==0,"three loads do not move cargo")
	await month_step()
	check(c.strategy_state.city_inventory.geumseong.sword==1 and Supply.ensure(c.strategy_state).orders[sword_id].status=="arrived","produced sword arrives at another city")
	c.open_supply("geumseong"); c.supply_overlay.rebuild(sword_id); await screen("sword_arrived"); await escape()
	await capital_forge()
	c._on_city_card_production_requested("geumseong"); p.recipe_selector.select(1); p.recipe_selector.item_selected.emit(1); await click(p.start_button); await escape()
	await month_step()
	check(c.strategy_state.city_production.geumseong.iron_sword.reason.contains("철"),"production genuinely blocked by iron")
	c._on_city_card_production_requested("geumseong"); await screen("iron_blocked"); await escape()
	var iron_id: String=await ship("geumgwan","geumseong",{"iron":4},"iron")
	var sword_before: int=c.strategy_state.city_inventory.geumseong.sword
	await month_step()
	check(Supply.ensure(c.strategy_state).orders[iron_id].status=="arrived" and c.strategy_state.city_inventory.geumseong.sword==sword_before+1 and c.strategy_state.city_inventory.geumseong.iron==2,"arriving iron feeds same-month production")
	c._on_city_card_production_requested("geumseong"); await screen("iron_resumed"); await escape()
	# Empty the source by valid, paid cargo commands. This creates a reproducible shortage without changing stocks.
	var emptied: int=0
	while int(c.provinces.geumgwan.food_stock)>0:
		var amount: int=mini(2000,int(c.provinces.geumgwan.food_stock))
		var r: Dictionary=Supply.start(c.strategy_state,c.provinces,"silla","geumgwan","geumseong",{"grain":amount},c.year*12+c.month)
		check(r.ok,"paid outbound food isolates recruitment shortage"); if not r.ok: break
		emptied+=amount
	c.select_province("geumgwan"); c._on_recruit_button_pressed(); await settle()
	check(c.recruitment_overlay.execute_button.disabled,"warehouse shortage blocks recruitment despite own in-transit grain")
	await screen("recruitment_blocked"); await escape()
	var food_id: String=await ship("geumseong","geumgwan",{"grain":1000},"grain")
	await month_step()
	check(Supply.ensure(c.strategy_state).orders[food_id].status=="arrived","food arrival")
	c.select_province("geumgwan"); c._on_recruit_button_pressed(); await settle()
	check(not c.recruitment_overlay.execute_button.disabled,"arrived grain enables recruitment")
	var gold_before: int=c.gold; var food_before: int=c.provinces.geumgwan.food_stock; var troops_before: int=c.provinces.geumgwan.troops
	await click(c.recruitment_overlay.execute_button)
	check(c.gold==gold_before-150 and c.provinces.geumgwan.food_stock==food_before-200 and c.provinces.geumgwan.troops==troops_before+1000,"actual recruitment pays delivered grain")
	await screen("recruitment_resumed"); await escape()
	transport_evidence.append({"case":"recruitment","outbound_grain":emptied,"gold_before":gold_before,"gold_after":c.gold,"food_before":food_before,"food_after":c.provinces.geumgwan.food_stock,"troops_before":troops_before,"troops_after":c.provinces.geumgwan.troops})
	# Isolated AI scenario checkpoint: shortage is created by its same paid transport command.
	var ai_dumped: int=0
	while int(c.provinces.geummajeo.food_stock)>0:
		var amount: int=mini(2000,int(c.provinces.geummajeo.food_stock))
		var r: Dictionary=Supply.start(c.strategy_state,c.provinces,"baekje","geummajeo","sabi",{"grain":amount},c.year*12+c.month)
		if not r.ok: break
		ai_dumped+=amount
	check(c.provinces.geummajeo.food_stock==0,"AI shortage set through real paid shipment")
	var start_stamp: int=c.year*12+c.month
	await month_step()
	var ai_order: Dictionary={}
	for order: Dictionary in Supply.ensure(c.strategy_state).orders.values():
		if order.faction_id=="baekje" and order.target=="geummajeo" and int(order.created_month)>start_stamp: ai_order=order
	check(not ai_order.is_empty(),"monthly AI autonomously supports shortage")
	# The player's panel intentionally does not expose AI command authority; use a read-only campaign log capture.
	await screen("ai_dispatch_log")
	for n: int in range(5):
		if ai_order.get("status","")=="arrived": break
		await month_step()
	check(ai_order.get("status","")=="arrived","autonomous AI shipment actually arrives")
	c.select_province("geummajeo"); await screen("ai_arrival_city")
	transport_evidence.append({"case":"ai","shortage_created_by_paid_exports":ai_dumped,"order":ai_order.duplicate(true),"decisions":Supply.ensure(c.strategy_state).ai_log.duplicate(true)})
	transport_evidence.append({"case":"final","year":c.year,"month":c.month,"transports":Supply.ensure(c.strategy_state).duplicate(true),"economy":c.strategy_state.faction_economy.duplicate(true),"provinces":c.provinces.duplicate(true),"inventory":c.strategy_state.city_inventory.duplicate(true)})
	c._on_save_button_pressed(GRESULTS+"gui-final.json")
	var f:=FileAccess.open(GRESULTS+"gui-evidence.json",FileAccess.WRITE); f.store_string(JSON.stringify(transport_evidence,"\t")); f.close()
	print("SUPPLY GUI TESTS: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
