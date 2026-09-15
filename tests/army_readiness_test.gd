extends "res://tests/officer_registry_test.gd"
const Army=preload("res://army_readiness.gd")
const RESULTS="res://.godot/army-results/"
var evidence: Dictionary={"migration":[],"training":[],"battles":[],"ai":[]}
func stamp() -> int: return c.year*12+c.month
func totals() -> Dictionary:
	var result: Dictionary={"troops":0,"equipment":0,"training_points":0}
	for u: Dictionary in Army.units(c.strategy_state).values():
		for field: String in result: result[field]+=int(u[field])
	return result
func unit_fixture(city: String,n: int,level: int=50,equipment: int=-1) -> String:
	for id: String in Army.at_city(c.strategy_state,city): Army.casualties(c.strategy_state,[id],int(Army.units(c.strategy_state)[id].troops),stamp())
	var u: Dictionary=Army.create(c.strategy_state,c.Economy.resolve(c.strategy_state,str(c.provinces[city].faction)),city,n,"infantry",level,n if equipment<0 else equipment,city)
	Army.sync(c.strategy_state,c.provinces); return u.id
func native_save(label: String) -> void:
	var before: Dictionary=canonical({"units":c.strategy_state.unit_rosters,"army":c.strategy_state.army,"snapshot":snapshot()})
	c._on_save_button_pressed(RESULTS+label+".json")
	for n: int in range(3):
		c._on_load_button_pressed(RESULTS+label+".json")
		check(canonical({"units":c.strategy_state.unit_rosters,"army":c.strategy_state.army,"snapshot":snapshot()})==before,label+" repeated native save "+str(n))
func tick() -> void:
	c._advance_month(); c.officer_registry.clock_month=stamp(); Army.process(c.strategy_state,c.provinces,stamp())
func formation_cases() -> void:
	for scenario: Dictionary in Scenarios.SCENARIOS:
		await start(scenario,"silla","historical")
		var sum_city: int=0
		for city: String in c.provinces:
			sum_city+=int(c.provinces[city].troops)
			check(Army.count(c.strategy_state,Army.at_city(c.strategy_state,city))==int(c.provinces[city].troops),"scenario source sum "+scenario.id+"/"+city)
		check(totals().troops==sum_city and totals().equipment==sum_city,"one-time baseline equipment without stock creation")
		evidence.migration.append({"scenario":scenario.id,"totals":totals(),"diagnostics":c.strategy_state.army.migration})
		native_save(scenario.id)
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var id: String=unit_fixture("geumseong",1001,53,1050)
	var before: Dictionary=totals()
	for n: int in range(30):
		var q: Dictionary=Army.split(c.strategy_state,c.provinces,"silla",id,333)
		check(q.ok and Army.merge(c.strategy_state,c.provinces,"silla",id,q.unit_id).ok and totals()==before,"exact split/rejoin conserves all mass %d" % n)
	var recruited: Dictionary=c.request_recruitment("geumseong",1000)
	check(recruited.ok,"normal paid recruitment")
	var rookie: Dictionary=Army.units(c.strategy_state)[recruited.unit_id]
	check(rookie.equipment==0 and Army.training(rookie)==50,"new recruitment has existing base training50 but no generated equipment")
	Army.merge(c.strategy_state,c.provinces,"silla",id,rookie.id)
	var merged: Dictionary=Army.units(c.strategy_state)[id]
	check(merged.troops==2001 and merged.equipment==1050 and merged.training_points==1001*53+1000*50,"reinforcement weighted training and equipment dilution")
	c.strategy_state.city_inventory.geumseong.sword=10
	var q: Dictionary=Army.equip(c.strategy_state,c.provinces,"silla",id,10,stamp())
	check(q.ok and merged.equipment==2050 and c.strategy_state.city_inventory.geumseong.sword==0 and Army.ratio(merged)==1.0,"ten bundles pay1000 person equipment, surplus49 preserved capped bonus")
	before=totals(); check(not Army.equip(c.strategy_state,c.provinces,"silla",id,1,stamp()).ok and totals()==before,"no excess/repeated issue")
	check(not Army.equip(c.strategy_state,c.provinces,"baekje",id,1,stamp()).ok,"enemy cannot equip")
	var old_equipment: int=merged.equipment; Army.casualties(c.strategy_state,[id],501,stamp())
	check(merged.troops==1500 and merged.equipment==old_equipment-ceili(float(old_equipment)*501/2001),"proportional equipment lost with casualties")
	Army.sync(c.strategy_state,c.provinces); native_save("reinforced")
	id=Army.at_city(c.strategy_state,"geumseong")[0]
	var moved: Dictionary=c.queue_province_transfer({"source_id":"geumseong","target_id":"geumgwan","unit_ids":[id],"troops":1500,"officer_ids":[]},true)
	check(moved.ok and Army.units(c.strategy_state)[id].status=="transit" and c.provinces.geumseong.troops==0,"movement references same IDs and removes city display")
	before=totals(); native_save("moving")
	c.process_pending_transfer_orders(); check(totals()==before and Army.units(c.strategy_state)[id].location=="geumgwan","arrival preserves men/equipment/training/origin")
	c.provinces.geumgwan.troops=999999
	Army.sync(c.strategy_state,c.provinces); check(c.provinces.geumgwan.troops<999999,"city projection cannot overwrite authoritative units")

func training_cases() -> void:
	for ability: int in [30,90]:
		await start(Scenarios.SCENARIOS[0],"silla","historical")
		var id: String=unit_fixture("geumseong",1000,50,1000)
		var officer: String=c.get_city_officer_ids("geumseong")[0]
		Registry.set_stats(c.officer_registry,officer,{"leadership":ability,"war":ability})
		var q: Dictionary=Army.train(c.strategy_state,c.provinces,"silla",id,officer,stamp())
		check(q.ok and q.efficiency==ability and q.gain==5+ability/10,"weighted leadership/war training estimate")
		var old: int=c.gold; Army.process(c.strategy_state,c.provinces,stamp())
		check(c.gold==old and Army.training(Army.units(c.strategy_state)[id])==50,"no acceptance-month expense or effect")
		check(not Registry.action_available(c.officer_registry,officer,c.provinces,"attack","geumseong") and Registry.action_available(c.officer_registry,officer,c.provinces,"defense","geumseong"),"training blocks external action but defense remains")
		native_save("training-"+str(ability))
		var months: int=0
		while not Army.training_job(c.strategy_state,id).is_empty() and months<10: tick(); months+=1
		check(months==(3 if ability==30 else 2) and old-c.gold==50*months and Army.training(Army.units(c.strategy_state)[id])==70,"actual cost and months by ability")
		evidence.training.append({"ability":ability,"months":months,"cost":old-c.gold,"unit":Army.units(c.strategy_state)[id].duplicate(true)})
		var before: Dictionary=totals(); old=c.gold; Army.process(c.strategy_state,c.provinces,stamp()); check(totals()==before and c.gold==old,"monthly training idempotence")
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var id: String=unit_fixture("geumseong",1000,50,1000)
	var staff: Array=c.get_city_officer_ids("geumseong")
	Army.train(c.strategy_state,c.provinces,"silla",id,staff[0],stamp())
	c.gold=0; tick(); check(Army.training(Army.units(c.strategy_state)[id])==50 and c.gold==0,"no money pauses without progress")
	c.gold=1000; c.provinces.geumseong.food_shortage=true; tick(); check(Army.training(Army.units(c.strategy_state)[id])==50 and c.gold==1000,"failed upkeep pauses without extra food charge")
	c.provinces.geumseong.food_shortage=false
	if staff.size()>1:
		check(Army.train(c.strategy_state,c.provinces,"silla",id,staff[1],stamp()).ok,"same-city replacement retains attained training")
	Army.stop(c.strategy_state,id); check(Army.training_job(c.strategy_state,id).is_empty(),"explicit stop releases training duty")
	Army.train(c.strategy_state,c.provinces,"silla",id,staff[0],stamp())
	c.provinces.geumseong.faction="백제"; tick(); check(Army.training(Army.units(c.strategy_state)[id])==50,"capture does not train enemy units")

func battle_cases() -> void:
	for high: bool in [false,true]:
		await start(Scenarios.SCENARIOS[0],"silla","historical")
		unit_fixture("gukwon",10000,70 if high else 0,10000 if high else 0)
		unit_fixture("ungjin",8000,50,8000); c.provinces.ungjin.fortress=0
		for city: String in ["gukwon","ungjin"]:
			for oid: String in c.get_city_officer_ids(city): Registry.set_stats(c.officer_registry,oid,{"leadership":50})
		var before: Dictionary=totals()
		var result: Dictionary=c.resolve_army_battle("gukwon","ungjin","silla")
		check(result.ok and result.won==high,"actual campaign battle flips only readiness")
		check(totals().troops==before.troops-result.attacker_losses-result.defender_losses,"actual battle troop loss and occupation conservation")
		evidence.battles.append(result.duplicate(true)); native_save("battle-"+str(high))
	for size: int in [1,10,499,999]:
		await start(Scenarios.SCENARIOS[0],"silla","historical")
		unit_fixture("gukwon",size,50,size); unit_fixture("ungjin",size*3,50,size*3)
		var before: Dictionary=totals(); var r: Dictionary=c.resolve_army_battle("gukwon","ungjin","silla")
		check(r.ok and totals().troops==before.troops-r.attacker_losses-r.defender_losses and totals().troops<=before.troops,"small-army no minimum survivor creation "+str(size))
		check(c.provinces.gukwon.troops==0,"small attack annihilation stays zero")
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	unit_fixture("gukwon",1,100,1); unit_fixture("ungjin",0)
	var r: Dictionary=c.resolve_army_battle("gukwon","ungjin","silla")
	check(r.ok and r.won and c.provinces.gukwon.troops+c.provinces.ungjin.troops==1,"one-man occupation cannot make two minimum garrisons")

func ai_cases() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var q: Dictionary=c.recruit_for_faction("baekje","sabi",1000)
	c.strategy_state.city_inventory.sabi.sword=10
	c.provinces.sabi.food_stock=10000
	c.Economy.post(c.strategy_state,"baekje",1000,"test_training_budget",stamp())
	var before: int=c.gold
	c.run_enemy_ai_turns()
	check(Army.units(c.strategy_state)[q.unit_id].equipment==1000 and c.strategy_state.city_inventory.sabi.sword==0,"actual AI monthly path issues paid inventory")
	check(c.strategy_state.military_planning.log.any(func(row): return row.faction_id=="baekje" and row.actions.any(func(action): return action.action=="training" and action.result.ok)),"actual national AI records successful training command")
	var job_count: int=0
	for job: Dictionary in Domestic_jobs():
		if job.kind=="training" and job.status=="pending": job_count+=1
	check(job_count>0,"AI actual training jobs exist")
	var b: Dictionary=canonical(c.strategy_state.army); c.run_enemy_ai_turns(); check(canonical(c.strategy_state.army)==b,"AI same-month no duplicate decision")
	var money: int=c.Economy.balance(c.strategy_state,"baekje"); tick()
	check(c.Economy.balance(c.strategy_state,"baekje")<money and c.gold==before,"AI training pays its own ledger")
	evidence.ai.append({"orders":c.strategy_state.military_planning.log,"jobs":Domestic_jobs(),"accounts":c.strategy_state.faction_economy.accounts})
func Domestic_jobs() -> Array: return c.strategy_state.domestic.jobs.values()
func _run() -> void:
	create_timer(180).timeout.connect(func(): push_error("ARMY TEST TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(RESULTS)
	await formation_cases(); await training_cases(); await battle_cases(); await ai_cases(); await migration_and_command_cases()
	var f:=FileAccess.open(RESULTS+"evidence.json",FileAccess.WRITE); f.store_string(JSON.stringify(evidence,"\t")); f.close()
	print("ARMY READINESS TESTS: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)

func migration_and_command_cases() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var legacy: Dictionary=c.strategy_state.duplicate(true); legacy.erase("army")
	legacy.unit_rosters={"geumseong":{"infantry":{"troops":700,"training":65,"equipment":701},"archer":{"troops":300,"training":82}}}
	var provinces: Dictionary={"geumseong":c.provinces.geumseong.duplicate(true)}; provinces.geumseong.troops=1000
	var orders: Array=[{"source_id":"geumseong","target_id":"geumgwan","faction":"신라","troops":150,"remaining_turns":1}]
	Army.initialize(legacy,provinces,orders,c.strategy.RECRUIT_UNIT_DEFS.merged(c.strategy.SPECIAL_UNIT_DEFS))
	var types: Dictionary=Army.projection(legacy,"geumseong")
	check(types.infantry.troops==700 and types.infantry.equipment==701 and types.archer.troops==300 and types.archer.training==82,"legacy preserves existing equipment and mixed troop types")
	check(orders.has(orders[0]) and Army.units(legacy)[orders[0].unit_ids[0]].troops==150,"legacy in-transit soldiers registered once apart from city")
	var saved: Dictionary=canonical(legacy); Army.initialize(legacy,provinces,orders); check(canonical(legacy)==saved,"migration never repeats baseline equipment")
	var id: String=unit_fixture("geumseong",1000,55,700)
	var officer_id: String=c.get_city_officer_ids("geumseong")[0]
	check(Army.appoint(c.strategy_state,c.provinces,"silla",id,c.get_officer(officer_id).name).ok and Army.units(c.strategy_state)[id].commander_id==officer_id,"compatibility name resolves to stored officer ID")
	var before: Dictionary=totals(); var origins: Dictionary=Army.units(c.strategy_state)[id].origins.duplicate(true)
	check(Army.change_faction(c.strategy_state,c.provinces,"silla",id,"baekje","sabi",stamp()).ok and totals()==before and Army.units(c.strategy_state)[id].origins==origins,"explicit affiliation change preserves recruits origin and all quantities")
	check(not Army.change_faction(c.strategy_state,c.provinces,"silla",id,"silla","geumseong",stamp()).ok,"former owner cannot change other faction unit")
