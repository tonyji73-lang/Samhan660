extends "res://tests/noble_politics_test.gd"
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var r: Dictionary=c.officer_registry
	Registry.set_location(r,"historical:002","geumseong")
	Noble.appoint(c,"silla","governor","geumseong","historical:002")
	check(r.people["historical:002"].loyalty==58 and r.people["historical:003"].loyalty==40 and r.politics.groups["silla:civil"].cooperation==50,"same-group replacement personal only")
	var old: Variant=canonical(r.politics)
	Core.initialize(r,c.scenario_id,633*12+1)
	check(canonical(r.politics)==old,"633 cannot reinitialize political history")
	var before: Variant=canonical(r.people["historical:017"])
	Registry.set_post(r,"governor:gosa","historical:017")
	Core.reaction(r,"historical:017","",false,"test other faction",stamp())
	check(canonical(r.people["historical:017"])==before,"632 other factions have no political personality effects")
	var unit: String=Army.at_city(c.strategy_state,"geumseong","silla")[0]
	Army.appoint(c.strategy_state,c.provinces,"silla",unit,"historical:004")
	var n: int=Core.influence(c.strategy_state,c.provinces,"silla").groups["silla:military"].troops
	c.strategy_state.unit_rosters[unit].status="transit"; c.strategy_state.unit_rosters[unit].location=""
	r.people["historical:004"].in_transit=true
	check(Core.influence(c.strategy_state,c.provinces,"silla").groups["silla:military"].troops==n,"transit actual commander remains included once")
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	c.officer_registry.erase("politics")
	var original: Variant=snapshot()
	c._on_save_button_pressed(DIR+"legacy-no-politics.json")
	c._on_load_button_pressed(DIR+"legacy-no-politics.json")
	check(not c.officer_registry.has("politics") and snapshot()==original,"old save no new groups awards resources or event generation")
	var ai: Array=[]
	for expected: String in ["accept","gift","reject"]:
		await start(Scenarios.SCENARIOS[0],"baekje","historical")
		# Controlled existing-unit placement builds influence; no troops added.
		var candidate: String="historical:003" if expected=="accept" else "historical:004"
		var previous: String="historical:004" if expected=="accept" else "historical:003"
		Registry.set_post(c.officer_registry,"governor:geumseong",previous,"검증 초기 배치")
		var total: int=0
		for u: Dictionary in c.strategy_state.unit_rosters.values():
			if u.faction_id=="silla" and int(u.troops)>0 and total<90000:
				u.location="geumseong"; u.commander_id=candidate; total+=int(u.troops)
		if expected=="gift": Economy.post(c.strategy_state,"silla",10000,"explicit_test_budget",stamp())
		var money: int=Economy.balance(c.strategy_state,"silla")
		c._present_pending_choice() # actual campaign monthly presentation/AI integration
		check(not c.officer_registry.politics.ai_log.is_empty(),"AI real campaign path decides "+expected)
		var entry: Dictionary=c.officer_registry.politics.ai_log.back()
		check(entry.choice==expected and Economy.balance(c.strategy_state,"silla")==money-(100 if expected=="gift" else 0),"AI ability concentration reserve and identical cost "+expected)
		ai.append(entry)
		var db: Variant=canonical(c.officer_registry.politics)
		c._present_pending_choice()
		check(canonical(c.officer_registry.politics)==db,"AI same-month demand cooldown "+expected)
	var file:=FileAccess.open(DIR+"supplement.json",FileAccess.WRITE); file.store_string(JSON.stringify(ai,"\t")); file.close()
	print("NOBLE SUPPLEMENT: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
