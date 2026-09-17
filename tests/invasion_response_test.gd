extends "res://tests/invasion_response_playtest.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INV_DIR+"normal.json"))
	await start(Scenarios.SCENARIOS[1],"silla","historical"); initial_stamp=stamp()
	for mode: String in ["source","target","food","unit_faction","unit_dead","unit_transit","leader_dead","leader_changed","leader_transit","leader_busy","ended","valid"]:
		c._on_load_button_pressed(normal.checkpoints.pending.slot); await process_frame
		var row: Dictionary=c.strategy_state.invasions.orders[normal.order]
		var uid: String=row.units[0]; var u: Dictionary=c.Army.units(c.strategy_state)[uid]
		# Deliberate boundary fixtures, separate from the normal comparison.
		match mode:
			"source": c.provinces[row.source].faction="고구려"
			"target": c.provinces[row.target].faction="고구려"
			"food": c.provinces[row.source].food_stock=0
			"unit_faction": u.faction_id="silla"
			"unit_dead": u.troops=0
			"unit_transit": u.status="transit"
			"leader_dead": row.commander="historical:004"; c.officer_registry.people[row.commander].alive=false
			"leader_changed": u.commander_id="historical:004"
			"leader_transit": row.commander="historical:004"; c.officer_registry.people[row.commander].in_transit=true
			"leader_busy":
				row.commander="historical:004"; c.officer_registry.people[row.commander].faction_id=row.faction; c.officer_registry.people[row.commander].location=row.source
				c.officer_registry.people[row.commander].duties.append({"kind":"industry","job_id":"controlled_busy"})
			"ended": c.strategy_state.campaign_ending.status="victory"
		c.year=int((int(row.due_month)-1)/12); c.month=(int(row.due_month)-1)%12+1
		var battles: int=c.strategy_state.army.battles.size(); var food_before: int=c.provinces[row.source].food_stock
		c.Invasions.process(c)
		check(row.status==("completed" if mode=="valid" else "cancelled"),"execution validity "+mode)
		check(c.strategy_state.army.battles.size()==battles+(1 if mode=="valid" else 0),"single or no battle "+mode)
		check(c.provinces[row.source].food_stock==food_before-(c.ATTACK_FOOD_COST if mode=="valid" else 0),"exact one or no battle debit "+mode)
		check(c.Army.reservation(c.strategy_state,uid).is_empty(),"reservation released "+mode)
		if mode!="valid": check(not row.reason.is_empty(),"cancellation reason retained "+mode)
		if mode=="target":
			c.open_invasions(); select_value(c.invasion_overlay.orders,row.id)
			check(c.invasion_overlay.details.text.contains(row.reason),"cancelled threat GUI shows exact reason")
			await screen("controlled-cancelled"); c.invasion_overlay.hide()
		var after: Dictionary=full_state(); c.Invasions.process(c)
		check(full_state()==after,"duplicate processing inert "+mode)
		check(not c.resolve_army_battle(row.source,row.target,row.faction,row).ok and full_state()==after,"completed or cancelled API cannot replay "+mode)
	c._on_load_button_pressed(normal.checkpoints.pending.slot); await process_frame
	var row: Dictionary=c.strategy_state.invasions.orders[normal.order]; var uid: String=row.units[0]
	var before: Dictionary=full_state()
	check(not c.Invasions.declare(c,row.source,row.target).ok,"same units cannot be reserved twice")
	check(not c.Army.split(c.strategy_state,c.provinces,row.faction,uid,100).ok,"reserved split blocked")
	check(not c.Army.merge(c.strategy_state,c.provinces,row.faction,row.units[1],uid).ok,"reserved merge blocked")
	check(not c.Army.appoint(c.strategy_state,c.provinces,row.faction,uid,"").ok,"reserved appointment blocked")
	check(not c.Army.equip(c.strategy_state,c.provinces,row.faction,uid,1,stamp()).ok,"reserved equipment command blocked")
	check(not c.Army.train(c.strategy_state,c.provinces,row.faction,uid,"",stamp()).ok,"reserved training blocked")
	check(not c.Mobilization.disband(c.strategy_state,c.provinces,row.faction,uid,100,stamp()).ok,"reserved disband blocked")
	for city: String in c.province_connections.get(row.source,[]):
		if c.provinces[city].faction!=c.provinces[row.source].faction: continue
		check(not c.queue_province_transfer({"source_id":row.source,"target_id":city,"troops":c.Army.units(c.strategy_state)[uid].troops,"unit_ids":[uid],"officer_ids":[]},false,row.faction).ok,"explicit reserved movement blocked")
		check(not c.queue_province_transfer({"source_id":row.source,"target_id":city,"troops":c.provinces[row.source].troops,"officer_ids":[]},false,row.faction).ok,"implicit movement excludes reserved troops"); break
	check(not c.Army.attack_units(c.strategy_state,row.source,row.faction).has(uid),"reserved units excluded from other attacks")
	check(full_state()==before,"rejected commands preserve all state")
	var second: Dictionary={}
	var army_before: Variant=canonical(c.strategy_state.unit_rosters)
	for source: String in c.provinces:
		if source==row.source or c.provinces[source].faction!="백제": continue
		for target: String in c.province_connections.get(source,[]):
			if c.provinces[target].faction!=c.player_faction: continue
			var q: Dictionary=c.Invasions.declare(c,source,target)
			if q.ok: second=q.order; break
		if not second.is_empty(): break
	check(not second.is_empty() and second.id!=row.id,"multiple independently reserved invasions")
	check(canonical(c.strategy_state.unit_rosters)==army_before,"declaration never duplicates or creates soldiers")
	if not second.is_empty():
		check(second.units.all(func(id): return not row.units.has(id)),"multiple invasions do not share units")
		c.open_invasions(); check(c.invasion_overlay.orders.item_count>=2,"multiple-order history UI remains accessible")
		select_value(c.invasion_overlay.orders,second.id); check(c.invasion_overlay.row().id==second.id,"second threat selectable")
		await screen("controlled-second-threat")
		select_value(c.invasion_overlay.orders,row.id); check(c.invasion_overlay.row().id==row.id,"first threat can be revisited")
		await screen("controlled-first-threat"); c.invasion_overlay.hide()
		var multiple: Dictionary=save_slot("controlled_multiple"); c._on_load_button_pressed(multiple.slot)
		check(full_state()==multiple.state,"multiple pending invasions survive save")
		c.year=int((int(row.due_month)-1)/12); c.month=(int(row.due_month)-1)%12+1
		c.Invasions.process(c)
		check(c.Invasions.pending(c.strategy_state).is_empty(),"all due orders settle independently")
	# Controlled current-state boundary: injury/equipment changes and later arrivals
	# are not a frozen announcement army and cannot silently join its reservation.
	c._on_load_button_pressed(normal.checkpoints.pending.slot); await process_frame
	row=c.strategy_state.invasions.orders[normal.order]
	var changed: Dictionary=c.Army.units(c.strategy_state)[row.units[0]]
	changed.equipment=0; changed.training_points=int(changed.troops)*70
	var extra: Dictionary=c.Army.create(c.strategy_state,row.faction,row.source,100,"infantry",50,100,row.source,"controlled_fixture")
	c.Army.sync(c.strategy_state,c.provinces)
	var expected_power: float=c.Army.power(c.strategy_state,row.units)*1.5
	c.year=int((int(row.due_month)-1)/12); c.month=(int(row.due_month)-1)%12+1; c.Invasions.process(c)
	var battle: Dictionary=Merit.battle(c.strategy_state,row.battle_id)
	check(is_equal_approx(float(battle.attacker_power),expected_power),"battle uses actual current equipment and training")
	check(not battle.attack_units.has(extra.id) and int(battle.attacker_troops)==int(row.announced_troops),"unreserved later arrivals do not silently join attack")
	c._on_load_button_pressed(normal.checkpoints.none_after.slot); await process_frame
	c.strategy_state.erase("invasions"); var legacy: Dictionary=save_slot("controlled_legacy")
	c._on_load_button_pressed(legacy.slot); before=full_state(); c.Invasions.process(c)
	check(full_state()==before and c.Invasions.pending(c.strategy_state).is_empty(),"legacy has no pending attacks and never replays past battles")
	print("INVASION BOUNDARIES: ",checks," checks, ",failures," failures"); quit(0 if failures==0 else 1)
