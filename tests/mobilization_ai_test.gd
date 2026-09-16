extends "res://tests/mobilization_test.gd"
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	var records: Array=[]
	for mode: String in ["common","stock_transport","regional"]:
		await start(Scenarios.SCENARIOS[0],"silla" if mode!="regional" else "baekje","historical")
		var f: String="baekje" if mode!="regional" else "silla"
		var name: String=c.strategy_state.faction_economy.factions[f]
		var case_city: String="sabi" if mode!="regional" else "geumgwan"
		var case_s: Dictionary=c.strategy_state
		# Explicit equipment deficit; completed training prevents training-only splits.
		var target: Dictionary=Army.units(case_s)[Army.at_city(case_s,case_city,f).filter(func(id): return Army.units(case_s)[id].kind=="infantry")[0]]
		target.equipment=int(target.troops)-100
		target.training_points=int(target.troops)*100
		var equipment_before: int=target.equipment
		check(case_s.city_inventory[case_city].sword==0,"no pre-existing weapon bundles "+mode)
		# Controlled available-infrastructure fixture, not normal-play procurement.
		case_s.province_buildings[case_city].smelter=1; case_s.province_buildings[case_city].forge=1
		case_s.faction_research[name].basic_smelting=1; case_s.faction_research[name].swordsmithing=1
		case_s["iron_ai"]={"months":{},"log":[],"last":{},"hubs":{f:case_city}}
		Economy.post(case_s,f,2000,"explicit_ai_fixture",stamp())
		if mode=="stock_transport":
			case_s.city_inventory.ungjin.iron=20
			Production.set_enabled(case_s,c.provinces,case_city,"iron_sword",name,true,c.scenario_id,c.iron_supply_rules)
		c.run_enemy_ai_turns()
		if mode=="stock_transport":
			check(c.Supply.ensure(case_s).orders.values().any(func(o): return o.target==case_city and o.cargo.iron>0),"actual AI compares and dispatches existing local iron stock")
		else:
			check(case_s.city_production[case_city]["iron_supply" if mode=="regional" else "iron_procurement"].enabled,"actual AI enables lowest eligible local route "+mode)
		var before: int=c.get_faction_gold(f)
		var gold_production: int=0
		# Planning may split formations; establish the precise deficit after that phase.
		target.equipment=int(target.troops)-100
		equipment_before=target.equipment
		# Execute the real settlement phases separately to observe stock before AI consumes it.
		c.Supply.process(case_s,c.provinces,stamp()+1)
		Production.process_all(case_s,c.provinces,stamp()+1,c.scenario_id,c.iron_supply_rules)
		check(case_s.city_inventory[case_city].sword==1 and target.equipment==equipment_before,"paid production creates stock before issue "+mode)
		Army.ai(case_s,c.provinces,f,stamp()+1)
		var issues: Array=case_s.army.history.filter(func(h): return h.action=="equipment_issue" and h.faction_id==f and h.unit_id==target.id and h.month==stamp()+1)
		check(issues.size()==1 and issues[0].bundles==1 and issues[0].persons==100 and target.equipment==equipment_before+100 and case_s.city_inventory[case_city].sword==0,"AI consumes produced bundle for the deficient unit "+mode)
		await advance()
		for entry: Dictionary in case_s.faction_economy.entries:
			if entry.faction_id==f and entry.reason=="production" and int(entry.month)==stamp(): gold_production-=int(entry.amount)
		check(gold_production==(10 if mode=="stock_transport" else (16 if mode=="regional" else 28)),"actual national production cost "+mode)
		var history: Array=case_s.army.history.duplicate(true)
		var current: Dictionary=resources(); c.run_enemy_ai_turns()
		check(resources()==current and case_s.army.history==history,"actual AI same-month resources and issues unchanged "+mode)
		records.append({"mode":mode,"production_gold":gold_production,"decisions":case_s.iron_ai,"supply_log":case_s.supply_transport.ai_log,"equipment":case_s.army.history,"national_before":before})
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var full_s: Dictionary=c.strategy_state
	full_s.city_inventory.sabi.sword=3
	for uid: String in Army.at_city(full_s,"sabi","baekje"):
		var unit: Dictionary=Army.units(full_s)[uid]
		unit.equipment=unit.troops
	var full_history: Array=full_s.army.history.filter(func(h): return h.action=="equipment_issue" and h.city_id=="sabi")
	c.run_enemy_ai_turns()
	check(full_s.city_inventory.sabi.sword==3 and full_s.army.history.filter(func(h): return h.action=="equipment_issue" and h.city_id=="sabi")==full_history,"fully equipped units leave available bundles unissued")
	await start(Scenarios.SCENARIOS[0],"baekje","historical")
	var city: String="sabi"; var s: Dictionary=c.strategy_state
	var worker: String=c.get_city_officer_ids(city)[0]
	Registry.set_stats(c.officer_registry,worker,{"politics":100,"intelligence":100})
	s.province_buildings[city].smelter=1; s.faction_research["백제"].basic_smelting=1
	check(Industry.start(s,c.provinces,c.strategy,"baekje",city,"production","",worker,stamp(),c.scenario_id,c.iron_supply_rules).ok,"common production manager fixture")
	Production.set_enabled(s,c.provinces,city,"iron_procurement","백제",true,c.scenario_id,c.iron_supply_rules)
	var opening: int=c.gold
	for n: int in range(1,3): Production.process_all(s,c.provinces,stamp()+n,c.scenario_id,c.iron_supply_rules)
	check(s.city_inventory[city].iron==6 and c.gold==opening-54,"150work two months three full paid common batches")
	check(s.facility_progress[city].smelter.remainder==0,"no integer work banking")
	var file:=FileAccess.open(DIR+"ai-evidence.json",FileAccess.WRITE); file.store_string(JSON.stringify(records,"\t")); file.close()
	print("MOBILIZATION AI TESTS: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
