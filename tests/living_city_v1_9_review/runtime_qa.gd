extends "base_qa.gd"
const Planning=preload("res://ai_military_planning.gd")
const Scenarios=preload("res://scenario_data.gd")
var trace: Array=[]
func map_ready() -> bool:
	return (not c.settlement_overlay.busy() and not c.settlement_overlay.map.input_locked) if c.settlement_overlay.visible else not c.map_area.modal_input_locked
func snapshot() -> Dictionary:
	var value: Dictionary=super.snapshot(); value.orders=JSON.parse_string(JSON.stringify(c.pending_transfer_orders)); return value
func write_json(name: String,value: Variant) -> void:
	var f:=FileAccess.open(out.path_join(name),FileAccess.WRITE); f.store_string(JSON.stringify(value,"\t")); f.close()
func pair(label: String) -> void:
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]: root.size=size; await capture(label+"-"+str(size.y))
func settle_events() -> void:
	for n: int in range(50):
		var p: Node=c.event_presentation
		if not p.active: break
		if p.awaiting_choice() and p.current.steps[p.step_index].get("mode","")=="choice": p._choose("reject" if p.view.choice_buttons.has("reject") else "maintain_tax")
		elif p.awaiting_choice(): p.next()
		else: p.skip()
		await get_tree().process_frame
	await settle()
func choose_battle(win: bool) -> Dictionary:
	for step: int in range(24):
		var options: Array=[]
		for source: String in Planning.owned(c,"silla"):
			if not c.validate_attack_staff(source).ok or c.get_city_officer_ids(source).is_empty(): continue
			var strength: float=c.Army.power(c.strategy_state,c.Army.attack_units(c.strategy_state,source,"silla"))*(1+float(c.get_best_commander(source,"attack").leadership)/100.0)
			for target: String in c.province_connections.get(source,[]):
				if c.Economy.resolve(c.strategy_state,c.provinces[target].faction)=="silla": continue
				var defense: float=c.Army.power(c.strategy_state,c.Army.at_city(c.strategy_state,target))*(1+float(c.get_best_commander(target).leadership)/100.0+float(c.provinces[target].fortress)/200.0)
				if c.get_sortie_quote(source,target).ok: options.append({"source":source,"target":target,"ratio":strength/maxf(1,defense)})
		options.sort_custom(func(a,b): return a.source+a.target<b.source+b.target if is_equal_approx(a.ratio,b.ratio) else (a.ratio>b.ratio if win else a.ratio<b.ratio))
		if options.is_empty(): return {}
		var best: Dictionary=options[0]
		if (win and best.ratio>1.05) or (not win and best.ratio<0.95):
			var officer: String=c.get_best_commander(best.source,"attack").get("officer_id","")
			var ids: Array=c.Army.attack_units(c.strategy_state,best.source,"silla")
			check(c.Noble.appoint(c,"silla","commander",ids[0],officer).ok,"normal commander appointment")
			trace.append(best); return best
		for source: String in Planning.owned(c,"silla"):
			if source==best.source: continue
			var path: Array=Planning.military_route(c,"silla",source,best.source)
			var amount: int=maxi(0,c.Army.count(c.strategy_state,c.Army.at_city(c.strategy_state,source,"silla",true))-3000)
			if path.size()>1 and amount>=100: trace.append(c.queue_province_transfer({"source_id":source,"target_id":path[1],"troops":amount,"officer_ids":[]},false,"silla"))
		c._on_end_turn_button_pressed(); await settle_events()
	return {}
func start_campaign() -> void:
	seed(64220260917)
	var s: Dictionary=Scenarios.SCENARIOS[1]
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":s.id,"scenario_year":s.year,"scenario_season":s.season})
	get_tree().change_scene_to_file("res://campaign_main.tscn"); await get_tree().create_timer(2).timeout; c=get_tree().current_scene; c.event_presentation.display_level="minimal"; await settle_events()
func battle_case(win: bool) -> void:
	await start_campaign(); var chosen: Dictionary=await choose_battle(win)
	check(not chosen.is_empty(),"normal commands find requested battle outcome")
	if chosen.is_empty(): finish(1); return
	c.select_province(chosen.source); c._on_attack_button_pressed(); c.select_province(chosen.target); c._on_attack_button_pressed(); await settle()
	var p: Node=c.sortie_overlay
	check(p.visible and c.map_area.modal_input_locked,"actual attack opens confirmation and locks map")
	var before: Dictionary=snapshot(); await pair(phase+"-sortie")
	for id: String in p.unit_buttons.keys(): p.unit_buttons[id].pressed.emit(); await settle()
	for n: int in range(p.targets.item_count): p.targets.select(n); p.targets.item_selected.emit(n); await settle()
	check(snapshot()==before,"target and unit previews preserve all game state")
	# Explicit insufficient-food fixture; restore before the normal battle.
	var actual_food: int=c.provinces[chosen.source].food_stock
	c.provinces[chosen.source].food_stock=0; p.refresh(); check(p.execute_button.disabled and not p.reason.text.is_empty(),"existing food validator blocks confirmation with reason")
	var blocked_state: Dictionary=snapshot(); p.confirm(); check(snapshot()==blocked_state,"blocked confirmation changes no ledger")
	c.provinces[chosen.source].food_stock=actual_food; p.refresh()
	c._on_end_turn_button_pressed(); check(snapshot()==before,"sortie blocks monthly processing")
	await key(KEY_ESCAPE); check(not p.visible and map_ready() and snapshot()==before,"Esc cancel preserves resources and restores active map")
	c.attack_source_id=chosen.source; c.select_province(chosen.target); c._on_attack_button_pressed(); await settle()
	var food_before: int=c.provinces[chosen.source].food_stock; var count: int=c.strategy_state.army.battles.size()
	var total_before: int=c.Army.count(c.strategy_state,c.Army.units(c.strategy_state).keys())
	p.execute_button.grab_focus(); await key(KEY_SPACE); await settle_events()
	check(c.strategy_state.army.battles.size()==count+1,"Space confirmation records exactly one battle")
	p.confirm(); check(c.strategy_state.army.battles.size()==count+1,"duplicate confirmation cannot repeat combat")
	var row: Dictionary=c.strategy_state.army.battles.back()
	check(row.won==win,"normal battle produces requested victory or defeat")
	check(c.provinces[chosen.source].food_stock==food_before-c.ATTACK_FOOD_COST,"local food charged exactly once")
	check(c.merit_overlay.visible,"existing battle presentation opens results")
	var result: Node=c.merit_overlay; await pair(phase+"-result")
	for side: String in ["attacker","defender"]:
		var total:=0
		for u: Dictionary in row[side+"_state"]: total+=int(u.troops)
		check(total==int(row[side+"_troops"]),"before troops match snapshot "+side)
	var losses:=0
	for h: Dictionary in c.strategy_state.army.history:
		if h.action=="casualties" and int(h.month)==int(row.month) and (row.attack_units+row.defend_units).has(h.unit_id): losses+=int(h.troops)
	check(losses==int(row.attacker_losses)+int(row.defender_losses),"battle losses exactly match casualty ledger")
	check(total_before-c.Army.count(c.strategy_state,c.Army.units(c.strategy_state).keys())==losses,"global troop delta exactly matches battle losses")
	check(c.Economy.resolve(c.strategy_state,c.provinces[row.target].faction)==(row.attacker_faction if win else row.defender_faction),"actual city ownership matches result")
	var state: Dictionary=snapshot(); result.refresh(); c.open_battle_merit(row.battle_id); check(snapshot()==state,"reopening result does not repeat casualties or ownership")
	result.close_button.grab_focus(); await key(KEY_TAB); check(result.is_ancestor_of(root.gui_get_focus_owner()),"result Tab stays inside modal")
	for down: bool in [true,false]:
		var e:=InputEventKey.new(); e.keycode=KEY_TAB; e.shift_pressed=true; e.pressed=down; root.push_input(e,true)
	await settle(); check(root.gui_get_focus_owner()==result.close_button,"Shift Tab reverses modal focus")
	result.overview.get_parent().scroll_vertical=10000; await settle(); check(result.overview.get_parent().scroll_vertical>0,"result detail scrolls internally")
	await capture(phase+"-detail-scroll")
	await key(KEY_ESCAPE); check(not result.visible and map_ready(),"result Esc restores active map input")
	var debug: Dictionary={"result":result.visible,"map_locked":c.map_area.modal_input_locked}
	for prop: String in ["settlement_overlay","sortie_overlay","politics_overlay","power_dialog","playability_dialog","invasion_overlay","army_overlay","recruitment_overlay","ending_load_dialog","ending_save_dialog"]: debug[prop]=c.get(prop).visible
	write_json(phase+"-modal.json",debug)
	c.open_battle_merit(row.battle_id)
	for n: int in range(result.recovery.get_child_count()):
		result.recovery.get_child(n).pressed.emit(); await settle(); check(c.army_overlay.visible or c.recruitment_overlay.visible,"postbattle link opens existing recovery screen")
		if c.army_overlay.visible:
			c.army_overlay.mode_buttons.training.pressed.emit(); await settle(); check(c.army_overlay.training_box.visible,"existing training screen reachable")
		c.army_overlay.hide(); c.recruitment_overlay.hide(); c.open_battle_merit(row.battle_id)
	if win:
		for entry: Dictionary in row.participants:
			var q: Dictionary=c.Merit.quote(c,row.battle_id,entry.officer_id)
			if not q.ok: continue
			var gold: int=c.gold; await click(result.reward_buttons[entry.officer_id]); check(c.gold==gold-int(q.cost),"existing optional reward charges quoted cost")
			state=snapshot(); c.Merit.reward(c,row.battle_id,entry.officer_id); check(snapshot()==state,"reward receipt blocks duplicate payment"); break
	await pair(phase+"-final")
	slot="user://living_city_v1_9_%s_%d_%d.json" % [phase,int(Time.get_unix_time_from_system()),OS.get_process_id()]
	check(not FileAccess.file_exists(slot) and c._on_save_button_pressed(slot),"new native user slot preserves previous saves")
	write_json(phase+"-restart.json",{"slot":slot,"state":snapshot(),"battle":row.battle_id,"trace":trace})
	evidence={"battle":row,"trace":trace}; finish()
func reload_case() -> void:
	for name: String in ["victory","defeat"]:
		var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join(name+"-restart.json")))
		if c==null:
			get_tree().current_scene._load_selected_game(receipt.slot); await get_tree().create_timer(2).timeout; c=get_tree().current_scene
		else: c._on_load_button_pressed(receipt.slot); await settle()
		check(snapshot()==receipt.state,"new process full state restores "+name)
		await settle_events(); c.open_battle_merit(receipt.battle); await pair("restored-"+name)
		var before: Dictionary=snapshot(); c.merit_overlay.refresh(); await key(KEY_ESCAPE); c.open_battle_merit(receipt.battle); check(snapshot()==before,"restored result reopening has no effects "+name)
		await key(KEY_ESCAPE); check(map_ready(),"restored active map input "+name)
	finish()
func run() -> void:
	await get_tree().create_timer(2).timeout
	if not OS.has_feature("editor"): resources()
	if phase=="reload": await reload_case()
	else: await battle_case(phase=="victory")
