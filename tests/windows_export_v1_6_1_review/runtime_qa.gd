extends "res://qa/base_qa.gd"
const Army=preload("res://army_readiness.gd")
var worker: String
var uid: String

func keyboard(code: Key, shift: bool=false) -> void:
	for down: bool in [true,false]:
		var e:=InputEventKey.new(); e.keycode=code; e.shift_pressed=shift; e.pressed=down; root.push_input(e,true)
	await settle()

func panel_capture(label: String) -> void:
	await capture(label+"-"+str(root.size.y))

func military_visuals() -> void:
	var previous: Dictionary=snapshot()
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await settle()
		c._on_city_card_production_requested("geumseong"); var p: Node=c.production_overlay
		await panel_capture("supply")
		check(p.local_stock.text.length()>0 and p.arrivals.text.length()>0,"export local stocks and incoming model")
		p.start_button.grab_focus(); await keyboard(KEY_TAB)
		check(root.gui_get_focus_owner()!=null and p.is_ancestor_of(root.gui_get_focus_owner()),"supply Tab in dialog")
		p.scroll_container.scroll_vertical=10000; await settle(); await panel_capture("supply-scroll")
		await keyboard(KEY_ESCAPE); check(not c.settlement_overlay.busy(),"supply Esc returns to settlement")
		c.open_army("geumseong"); var a: Node=c.army_overlay
		for mode: String in ["formation","training"]:
			a.show_mode(mode); await settle()
			await panel_capture(mode)
			check(a.unit_list.get_child_count()>0,"unit list visible "+mode)
			var focus_button: Button=a.close_button
			focus_button.grab_focus(); await keyboard(KEY_TAB)
			check(root.gui_get_focus_owner()!=focus_button and a.is_ancestor_of(root.gui_get_focus_owner()),"military Tab wraps "+mode)
			await keyboard(KEY_TAB,true); check(root.gui_get_focus_owner()==focus_button,"military Shift Tab reverse "+mode)
		if not a.candidate_buttons.is_empty():
			var card: Button=a.candidate_buttons[0]; var candidate_id: String=str(card.get_meta("officer_id")); card.grab_focus(); await keyboard(KEY_SPACE)
			check(a.officer()==candidate_id,"keyboard candidate selection")
			a.cancel_selection.grab_focus(); await keyboard(KEY_SPACE)
			check(snapshot()==previous and a.officer()==a.selection_before,"keyboard cancel restores selection without campaign mutation")
		await keyboard(KEY_ESCAPE); check(not c.settlement_overlay.busy(),"military Esc restores settlement")
	check(snapshot()==previous,"all export screen previews leave state unchanged")
	root.size=Vector2i(1280,720)

func new_campaign() -> void:
	await click(get_tree().current_scene.new_game_button); await get_tree().create_timer(3).timeout
	var setup: Node=get_tree().current_scene
	await click(setup.faction_view._focus_controls["scenario:silla_equilibrium_632"])
	await click(setup.faction_view._focus_controls["faction:silla"])
	await click(setup.faction_view._focus_controls.start)
	await get_tree().create_timer(3).timeout; c=get_tree().current_scene; await events()
	check(c.year==632 and c.player_faction_id=="silla","normal new 632 Silla campaign")

func prepare() -> void:
	await new_campaign(); await military_visuals()
	worker=c.get_city_officer_ids("geumseong")[0]
	check(c.queue_province_transfer({"source_id":"geumseong","target_id":"geumgwan","officer_ids":[worker],"troops":0},true).ok,"normal worker transfer")
	await month()
	for task: Array in [["build","smelter"],["build","forge"],["research","swordsmithing"]]:
		await accept("geumgwan",task[0],task[1],worker); await wait_job(task[0],"geumgwan")
	c._on_city_card_production_requested("geumgwan"); var p: Node=c.production_overlay
	for n: int in [0,1]:
		p.recipe_selector.select(n); p.recipe_selector.item_selected.emit(n); await click(p.start_button)
		check(c.strategy_state.city_production.geumgwan[p.selected_recipe_id].enabled,"normal production reservation")
	await key(KEY_ESCAPE)
	for n: int in range(10): await month()
	check(c.strategy_state.city_inventory.geumgwan.sword>=10,"normal production creates actual weapons")
	c.select_province("geumgwan"); c._on_transfer_button_pressed(); await settle(); await click(c.transfer_panel.cargo_button)
	var supply: Node=c.supply_overlay; pick(supply.destination,"geumseong"); supply.amounts.sword.value=10; await settle()
	check(not supply.execute_button.disabled,"normal cargo quote available"); await click(supply.execute_button)
	check(not supply.selected_order().is_empty(),"normal cargo dispatched"); await key(KEY_ESCAPE)
	check(c.queue_province_transfer({"source_id":"geumgwan","target_id":"geumseong","officer_ids":[worker],"troops":0},true).ok,"trainer returns normally")
	await month(); check(c.strategy_state.city_inventory.geumseong.sword>=10,"local cargo arrives")
	c.select_province("geumseong"); c._on_recruit_button_pressed(); await settle()
	var before_ids: Array=Army.at_city(c.strategy_state,"geumseong")
	await click(c.recruitment_overlay.execute_button); await key(KEY_ESCAPE)
	for value: String in Army.at_city(c.strategy_state,"geumseong"):
		if not before_ids.has(value): uid=value
	check(not uid.is_empty(),"normal recruitment creates unit")
	c.open_army("geumseong"); var a: Node=c.army_overlay; a.rebuild(uid); a.show_mode("formation"); a.bundles.value=10
	var before: Dictionary=snapshot(); var stock: int=c.strategy_state.city_inventory.geumseong.sword
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await panel_capture("equipment-preview")
		check(snapshot()==before,"equipment preview pure")
	a.equip_button.grab_focus(); await keyboard(KEY_SPACE)
	check(Army.units(c.strategy_state)[uid].equipment==1000 and c.strategy_state.city_inventory.geumseong.sword==stock-10,"keyboard issue exact 10 bundles / 1000 equipment")
	a.show_mode("training"); a.select_officer(worker); await settle(); a.commander_button.grab_focus(); await keyboard(KEY_SPACE); a.select_officer(worker)
	check(Army.units(c.strategy_state)[uid].commander_id==worker,"keyboard commander appointment")
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await panel_capture("training-quote")
	a.train_button.grab_focus(); await keyboard(KEY_SPACE)
	check(not Army.training_job(c.strategy_state,uid).is_empty(),"keyboard training accepted")
	await key(KEY_ESCAPE); await month()
	var job: Dictionary=Army.training_job(c.strategy_state,uid)
	check(not job.is_empty() and job.cost_paid>0 and Army.training(Army.units(c.strategy_state)[uid])>50,"paid training in progress before save")
	c.open_army("geumseong"); a.rebuild(uid); a.show_mode("training"); await panel_capture("training-pending"); await key(KEY_ESCAPE)
	slot="user://windows_export_v1_6_1_"+str(int(Time.get_unix_time_from_system()))+".json"
	check(not FileAccess.file_exists(slot),"unique slot does not overwrite existing saves")
	check(c._on_save_button_pressed(slot),"default user path pending save")
	var f:=FileAccess.open(out.path_join("restart.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"slot":slot,"uid":uid,"worker":worker,"job_id":job.id,"snapshot":snapshot()},"\t")); f.close()
	evidence={"unit":Army.units(c.strategy_state)[uid],"job":job,"stock":c.strategy_state.city_inventory.geumseong,"gold":c.gold}
	finish()

func reload_campaign() -> Dictionary:
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("restart.json")))
	slot=receipt.slot; uid=receipt.uid; worker=receipt.worker
	get_tree().current_scene._load_selected_game(slot)
	await get_tree().create_timer(3).timeout; c=get_tree().current_scene; await settle()
	check(snapshot()==receipt.snapshot,"new process restores exact troops equipment stock gold officer progress")
	return receipt

func reload_test() -> void:
	var receipt: Dictionary=await reload_campaign()
	for n: int in range(2):
		c._on_load_button_pressed(slot); await settle()
		check(snapshot()==receipt.snapshot,"repeat load has no duplicate payment or issue")
	c.open_army("geumseong"); var a: Node=c.army_overlay; a.rebuild(uid); a.show_mode("training"); await panel_capture("training-restored")
	check(a.unit_summary.text.contains("병력 1000명") and not a.unit_summary.text.contains("1000.0명"),"loaded troop summary uses integer display")
	await key(KEY_ESCAPE)
	var months:=0
	while not Army.training_job(c.strategy_state,uid).is_empty() and months<8: await month(); months+=1
	check(Army.training(Army.units(c.strategy_state)[uid])>=70,"restored training completes via real month")
	var completed: Dictionary=Army.Domestic.ensure(c.strategy_state).jobs[receipt.job_id].duplicate(true)
	check(completed.status=="completed" and completed.cost_paid==100,"normal training final cost 100 once")
	var unit: Dictionary=Army.units(c.strategy_state)[uid].duplicate(true)
	await month()
	check(Army.units(c.strategy_state)[uid]==unit and Army.Domestic.ensure(c.strategy_state).jobs[receipt.job_id]==completed,"extra month does not repeat training or equipment")
	c.open_army("geumseong"); a.rebuild(uid); a.show_mode("training")
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await panel_capture("training-complete"); check(a.train_button.disabled,"completed readiness button refreshed")
	evidence={"unit":unit,"job":completed,"months_after_reload":months,"gold":c.gold,"stock":c.strategy_state.city_inventory.geumseong}
	finish()

func dpi_hold() -> void:
	await reload_campaign()
	root.size=Vector2i(1280,720); c.open_army("geumseong"); var a: Node=c.army_overlay; a.rebuild(uid); a.show_mode("formation"); await settle()
	while true:
		var controls: Dictionary={}
		for name: String in ["formation","training"]:
			var b: Control=a.mode_buttons[name]; var r: Rect2=b.get_global_rect()
			controls[name]={"x":r.get_center().x/root.size.x,"y":r.get_center().y/root.size.y}
		var file:=FileAccess.open(out.path_join("dpi-live.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"size":[root.size.x,root.size.y],"controls":controls,"mode":a.mode,"army_visible":a.visible,"production_visible":c.production_overlay.visible,"gold":c.gold},"\t")); file.close()
		await get_tree().create_timer(0.5).timeout

func run() -> void:
	await get_tree().create_timer(3).timeout; resources()
	check(ResourceLoader.exists("res://ui/living_city_v1/military_style.gd"),"V1.6 shared military style packed")
	if phase=="prepare": await prepare()
	elif phase=="reload": await reload_test()
	elif phase=="dpi": await dpi_hold()
