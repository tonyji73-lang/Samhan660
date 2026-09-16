extends "res://tests/battle_merit_playtest.gd"

const LOOP_DIR="res://.godot/silla-642-gameplay-loop/"
var unit_id: String=""
var initial_stamp: int
var checkpoints: Dictionary={}
var outcome: Dictionary={}

func screen(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(LOOP_DIR+label+".png")==OK,"GUI "+label)

func select_value(picker: OptionButton, value: String) -> void:
	for n: int in range(picker.item_count):
		if picker.get_item_metadata(n)==value:
			picker.select(n); picker.item_selected.emit(n); return
	check(false,"available GUI selection "+value)

func press(button: Button) -> void:
	check(not button.disabled,"enabled GUI command "+button.text)
	if button.disabled: return
	if DisplayServer.get_name()=="headless": button.pressed.emit()
	else: await click(button)

func next_month(phase: String) -> void:
	var previous: int=stamp()
	c._on_end_turn_button_pressed(); await process_frame; await settle_events()
	check(stamp()==previous+1,"normal month "+phase)
	months.append({"elapsed":stamp()-initial_stamp,"phase":phase,"gold":c.gold,"stock":c.strategy_state.city_inventory.geumseong.duplicate(true),"unit":c.Army.units(c.strategy_state).get(unit_id,{}).duplicate(true)})
	print("LOOP MONTH ",stamp()-initial_stamp," ",phase," gold ",c.gold," swords ",c.strategy_state.city_inventory.geumseong.sword)

func politics_snapshot() -> Dictionary:
	return canonical({"loyalty":c.officer_registry.people["historical:004"].loyalty,"groups":c.officer_registry.politics.groups,"influence":Core.influence(c.strategy_state,c.provinces,"silla"),"posts":c.officer_registry.posts})

func finish() -> void:
	var output:=FileAccess.open(LOOP_DIR+"normal.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"pid":OS.get_process_id(),"unit_id":unit_id,"elapsed":stamp()-initial_stamp,"checkpoints":checkpoints,"outcome":outcome,"actions":actions,"months":months,"trace":trace,"events":occurrences,"checks":checks,"failures":failures},"\t")); output.close()
	print("GAMEPLAY LOOP: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)

func _run() -> void:
	create_timer(240).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(LOOP_DIR)
	seed(64220260918)
	await start(Scenarios.SCENARIOS[1],"silla","historical"); await settle_events()
	initial_stamp=stamp()
	for n: int in range(40):
		industry_orders()
		if c.strategy_state.city_inventory.geumseong.sword>=10: break
		await next_month("paid production")
	check(c.strategy_state.city_inventory.geumseong.sword>=10,"ten paid weapon bundles ready")
	c._on_city_card_production_requested("geumseong"); await screen("01-production"); c.production_overlay.hide()
	var old_ids: Array=c.Army.units(c.strategy_state).keys()
	var before_gold: int=c.gold
	check(c.request_recruitment("geumseong",1000).ok and c.gold==before_gold-150,"normal recruitment costs150")
	for uid: String in c.Army.units(c.strategy_state):
		if not old_ids.has(uid): unit_id=uid
	check(not unit_id.is_empty(),"new recruit has tracked unit ID")
	if unit_id.is_empty(): finish(); return
	c.open_army("geumseong"); select_value(c.army_overlay.selector,unit_id)
	await press(c.army_overlay.equip_button)
	check(c.Army.units(c.strategy_state)[unit_id].equipment==1000,"produced ten bundles equip recruited1000")
	select_value(c.army_overlay.officers,"historical:004"); await press(c.army_overlay.train_button)
	check(c.army_overlay.officer()=="historical:004" and c.army_overlay.details.text.contains("50.0 → 64.0"),"training refresh retains chosen trainer and real next-month quote")
	await screen("02-training-start"); c.army_overlay.hide()
	var training_start: int=stamp()
	for n: int in range(10):
		if c.Army.training_job(c.strategy_state,unit_id).is_empty(): break
		await next_month("training")
	check(c.Army.training(c.Army.units(c.strategy_state)[unit_id])>=70,"paid monthly training reaches70")
	var jobs: Array=c.strategy_state.domestic.jobs.values().filter(func(j): return j.get("unit_id","")==unit_id and j.kind=="training")
	check(jobs.size()==1 and jobs[0].cost_paid==100 and jobs[0].history.size()==2,"two training months charged50 each")
	outcome.training_months=stamp()-training_start
	await appoint("commander",unit_id,"historical:004")
	c.open_army("geumseong"); select_value(c.army_overlay.selector,unit_id); await screen("03-trained-equipped"); c.army_overlay.hide()
	checkpoints.trained=save_slot("loop_trained")
	for defense: Dictionary in c.strategy_state.army.battles:
		if defense.defender_faction!="silla": continue
		c.open_battle_merit(defense.battle_id)
		if defense.won:
			for participant: Dictionary in defense.participants:
				if participant.faction_id=="silla": check(not Merit.quote(c,defense.battle_id,participant.officer_id).ok,"natural defensive defeat cannot earn victory reward")
		await screen("natural-defense-"+defense.target); await press(c.merit_overlay.close_button)
	# The tracked unit and its commander travel together through normal one-month orders.
	for n: int in range(30):
		var u: Dictionary=c.Army.units(c.strategy_state)[unit_id]
		var source: String=u.location
		if source.is_empty(): await next_month("arrival"); continue
		var best: Dictionary={}
		var strength: float=c.Army.power(c.strategy_state,c.Army.attack_units(c.strategy_state,source,"silla"))*(1+float(c.get_best_commander(source,"attack").leadership)/100)
		for target: String in c.province_connections.get(source,[]):
			if c.Economy.resolve(c.strategy_state,c.provinces[target].faction)=="silla": continue
			var defense: float=c.Army.power(c.strategy_state,c.Army.at_city(c.strategy_state,target))*(1+float(c.get_best_commander(target).leadership)/100+float(c.provinces[target].fortress)/200)
			var ratio: float=strength/maxf(1,defense)
			if best.is_empty() or ratio>best.ratio: best={"source":source,"target":target,"ratio":ratio}
		if not best.is_empty() and best.ratio>1.05 and c.validate_attack_staff(source).ok:
			outcome.attack=best
			c.resolve_attack(source,best.target); await process_frame; await settle_events(); await process_frame; await process_frame
			break
		var rally: String=source if not best.is_empty() else "gukwon"
		if source!=rally:
			var path: Array=Planning.military_route(c,"silla",source,rally)
			check(path.size()>1,"owned route to frontier")
			if path.size()<2: finish(); return
			c.open_army(source); select_value(c.army_overlay.selector,unit_id); select_value(c.army_overlay.destination,path[1])
			await press(c.army_overlay.move_button); await screen("04-move-"+str(n)); c.army_overlay.hide()
		else:
			for city: String in Planning.owned(c,"silla"):
				if city==source: continue
				var route: Array=Planning.military_route(c,"silla",city,source)
				var amount: int=maxi(0,c.Army.count(c.strategy_state,c.Army.at_city(c.strategy_state,city,"silla",true))-3000)
				if route.size()>1 and amount>=100:
					trace.append({"month":stamp(),"reinforcement":c.queue_province_transfer({"source_id":city,"target_id":route[1],"troops":amount,"officer_ids":[]},false,"silla")})
		await next_month("frontier deployment")
	var rows: Array=c.strategy_state.army.battles
	check(outcome.has("attack") and not rows.is_empty(),"tracked trained unit reaches actual battle")
	if not outcome.has("attack") or rows.is_empty(): finish(); return
	var row: Dictionary=rows.back()
	outcome.battle=row.duplicate(true)
	check(row.won,"normal battle won")
	var trained: Array=row.attacker_state.filter(func(u): return u.id==unit_id)
	check(trained.size()==1 and trained[0].equipment==1000 and trained[0].training_points==70000 and trained[0].troops==1000,"battle snapshot contains produced trained1000 at training70")
	if not row.won: finish(); return
	var q: Dictionary=Merit.quote(c,row.battle_id,"historical:004")
	check(q.ok,"surviving trained unit commander is reward candidate")
	if not q.ok: finish(); return
	outcome.before_reward=politics_snapshot()
	await screen("05-merit-before")
	checkpoints.unawarded=save_slot("loop_unawarded")
	var money: int=c.gold
	await press(c.merit_overlay.reward_buttons["historical:004"])
	check(c.gold==money-100,"selected merit costs100")
	outcome.after_reward=politics_snapshot()
	check(outcome.after_reward.loyalty==q.loyalty_after and c.officer_registry.politics.groups[q.group_id].cooperation==q.cooperation_after,"reward loyalty and cooperation applied")
	await screen("06-merit-rewarded"); await press(c.merit_overlay.close_button)
	check(not c.map_area.modal_input_locked,"result close restores map input")
	c.open_politics(); select_value(c.politics_overlay.history_people,"historical:004")
	check(c.politics_overlay.details.text.contains("포상 완료") and c.politics_overlay.details.text.contains("참전·포상 이력"),"personnel history includes selected battle reward")
	await screen("07-history"); c.politics_overlay.hide()
	# Subsequent real personnel command: appoint the rewarded commander to the capital governor post after return.
	for n: int in range(12):
		var person: Dictionary=c.get_officer("historical:004")
		var source: String=person.get("location","")
		if source=="geumseong": break
		var route: Array=Planning.military_route(c,"silla",source,"geumseong")
		check(route.size()>1,"return route for subsequent appointment")
		if route.size()<2: finish(); return
		var move: Dictionary=c.queue_province_transfer({"source_id":source,"target_id":route[1],"troops":0,"officer_ids":["historical:004"]},true,"silla")
		trace.append({"month":stamp(),"officer_return":move})
		check(move.ok,"normal officer return")
		await next_month("return for personnel")
	outcome.before_appointment=politics_snapshot()
	await appoint("governor","geumseong","historical:004")
	outcome.after_appointment=politics_snapshot()
	check(outcome.before_appointment.influence!=outcome.after_appointment.influence,"subsequent governor appointment changes actual military political influence")
	check(c.officer_registry.people["historical:003"].loyalty==40 and c.officer_registry.politics.groups["silla:civil"].cooperation==44,"replaced governor loses loyalty10 and civil cooperation6")
	check(c.officer_registry.people["historical:004"].loyalty==63,"existing six-month appointment cooldown prevents repeated positive gain")
	checkpoints.final=save_slot("loop_final")
	outcome.battles=c.strategy_state.army.battles.duplicate(true)
	outcome.negotiations=c.Power.records(c.strategy_state).duplicate(true)
	finish()
