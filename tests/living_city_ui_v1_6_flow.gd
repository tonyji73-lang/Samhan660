extends "res://tests/army_readiness_gui_test.gd"
const REVIEW="res://tests/living_city_v1_6_review/flow/"

func screen(label: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(REVIEW+str(root.size.y)+"_"+label+".png")==OK,"capture "+label)

func month_step() -> void:
	await events()
	if c.merit_overlay.visible: await escape()
	var before: int=c.year*12+c.month
	await click(c.settlement_overlay.buttons.month); await events()
	if c.merit_overlay.visible: await escape()
	check(c.year*12+c.month==before+1,"real month advances")

func click(control: Control) -> void:
	if c!=null and c.army_overlay!=null:
		var a: Node=c.army_overlay
		if control in [a.train_button,a.commander_button,a.stop_button]: a.show_mode("training")
		elif control in [a.equip_button,a.split_button,a.merge_button,a.disband_button,a.move_button,a.attack_button]: a.show_mode("formation")
	await super.click(control)

func key(code: Key, shift: bool=false) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.shift_pressed=shift; event.pressed=down; root.push_input(event,true)
	await settle()

func _run() -> void:
	create_timer(660).timeout.connect(func(): push_error("V1.6 FLOW TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(REVIEW)
	DirAccess.make_dir_recursive_absolute("res://.godot/industry-results/")
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await events()
	worker=c.get_city_officer_ids("geumseong")[0]
	check(c.queue_province_transfer({"source_id":"geumseong","target_id":"geumgwan","officer_ids":[worker],"troops":0},true).ok,"normal officer transfer")
	await month_step(); await task("build","smelter",0); await task("build","forge",1); await task("research","swordsmithing",1)
	c._on_city_card_production_requested("geumgwan"); var production: Node=c.production_overlay
	for n: int in [0,1]: production.recipe_selector.select(n); production.recipe_selector.item_selected.emit(n); await click(production.start_button)
	await escape()
	for n: int in range(10): await month_step()
	check(c.strategy_state.city_inventory.geumgwan.sword>=10,"normal production made 10 bundles")
	var shipping: String=await ship("geumgwan","geumseong",{"sword":10},"weapons")
	c._on_city_card_production_requested("geumseong")
	check(c.production_overlay.arrivals.text.contains("무기 10") and int(c.strategy_state.city_inventory.geumseong.sword)==0,"incoming equipment excluded from local stock")
	await screen("supply_incoming"); await escape()
	check(c.queue_province_transfer({"source_id":"geumgwan","target_id":"geumseong","officer_ids":[worker],"troops":0},true).ok,"trainer returns normally")
	await month_step()
	check(c.strategy_state.city_inventory.geumseong.sword>=10,"actual shipment arrived")
	c.select_province("geumseong"); c._on_recruit_button_pressed(); await settle()
	var before_ids: Array=Army.at_city(c.strategy_state,"geumseong")
	await click(c.recruitment_overlay.execute_button); await escape()
	var uid: String=""
	for value: String in Army.at_city(c.strategy_state,"geumseong"):
		if not before_ids.has(value): uid=value
	check(not uid.is_empty(),"normal recruitment made unequipped 1000-person unit")
	c.open_army("geumseong"); var a: Node=c.army_overlay; a.rebuild(uid); a.show_mode("formation"); a.bundles.value=10
	var before_stock: int=c.strategy_state.city_inventory.geumseong.sword
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await settle(); await screen("equipment_preview")
		check(a.equip_summary.text.contains("0 → 1000명분"),"quote previews equipment delta "+str(resolution))
		check(c.strategy_state.city_inventory.geumseong.sword==before_stock and Army.units(c.strategy_state)[uid].equipment==0,"preview does not issue equipment")
	a.equip_button.grab_focus(); await key(KEY_SPACE)
	check(Army.units(c.strategy_state)[uid].equipment==1000 and c.strategy_state.city_inventory.geumseong.sword==before_stock-10,"keyboard confirms exact existing equipment quote")
	a.show_mode("training"); a.select_officer(worker); await settle()
	var original: String=a.officer(); var stock_snapshot: Dictionary=state()
	for b: Button in a.candidate_buttons:
		if str(b.get_meta("officer_id"))!=original: await click(b); break
	await click(a.cancel_selection)
	check(state()==stock_snapshot,"candidate selection/cancel changes no game state")
	a.select_officer(worker); a.commander_button.grab_focus(); await key(KEY_SPACE); a.select_officer(worker)
	check(Army.units(c.strategy_state)[uid].commander_id==worker,"keyboard commander appointment")
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await settle(); a.train_button.grab_focus(); await key(KEY_TAB); var focus: Control=root.gui_get_focus_owner()
		check(focus!=null and a.is_ancestor_of(focus),"Tab stays in military dialog")
		await key(KEY_TAB,true); check(root.gui_get_focus_owner()==a.train_button,"Shift Tab returns to training confirmation")
		await screen("training_quote")
	var estimate: Dictionary=Army.training_quote(c.strategy_state,c.provinces,"silla",uid,worker,c.year*12+c.month)
	a.train_button.grab_focus(); await key(KEY_SPACE)
	check(not Army.training_job(c.strategy_state,uid).is_empty(),"keyboard training accepted")
	await screen("training_pending"); await escape(); check(not a.visible,"training Esc closes")
	var months: int=0
	while not Army.training_job(c.strategy_state,uid).is_empty() and months<8: await month_step(); months+=1
	check(Army.training(Army.units(c.strategy_state)[uid])>=70,"paid monthly training completes")
	c.open_army("geumseong"); a.rebuild(uid); a.show_mode("training")
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await screen("training_complete")
		check(a.training_summary.text.contains("훈련 완료") and a.train_button.disabled,"readiness refreshed after month processing")
	var f:=FileAccess.open(REVIEW+"result.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"estimate":estimate,"months":months,"shipping":shipping,"unit":Army.units(c.strategy_state)[uid],"stock":c.strategy_state.city_inventory.geumseong,"date":[c.year,c.month]},"\t")); f.close()
	print("V1.6 NORMAL FLOW: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)

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
	check(not panel.visible and not c.settlement_overlay.busy(),"pending load restores job and settlement input")
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
	check(not c.settlement_overlay.busy(),"Esc restores settlement input")


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
	await escape(); check(not c.settlement_overlay.busy(),"cargo Esc restores settlement input")
	return str(order.id)

