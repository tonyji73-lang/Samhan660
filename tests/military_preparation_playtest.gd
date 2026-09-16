extends "res://tests/silla_642_gameplay_loop.gd"

const PREP_DIR="res://.godot/military-preparation/"

func screen(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(PREP_DIR+label+".png")==OK,"GUI "+label)

func save_slot(label: String) -> Dictionary:
	var slot: String="user://military_preparation_%s_%d_%d.json" % [label,int(Time.get_unix_time_from_system()),OS.get_process_id()]
	check(not FileAccess.file_exists(slot) and c._on_save_button_pressed(slot),"unique host slot "+label)
	return {"slot":slot,"state":full_state()}

func press(button: Button) -> void:
	if c.production_overlay.visible and c.production_overlay.scroll_container.is_ancestor_of(button):
		await process_frame; await process_frame
		c.production_overlay.scroll_container.ensure_control_visible(button); await process_frame; await process_frame
	await super.press(button)

func army() -> void:
	var before: Dictionary=full_state()
	c.open_army("geumseong"); select_value(c.army_overlay.selector,unit_id)
	check(full_state()==before,"opening guide never charges or assigns")

func round_trip(kind: String, esc: bool=false) -> void:
	var before: Dictionary=full_state()
	await press(c.army_overlay.preparation_buttons[kind])
	var ui: Node=c.production_overlay if kind=="production" else c.industry_overlay
	check(ui.visible and not c.army_overlay.visible and c.map_area.modal_input_locked,"shortcut switches one modal "+kind)
	await screen("browse-"+kind)
	if esc:
		for down: bool in [true,false]:
			var e:=InputEventKey.new(); e.keycode=KEY_ESCAPE; e.pressed=down; root.push_input(e,true)
		await process_frame
	else: await press(ui.preparation_back)
	check(c.army_overlay.visible and c.army_overlay.id()==unit_id and c.army_overlay.city=="geumseong","return keeps selected city and unit "+kind)
	check(full_state()==before,"read-only shortcut and return "+kind)

func start_job(kind: String, worker: String) -> void:
	await press(c.army_overlay.preparation_buttons[kind])
	var ui: Node=c.industry_overlay
	select_value(ui.officer_selector,worker)
	var before: int=c.gold
	await press(ui.execute_button)
	var job: Dictionary=ui.job()
	check(not job.is_empty() and before-c.gold==job.cost_paid,"GUI job pays common quote "+kind)
	actions.append({"month":stamp(),"job":job.duplicate(true)})
	await press(ui.preparation_back)
	check(c.army_overlay.id()==unit_id,"job return keeps unit")

func finish() -> void:
	var out:=FileAccess.open(PREP_DIR+"normal.json",FileAccess.WRITE)
	out.store_string(JSON.stringify({"pid":OS.get_process_id(),"unit_id":unit_id,"elapsed":stamp()-initial_stamp,"checkpoints":checkpoints,"actions":actions,"months":months,"events":occurrences,"checks":checks,"failures":failures},"\t")); out.close()
	print("MILITARY PREPARATION GUI: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)

func _run() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(PREP_DIR)
	seed(64220260918)
	await start(Scenarios.SCENARIOS[1],"silla","historical"); await settle_events()
	initial_stamp=stamp(); unit_id=c.Army.at_city(c.strategy_state,"geumseong","silla")[0]
	army(); await round_trip("production"); await round_trip("build",true); await round_trip("research")
	check(not c.army_overlay.preparation_model.parallel,"oversized original unit cannot claim parallel training")
	await start_job("build","historical:001"); await start_job("research","historical:003")
	for n: int in range(10):
		c.army_overlay.hide(); await next_month("facilities and research"); army()
		if n==4: await start_job("build","historical:001")
	check(c.strategy_state.province_buildings.geumseong.forge==1,"normal facilities ready in ten months")
	await press(c.army_overlay.preparation_buttons.production)
	await press(c.production_overlay.manager_button)
	select_value(c.industry_overlay.officer_selector,"historical:003"); await press(c.industry_overlay.execute_button)
	await press(c.industry_overlay.preparation_back)
	check(c.army_overlay.id()==unit_id,"nested production to manager returns original unit")
	await press(c.army_overlay.preparation_buttons.production)
	for recipe: String in ["iron_procurement","iron_sword"]:
		select_value(c.production_overlay.recipe_selector,recipe); await press(c.production_overlay.start_button)
		check(c.strategy_state.city_production.geumseong[recipe].enabled,"actual GUI recipe order enabled "+recipe)
	await press(c.production_overlay.preparation_back); c.army_overlay.hide()
	var old: Array=c.Army.units(c.strategy_state).keys()
	c._on_city_card_recruit_requested("geumseong"); var before: int=c.gold
	await press(c.recruitment_overlay.execute_button)
	check(c.gold==before-150,"paid recruitment1000")
	for uid: String in c.Army.units(c.strategy_state):
		if not old.has(uid): unit_id=uid
	await press(c.recruitment_overlay.army_button); select_value(c.army_overlay.selector,unit_id)
	select_value(c.army_overlay.officers,"historical:003")
	check(not c.army_overlay.preparation_model.parallel and not c.army_overlay.preparation_model.training.ok,"busy production manager cannot also train")
	select_value(c.army_overlay.officers,"historical:004")
	check(c.army_overlay.preparation_model.parallel,"separate eligible trainer and paid production can run together")
	await screen("parallel-available")
	await round_trip("production",true)
	check(c.army_overlay.officer()=="historical:004","return preserves chosen trainer")
	await press(c.army_overlay.train_button); await screen("parallel-started")
	for n: int in range(12):
		c.army_overlay.hide(); await next_month("paid production plus training"); army()
		if n==0: checkpoints.progress=save_slot("progress"); await screen("parallel-month1")
		if n==1:
			check(c.Army.training(c.Army.units(c.strategy_state)[unit_id])==70 and c.strategy_state.city_inventory.geumseong.sword>0,"training finished while production accumulated weapons")
			await screen("training-complete")
		if c.strategy_state.city_inventory.geumseong.sword>=10: break
	check(stamp()-initial_stamp==17,"parallel normal path finishes at month17")
	await press(c.army_overlay.equip_button)
	check(c.Army.units(c.strategy_state)[unit_id].equipment==1000 and c.Army.training(c.Army.units(c.strategy_state)[unit_id])==70,"same recruited unit fully equipped and trained")
	check(c.army_overlay.preparation.text.contains("장비·훈련 준비 완료"),"guide refreshes to ready after actual issue")
	await screen("ready"); await round_trip("build"); await round_trip("research",true)
	await press(c.army_overlay.close_button)
	check(not c.map_area.modal_input_locked,"final Close restores map input")
	checkpoints.ready=save_slot("ready")
	finish()
