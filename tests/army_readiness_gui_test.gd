extends "res://tests/supply_transport_gui_test.gd"
const Army=preload("res://army_readiness.gd")
const ARESULTS="res://.godot/army-results/"
var readiness_evidence: Dictionary={}
func screen(label: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(ARESULTS+label+".png")==OK,"capture "+label)
func pick(selector: OptionButton, key: String) -> void:
	for n: int in range(selector.item_count):
		if str(selector.get_item_metadata(n))==key: selector.select(n); selector.item_selected.emit(n); return
func military(city: String,uid: String) -> Node:
	c.select_province(city); c._on_recruit_button_pressed(); await settle(); await click(c.recruitment_overlay.army_button)
	var panel: Node=c.army_overlay; pick(panel.selector,uid); await settle(); return panel
func frontline_path(source: String) -> Array:
	var queue: Array=[[source]]; var seen: Dictionary={source:true}
	while not queue.is_empty():
		var path: Array=queue.pop_front(); var city: String=path.back()
		if c.has_enemy_neighbor(city) and int(c.provinces[city].troops)>=3000 and int(c.provinces[city].food_stock)>=c.ATTACK_FOOD_COST: return path
		var neighbors: Array=c.province_connections.get(city,[]).duplicate(); neighbors.sort()
		for next: String in neighbors:
			if seen.has(next) or c.provinces[next].faction!=c.player_faction: continue
			seen[next]=true; var route: Array=path.duplicate(); route.append(next); queue.append(route)
	return []
func _run() -> void:
	create_timer(660).timeout.connect(func(): push_error("ARMY GUI TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(ARESULTS)
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await events()
	worker=c.get_city_officer_ids("geumseong")[0]
	check(c.queue_province_transfer({"source_id":"geumseong","target_id":"geumgwan","officer_ids":[worker],"troops":0},true).ok,"real officer for production chain")
	await month_step(); await task("build","smelter",0); await task("build","forge",1); await task("research","swordsmithing",1)
	c._on_city_card_production_requested("geumgwan"); var production: Node=c.production_overlay
	for n: int in [0,1]: production.recipe_selector.select(n); production.recipe_selector.item_selected.emit(n); await click(production.start_button)
	await escape()
	for n: int in range(10): await month_step()
	check(c.strategy_state.city_inventory.geumgwan.sword>=10,"ten actual recipe batches, no inventory scaling")
	var shipping: String=await ship("geumgwan","geumseong",{"sword":10},"weapons")
	check(c.queue_province_transfer({"source_id":"geumgwan","target_id":"geumseong","officer_ids":[worker],"troops":0},true).ok,"trainer actually returns to capital")
	await month_step()
	check(c.strategy_state.city_inventory.geumseong.sword>=10,"produced weapons actually arrive")
	c.select_province("geumseong"); c._on_recruit_button_pressed(); await settle()
	var before_ids: Array=Army.at_city(c.strategy_state,"geumseong")
	await click(c.recruitment_overlay.execute_button); await escape()
	var uid: String=""
	for candidate: String in Army.at_city(c.strategy_state,"geumseong"):
		if not before_ids.has(candidate): uid=candidate
	check(not uid.is_empty(),"actual UI recruitment creates stable formation")
	var panel: Node=await military("geumseong",uid)
	panel.bundles.value=10; await settle(); await screen("equipment_quote")
	var before_stock: int=c.strategy_state.city_inventory.geumseong.sword
	await click(panel.equip_button)
	check(Army.units(c.strategy_state)[uid].equipment==1000 and c.strategy_state.city_inventory.geumseong.sword==before_stock-10,"ten bundles become1000 assigned person equipment")
	pick(panel.officers,worker); await click(panel.commander_button); pick(panel.officers,worker)
	var estimate: Dictionary=Army.training_quote(c.strategy_state,c.provinces,"silla",uid,worker,c.year*12+c.month)
	await screen("training_quote"); await click(panel.train_button); await screen("training_pending"); await escape()
	var start_gold: int=c.gold; var start_month: int=c.year*12+c.month; var months: int=0
	while not Army.training_job(c.strategy_state,uid).is_empty() and months<8: await month_step(); months+=1
	check(Army.training(Army.units(c.strategy_state)[uid])>=70,"actual paid months finish training")
	panel=await military("geumseong",uid); await screen("trained"); await escape()
	readiness_evidence["training"]={"estimate":estimate,"months":months,"start_month":start_month,"end_month":c.year*12+c.month,"unit":Army.units(c.strategy_state)[uid].duplicate(true),"start_gold":start_gold,"end_gold":c.gold,"shipping":shipping}
	var path: Array=frontline_path("geumseong")
	check(not path.is_empty(),"reachable real frontline")
	for n: int in range(1,path.size()):
		panel=await military(str(path[n-1]),uid); pick(panel.officers,worker); await click(panel.commander_button)
		pick(panel.destination,str(path[n])); await click(panel.move_button); await escape(); await month_step()
		check(Army.units(c.strategy_state)[uid].location==path[n],"trained unit actually reaches "+str(path[n]))
	var source: String=str(path.back()); var target: String=""
	for neighbor: String in c.province_connections.get(source,[]):
		if c.provinces[neighbor].faction!=c.player_faction: target=neighbor; break
	panel=await military(source,uid); pick(panel.officers,worker); await click(panel.commander_button)
	var before: int=c.strategy_state.army.battles.size()
	await screen("frontline_ready"); await click(panel.attack_button)
	check(c.attack_source_id==source,"existing sortie flow armed")
	c.select_province(target); c._on_city_card_sortie_requested(target); await settle()
	check(c.strategy_state.army.battles.size()==before+1,"actual campaign battle entry resolves once")
	await events()
	panel=await military(source,uid); await screen("battle_result"); await escape()
	c._on_save_button_pressed(ARESULTS+"gui-battle.json")
	var snapshot: Variant=JSON.parse_string(JSON.stringify({"units":c.strategy_state.unit_rosters,"army":c.strategy_state.army,"gold":c.gold,"provinces":c.provinces}))
	for n: int in range(3):
		c._on_load_button_pressed(ARESULTS+"gui-battle.json"); await settle()
		check(JSON.parse_string(JSON.stringify({"units":c.strategy_state.unit_rosters,"army":c.strategy_state.army,"gold":c.gold,"provinces":c.provinces}))==snapshot,"post-battle save keeps all units/equipment/money")
	readiness_evidence["battle"]=c.strategy_state.army.battles.back(); readiness_evidence["accounts"]=c.strategy_state.faction_economy.accounts; readiness_evidence["entries"]=c.strategy_state.faction_economy.entries; readiness_evidence["army"]=c.strategy_state.army
	var f:=FileAccess.open(ARESULTS+"gui-evidence.json",FileAccess.WRITE); f.store_string(JSON.stringify(readiness_evidence,"\t")); f.close()
	print("ARMY GUI TESTS: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
