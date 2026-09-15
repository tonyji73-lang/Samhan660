extends "res://tests/project_foundation_test.gd"

const RESULTS="res://.godot/industry-results/"
var worker: String=""
var ledger: Array=[]

func screen(label: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(RESULTS+label+".png")==OK,"capture "+label)

func events() -> void:
	for n: int in range(35):
		var e: Node=c.event_presentation
		if not e.active: break
		if e.awaiting_choice():
			if e.current.steps[e.step_index].get("mode","")=="choice": await click(e.view.choice_buttons.maintain_tax)
			else: e.view.next_button.pressed.emit(); await settle()
		else: e.skip(); await settle()

func month_step() -> void:
	await events()
	var before: int=c.year*12+c.month
	await click(c.end_turn_button); await events()
	check(c.year*12+c.month==before+1,"real month advances")

func select_worker(panel: Node) -> void:
	for n: int in range(panel.officer_selector.item_count):
		if panel.officer_selector.get_item_metadata(n)==worker:
			panel.officer_selector.select(n); panel.officer_selector.item_selected.emit(n); break
	await settle()

func task(kind: String, requirement: String, recipe: int) -> void:
	c._on_city_card_production_requested("geumgwan")
	var p: Node=c.production_overlay
	p.recipe_selector.select(recipe); p.recipe_selector.item_selected.emit(recipe)
	await click(p.building_button if kind=="build" else p.research_button)
	var panel: Node=c.industry_overlay
	check(panel.visible and not p.visible and c.map_area.modal_input_locked,"existing "+kind+" opens assignment and locks map")
	await select_worker(panel)
	check(not panel.execute_button.disabled and panel.details.text.contains("월 작업량") and panel.details.text.contains("첫 월 진척"),"shared estimate and cancellation rule visible")
	await screen(requirement+"_quote")
	var gold_before: int=c.gold
	await click(panel.execute_button)
	var job: Dictionary=c.Industry.active(c.strategy_state,kind,"geumgwan","silla")
	check(not job.is_empty() and gold_before-c.gold==job.cost_paid,"UI pays original cost once "+requirement)
	await screen(requirement+"_pending")
	c._on_save_button_pressed(RESULTS+"gui-"+requirement+".json")
	c._on_load_button_pressed(RESULTS+"gui-"+requirement+".json")
	await settle()
	check(not panel.visible and not c.map_area.modal_input_locked,"pending load restores job and map input")
	var count: int=0
	while not c.Industry.active(c.strategy_state,kind,"geumgwan","silla").is_empty() and count<15:
		await month_step(); count+=1
	var completed: Dictionary=c.Industry.jobs(c.strategy_state)[job.id]
	check(completed.status=="completed","actual monthly completion "+requirement)
	ledger.append({"kind":kind,"requirement":requirement,"months":count,"cost":completed.cost_paid,"progress":completed.progress,"gold_after":c.gold,"year":c.year,"month":c.month,"officer_id":worker})
	c.open_industry("geumgwan",kind,requirement)
	check(panel.details.text.contains("완료"),"completed receipt visible")
	await screen(requirement+"_completed")
	await escape()
	check(not c.map_area.modal_input_locked,"Esc restores input")

func _run() -> void:
	create_timer(240).timeout.connect(func(): push_error("INDUSTRY GUI TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(RESULTS)
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await events()
	worker=c.get_city_officer_ids("geumseong")[0]
	check(c.queue_province_transfer({"source_id":"geumseong","target_id":"geumgwan","officer_ids":[worker],"troops":0},true).ok,"existing transfer moves real officer to unstaffed pilot city")
	await month_step()
	check(c.get_city_officer_ids("geumgwan").has(worker),"actual transfer arrival, no generated/injected officer")
	await task("build","smelter",0)
	await task("build","forge",1)
	await task("research","swordsmithing",1)
	c._on_city_card_production_requested("geumgwan")
	var p: Node=c.production_overlay
	await click(p.manager_button)
	var panel: Node=c.industry_overlay
	await select_worker(panel); await click(panel.execute_button)
	check(c.Industry.production_work(c.strategy_state,c.provinces,"geumgwan",c.year*12+c.month)>100,"real historical officer manages production")
	await screen("production_manager")
	await escape()
	c._on_city_card_production_requested("geumgwan")
	for recipe: int in [0,1]:
		p.recipe_selector.select(recipe); p.recipe_selector.item_selected.emit(recipe); await click(p.start_button)
	await screen("both_facilities_ready")
	await escape()
	var before: int=c.strategy_state.city_inventory.geumgwan.sword
	for n: int in range(3): await month_step()
	c._on_city_card_production_requested("geumgwan")
	check(c.strategy_state.city_inventory.geumgwan.sword>before and c.strategy_state.city_inventory.geumgwan.iron>=0,"native scenario chain produces actual sword inventory")
	await screen("iron_to_swords")
	ledger.append({"sword_before":before,"sword_after":c.strategy_state.city_inventory.geumgwan.sword,"iron":c.strategy_state.city_inventory.geumgwan.iron,"gold":c.gold,"facility_progress":c.strategy_state.facility_progress.geumgwan,"account":c.strategy_state.faction_economy.accounts.silla,"entries":c.strategy_state.faction_economy.entries})
	await escape(); check(not c.map_area.modal_input_locked,"production close restores map")
	var file:=FileAccess.open(RESULTS+"gui-evidence.json",FileAccess.WRITE); file.store_string(JSON.stringify(ledger,"\t")); file.close()
	print("INDUSTRY GUI TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
