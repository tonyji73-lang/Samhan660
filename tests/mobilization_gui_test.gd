extends "res://tests/industry_assignment_gui_test.gd"
const Army=preload("res://army_readiness.gd")
const Mob=preload("res://mobilization.gd")
const DIR="res://.godot/mobilization-results/"
var nation: String
var home_city: String
var proofs: Array=[]
func screen(label: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(DIR+nation+"-"+label+".png")==OK,"capture "+nation+label)
func pick(selector: OptionButton, key: String) -> void:
	for n: int in range(selector.item_count):
		if str(selector.get_item_metadata(n))==key: selector.select(n); selector.item_selected.emit(n); return
func task(kind: String, requirement: String, recipe: int) -> void:
	c._on_city_card_production_requested(home_city)
	var p: Node=c.production_overlay; p.recipe_selector.select(recipe); p.recipe_selector.item_selected.emit(recipe)
	await click(p.building_button if kind=="build" else p.research_button)
	var panel: Node=c.industry_overlay
	await select_worker(panel)
	check(panel.visible and not panel.execute_button.disabled,"real eligible "+nation+requirement)
	await click(panel.execute_button)
	var job: Dictionary=c.Industry.active(c.strategy_state,kind,home_city,nation)
	check(not job.is_empty(),"paid infrastructure "+requirement)
	if job.is_empty(): quit(1); return
	await escape()
	var n: int=0
	while not c.Industry.active(c.strategy_state,kind,home_city,nation).is_empty() and n<20: await month_step(); n+=1
	proofs.append({"nation":nation,"kind":kind,"requirement":requirement,"months":n,"cost":job.cost_paid})
func _run() -> void:
	create_timer(900).timeout.connect(func(): push_error("MOBILIZATION GUI TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(DIR)
	for f: String in ["silla","baekje","goguryeo"]:
		nation=f; home_city={"silla":"geumseong","baekje":"sabi","goguryeo":"pyongyang"}[f]
		root.set_meta("new_game_settings",{"faction":f,"play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
		change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await events()
		worker=c.get_city_officer_ids(home_city)[0]
		var start_stamp: int=c.year*12+c.month
		await task("build","smelter",2)
		if int(c.strategy_state.faction_research[c.player_faction].basic_smelting)<1: await task("research","basic_smelting",2)
		await task("build","forge",1); await task("research","swordsmithing",1)
		c._on_city_card_production_requested(home_city)
		var p: Node=c.production_overlay
		for recipe: int in [2,1]: p.recipe_selector.select(recipe); p.recipe_selector.item_selected.emit(recipe); await click(p.start_button)
		await screen("common-iron-quote"); await escape()
		for n: int in range(10): await month_step()
		check(int(c.strategy_state.city_inventory[home_city].sword)==10,"normal common iron to ten swords "+f)
		c._on_city_card_production_requested(home_city); await screen("weapons-produced")
		for recipe: int in [2,1]: p.recipe_selector.select(recipe); p.recipe_selector.item_selected.emit(recipe); await click(p.stop_button)
		await escape()
		c.select_province(home_city); c._on_recruit_button_pressed(); await settle()
		var q: Dictionary=c.get_recruitment_quote(home_city,1000)
		check(q.ok,"native population eligible1000 "+f); await screen("recruit-quote")
		var population: int=c.provinces[home_city].population
		var ids: Array=Army.at_city(c.strategy_state,home_city)
		await click(c.recruitment_overlay.execute_button); await screen("recruited")
		check(int(c.provinces[home_city].population)==population-1000,"actual GUI civilian debit "+f)
		var uid: String=""
		for candidate: String in Army.at_city(c.strategy_state,home_city):
			if not ids.has(candidate): uid=candidate
		await click(c.recruitment_overlay.army_button)
		var army: Node=c.army_overlay; pick(army.selector,uid)
		await click(army.equip_button); pick(army.officers,worker); await click(army.train_button)
		check(c.strategy_state.unit_rosters[uid].equipment==1000 and c.strategy_state.city_inventory[home_city].sword==0,"ten actual bundles consumed "+f)
		await screen("equipped-training"); await escape()
		var train_months: int=0; var gold_before: int=c.gold
		while not Army.training_job(c.strategy_state,uid).is_empty() and train_months<8: await month_step(); train_months+=1
		check(Army.training(c.strategy_state.unit_rosters[uid])==70,"real completed training "+f)
		c.select_province(home_city); c._on_recruit_button_pressed(); await click(c.recruitment_overlay.army_button); pick(army.selector,uid)
		await screen("trained"); check(army.destination.item_count>0,"friendly transfer destination "+f)
		var target: String=str(army.destination.get_item_metadata(0)); army.destination.select(0)
		await click(army.move_button); await escape(); await month_step()
		check(c.strategy_state.unit_rosters[uid].location==target and Mob.serving(c.strategy_state,home_city)>=1000,"origin retained on actual transfer")
		c.select_province(target); c._on_recruit_button_pressed(); await click(c.recruitment_overlay.army_button); pick(army.selector,uid); army.amount.value=333
		var targetpop: int=c.provinces[target].population; var soldierbefore: int=c.provinces[target].troops
		await screen("disband-quote"); await click(army.disband_button); await screen("disbanded")
		check(c.provinces[target].population==targetpop+333 and c.provinces[target].troops==soldierbefore-333 and c.strategy_state.unit_rosters[uid].troops==667,"GUI partial discharge exact destination population")
		await escape()
		var saved: String=DIR+f+"-final.json"; c._on_save_button_pressed(saved)
		var before: Dictionary=JSON.parse_string(JSON.stringify({"u":c.strategy_state.unit_rosters,"p":c.provinces,"a":c.strategy_state.faction_economy.accounts}))
		for n: int in range(3):
			c._on_load_button_pressed(saved); await settle()
			check(JSON.parse_string(JSON.stringify({"u":c.strategy_state.unit_rosters,"p":c.provinces,"a":c.strategy_state.faction_economy.accounts}))==before,"native repeated load "+f)
		proofs.append({"nation":f,"start_stamp":start_stamp,"end_stamp":c.year*12+c.month,"quote":q,"training_months":train_months,"training_cost":50*train_months,"unit":c.strategy_state.unit_rosters[uid],"account":c.strategy_state.faction_economy.accounts[f],"transactions":c.strategy_state.faction_economy.entries,"disband_target":target,"population_before":targetpop,"population_after":c.provinces[target].population})
	var file:=FileAccess.open(DIR+"gui-evidence.json",FileAccess.WRITE); file.store_string(JSON.stringify(proofs,"\t")); file.close()
	print("MOBILIZATION GUI TESTS: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
