extends "res://tests/battle_merit_playtest.gd"

func _run() -> void:
	create_timer(120).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(MERIT_DIR)
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MERIT_DIR+"normal.json"))
	await start(Scenarios.SCENARIOS[1],"silla","historical")
	var id: String=normal.battle_id; var person: String=normal.candidate
	for mode: String in ["money","dead","inactive","enemy","unknown","loser","ended","wrong_player","unsupported","no_politics","duplicate"]:
		c._on_load_button_pressed(normal.awarded.slot if mode=="duplicate" else normal.unawarded.slot)
		var candidate: String=person
		match mode:
			"money": Economy.post(c.strategy_state,"silla",99-c.gold,"test_fixture",stamp())
			"dead": c.officer_registry.people[person].alive=false
			"inactive": c.officer_registry.people[person].active=false
			"enemy": c.officer_registry.people[person].faction_id="baekje"
			"unknown": candidate="not-a-participant"
			"loser": Merit.participant(Merit.battle(c.strategy_state,id),person).won=false
			"ended": c.strategy_state.campaign_ending.status="victory"
			"wrong_player": c.player_faction_id="baekje"
			"unsupported": c.scenario_id="baekje_fall_660"
			"no_politics": c.officer_registry.erase("politics")
		var before: Dictionary=full_state()
		check(not Merit.reward(c,id,candidate).ok and full_state()==before,"atomic revalidation rejects "+mode)
	# A displayed valid quote cannot authorize a stale click.
	c._on_load_button_pressed(normal.unawarded.slot)
	check(Merit.quote(c,id,person).ok,"valid displayed quote")
	Economy.post(c.strategy_state,"silla",99-c.gold,"test_fixture",stamp())
	var stale: Dictionary=full_state()
	check(not Merit.reward(c,id,person).ok and full_state()==stale,"execution rechecks money after preview")
	c._on_load_button_pressed(normal.unawarded.slot)
	c.officer_registry.people[person].loyalty=99
	var gid: String=c.officer_registry.people[person].political_group_id
	c.officer_registry.politics.groups[gid].cooperation=99
	check(Merit.reward(c,id,person).ok and c.officer_registry.people[person].loyalty==100 and c.officer_registry.politics.groups[gid].cooperation==100,"common political caps preserved")
	# Legacy schema deliberately removes new fields without synthesizing historic merit.
	c._on_load_button_pressed(normal.unawarded.slot)
	for row: Dictionary in c.strategy_state.army.battles:
		for key: String in ["battle_id","merit_version","participants","rewards","reward_enabled"]: row.erase(key)
	var legacy: Dictionary=save_slot("legacy")
	c._on_load_button_pressed(legacy.slot)
	var old: Dictionary=full_state()
	check(old==legacy.state and not Merit.reward(c,id,person).ok and full_state()==old,"legacy battle restore has no retroactive reward or changes")
	# Actual combat resolver, controlled placement/strength only for boundary coverage.
	for scenario: Dictionary in [Scenarios.SCENARIOS[0],Scenarios.SCENARIOS[1]]:
		await start(scenario,"silla","historical")
		var first: String=c.Army.at_city(c.strategy_state,"geumseong","silla")[0]
		check(c.Army.appoint(c.strategy_state,c.provinces,"silla",first,"historical:004").ok,"common appointment in boundary fixture")
		var split: Dictionary=c.Army.split(c.strategy_state,c.provinces,"silla",first,1000)
		check(split.ok,"normal split creates multiple units with same commander")
		# Empty the target via fixture relocation, not by altering combat formulas.
		for unit_id: String in c.Army.at_city(c.strategy_state,"sabi"):
			c.strategy_state.unit_rosters[unit_id].location="ungjin"
		var result: Dictionary=c.Army.combat(c.strategy_state,c.provinces,"geumseong","sabi",98,0,stamp(),"historical:004","")
		var entry: Dictionary=Merit.participant(result,"historical:004")
		check(result.won and result.participants.filter(func(p): return p.officer_id=="historical:004").size()==1 and entry.commanded_units.size()>=2,"multiple unit commander has one candidate "+str(scenario.year))
		var saved: Variant=canonical(Merit.battle(c.strategy_state,result.battle_id).participants)
		c.officer_registry.people["historical:004"].location="geumgwan"
		for unit: Dictionary in c.strategy_state.unit_rosters.values(): unit.commander_id=""
		check(canonical(Merit.battle(c.strategy_state,result.battle_id).participants)==saved,"postbattle movement and command changes preserve evidence")
		check(Merit.reward(c,result.battle_id,"historical:004").ok,"supported scenario actual winner can receive reward "+str(scenario.year))
		for unit_id: String in c.Army.at_city(c.strategy_state,"gosa"): c.strategy_state.unit_rosters[unit_id].location="ungjin"
		var other: Dictionary=c.Army.combat(c.strategy_state,c.provinces,"geumgwan","gosa",98,0,stamp(),"historical:004","")
		check(other.battle_id!=result.battle_id,"distinct IDs even same month")
		check(other.won and Merit.reward(c,other.battle_id,"historical:004").ok,"same officer may be rewarded once in a different victory")
	# A defensive victory uses the defender's actual snapshot, not the attacking leader.
	await start(Scenarios.SCENARIOS[1],"silla","historical")
	var defender: String=c.Army.at_city(c.strategy_state,"geumseong","silla")[0]
	c.Army.appoint(c.strategy_state,c.provinces,"silla",defender,"historical:004")
	var defense: Dictionary=c.Army.combat(c.strategy_state,c.provinces,"sabi","geumseong",0,100,stamp(),"historical:015","historical:004")
	check(not defense.won and Merit.quote(c,defense.battle_id,"historical:004").ok,"defensive victory candidate is eligible")
	check(Merit.participant(defense,"historical:004").side=="defender" and not Merit.quote(c,defense.battle_id,"historical:015").ok,"enemy or losing commander is ineligible")
	var output:=FileAccess.open(MERIT_DIR+"boundaries.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"legacy":legacy.slot},"\t")); output.close()
	print("BATTLE MERIT BOUNDARIES: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
