extends "res://tests/faction_economy_test.gd"
const Army=preload("res://army_readiness.gd")
const Mob=preload("res://mobilization.gd")
const Industry=preload("res://industry_assignment.gd")
const DIR="res://.godot/mobilization-results/"
var result_data: Dictionary={"recruitment":[],"scenarios":[],"months":[],"opening":{},"closing":{}}
func stamp() -> int: return c.year*12+c.month
func resources() -> Dictionary: return canonical({"p":c.provinces,"u":c.strategy_state.unit_rosters,"a":c.strategy_state.faction_economy.accounts,"i":c.strategy_state.city_inventory})
func origins_valid() -> bool:
	for u: Dictionary in Army.units(c.strategy_state).values():
		var n: int=0
		for value: Variant in u.origins.values(): n+=int(value)
		if n!=int(u.troops): return false
	return true
func economic_census() -> Dictionary:
	var out: Dictionary={}
	for f: String in ["silla","baekje","goguryeo"]:
		var row: Dictionary={"population":0,"troops":0,"food":0,"equipment":0,"cities":0,"account":c.strategy_state.faction_economy.accounts[f].duplicate(true),"expenses":{}}
		for city: String in Economy.city_ids(c.strategy_state,c.provinces):
			if Economy.resolve(c.strategy_state,str(c.provinces[city].faction))!=f: continue
			row.population+=int(c.provinces[city].population); row.food+=int(c.provinces[city].food_stock); row.cities+=1
		for u: Dictionary in Army.units(c.strategy_state).values():
			if u.faction_id==f: row.troops+=int(u.troops); row.equipment+=mini(int(u.equipment),int(u.troops))
		for entry: Dictionary in c.strategy_state.faction_economy.entries:
			if entry.faction_id==f and int(entry.amount)<0: row.expenses[entry.reason]=int(row.expenses.get(entry.reason,0))-int(entry.amount)
		out[f]=row
	return out
func population_cases() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var city: String="geumseong"; var s: Dictionary=c.strategy_state
	var before: Dictionary=resources(); var v: Dictionary=Mob.view(s,c.provinces,city); var q: Dictionary=c.get_recruitment_quote(city,1000)
	check(q.ok,"natural capital can recruit1000")
	var oldcap: int=c.provinces[city].granary_capacity
	var paid: Dictionary=c.request_recruitment(city,1000)
	check(paid.ok and int(c.provinces[city].population)==int(before.p[city].population)-1000 and int(c.provinces[city].troops)==int(before.p[city].troops)+1000,"civilian to serving exact1000")
	check(c.gold==int(before.a.silla.balance)-150 and c.provinces[city].food_stock==int(before.p[city].food_stock)-200,"same gold150 food200")
	check(Mob.view(s,c.provinces,city).available==int(v.available)-1000,"mobilization budget spent, C+S unchanged")
	check(c.city_operation_quote(city).tax==q.tax_after and c.city_operation_quote(city).annual_harvest==q.harvest_after and q.harvest_after<q.harvest_before,"forecast uses actual population formula once")
	check(c.provinces[city].granary_capacity==oldcap,"warehouse capacity unaffected")
	result_data.recruitment.append({"before":v,"quote":q,"after":Mob.view(s,c.provinces,city),"paid":paid})
	var uid: String=paid.unit_id
	var recruited: Dictionary=s.unit_rosters[uid]
	check(recruited.creation_reason=="recruitment" and recruited.equipment==0,"recruit reason and no generated equipment")
	check(c.queue_province_transfer({"source_id":city,"target_id":"geumgwan","unit_ids":[uid],"troops":1000,"officer_ids":[]},true).ok,"actual paid troops transfer")
	check(Mob.serving(s,city)==int(v.serving)+1000,"transit still burdens origin")
	check(not Mob.disband(s,c.provinces,"silla",uid,100,stamp()).ok,"transit cannot disband")
	c.process_pending_transfer_orders()
	var localpop: int=c.provinces.geumgwan.population
	var remaining: int=Mob.serving(s,city)
	var removed: Dictionary=Mob.disband(s,c.provinces,"silla",uid,400,stamp())
	check(removed.ok and c.provinces.geumgwan.population==localpop+400 and Mob.serving(s,city)==remaining-400,"partial discharge returns civilians at current city, releases origin")
	var split: Dictionary=Army.split(s,c.provinces,"silla",uid,200)
	check(split.ok and Army.merge(s,c.provinces,"silla",uid,split.unit_id).ok and origins_valid(),"origin mass split merge exact")
	var other: Dictionary=Army.create(s,"silla","geumgwan",301,"infantry",50,301,"geumgwan","test_fixture")
	Army.merge(s,c.provinces,"silla",uid,other.id)
	Army.casualties(s,[uid],233,stamp()); Army.sync(s,c.provinces)
	check(origins_valid() and c.provinces.geumgwan.population==localpop+400,"mixed origin battle death not civilian refund")
	native_save("mobilization-partial")
	for mode: String in ["zero","cap","money","food","enemy"]:
		await start(Scenarios.SCENARIOS[0],"silla","historical")
		if mode=="zero": c.provinces[city].population=0
		if mode=="cap": c.provinces[city].population=1
		if mode=="money": Economy.post(c.strategy_state,"silla",-999,"fixture",stamp())
		if mode=="food": c.provinces[city].food_stock=0
		before=resources()
		var r: Dictionary=Recruit.execute(c.strategy_state,c.provinces,"baekje" if mode=="enemy" else "silla","silla",city,1000,stamp())
		check(not r.ok and resources()==before,"failure atomic "+mode)
		if mode in ["zero","cap"]:
			var population: int=c.provinces[city].population
			c.strategy_state.erase("mobilization"); Mob.initialize(c.strategy_state,c.provinces)
			check(c.provinces[city].population==population and resources()==before,"legacy overcap no retroactive subtraction "+mode)
			native_save("mobilization-"+mode)
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	paid=c.request_recruitment(city,1000); uid=paid.unit_id
	var officer: String=c.get_city_officer_ids(city)[0]
	check(Army.train(c.strategy_state,c.provinces,"silla",uid,officer,stamp()).ok,"real trainer")
	check(Mob.disband(c.strategy_state,c.provinces,"silla",uid,501,stamp()).ok and not Army.training_job(c.strategy_state,uid).is_empty(),"partial discharge preserves remaining duty")
	check(Army.training_quote(c.strategy_state,c.provinces,"silla",uid,officer,stamp()).cost==25,"remaining499 monthly cost25")
	check(Mob.disband(c.strategy_state,c.provinces,"silla",uid,499,stamp()).ok and Army.training_job(c.strategy_state,uid).is_empty(),"full discharge clears training duty")
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var first: Dictionary=c.strategy_state.unit_rosters.values()[0]
	var known_city: String=first.location; var known_troops: int=first.troops
	var civilians_before: int=c.provinces[known_city].population
	first.erase("origins"); first.erase("creation_reason"); c.strategy_state.erase("mobilization")
	Mob.initialize(c.strategy_state,c.provinces)
	check(first.origins=={known_city:known_troops} and c.provinces[known_city].population==civilians_before and not c.strategy_state.mobilization.migration.is_empty(),"unknown old origin inferred with diagnostic, population preserved")
	native_save("mobilization-inferred-origin")
func iron_cases() -> void:
	for scenario: Dictionary in Scenarios.SCENARIOS:
		await start(scenario,"silla","historical")
		var availability: Dictionary={"scenario":scenario.id,"countries":{}}
		for city: String in Economy.city_ids(c.strategy_state,c.provinces):
			var f: String=Economy.resolve(c.strategy_state,str(c.provinces[city].faction))
			if f.is_empty(): continue
			check(c.strategy.get_building_quote(c.strategy_state,city,"smelter",scenario.id,c.iron_supply_rules).ok,"unrestricted common smelter "+scenario.id+city)
			availability.countries[f]=int(availability.countries.get(f,0))+1
		result_data.scenarios.append(availability); native_save("mobilization-scenario-"+scenario.id)
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	for f: String in ["silla","baekje","goguryeo"]:
		var city: String={"silla":"geumgwan","baekje":"sabi","goguryeo":"pyongyang"}[f]
		var name: String=c.strategy_state.faction_economy.factions[f]
		c.strategy_state.province_buildings[city].smelter=1
		c.strategy_state.faction_research[name].basic_smelting=1
		Production.set_enabled(c.strategy_state,c.provinces,city,"iron_procurement",name,true,c.scenario_id,c.iron_supply_rules)
		if f=="silla": Production.set_enabled(c.strategy_state,c.provinces,city,"iron_supply",name,true,c.scenario_id,c.iron_supply_rules)
	var accounts: Dictionary=c.strategy_state.faction_economy.accounts.duplicate(true)
	Production.process_all(c.strategy_state,c.provinces,stamp()+1,c.scenario_id,c.iron_supply_rules)
	for f: String in ["silla","baekje","goguryeo"]:
		var city: String={"silla":"geumgwan","baekje":"sabi","goguryeo":"pyongyang"}[f]
		check(c.strategy_state.city_inventory[city].iron==2,"one smelter twoiron only "+f)
		check(c.get_faction_gold(f)==int(accounts[f].balance)-(6 if f=="silla" else 18),"national actual supply cost "+f)
	var before: Dictionary=resources()
	Production.process_all(c.strategy_state,c.provinces,stamp()+1,c.scenario_id,c.iron_supply_rules)
	check(resources()==before,"all countries repeated production month unchanged")
	Production.set_enabled(c.strategy_state,c.provinces,"geumgwan","iron_supply","신라",false,c.scenario_id,c.iron_supply_rules)
	Production.process_all(c.strategy_state,c.provinces,stamp()+1,c.scenario_id,c.iron_supply_rules)
	check(resources()==before,"route switch same month no extra work")
	Production.process_all(c.strategy_state,c.provinces,stamp()+2,c.scenario_id,c.iron_supply_rules)
	check(c.strategy_state.city_inventory.geumgwan.iron==4 and c.gold==976,"common after regional costs18 nextmonth")
	Economy.post(c.strategy_state,"baekje",-c.get_faction_gold("baekje")+17,"fixture",stamp())
	var iron: int=c.strategy_state.city_inventory.sabi.iron
	Production.process_all(c.strategy_state,c.provinces,stamp()+3,c.scenario_id,c.iron_supply_rules)
	check(c.strategy_state.city_inventory.sabi.iron==iron and c.get_faction_gold("baekje")==17,"insufficient17 no output or charge")
	c.provinces.sabi.faction="신라"; Production.stop_on_capture(c.strategy_state,"sabi")
	Production.process_all(c.strategy_state,c.provinces,stamp()+4,c.scenario_id,c.iron_supply_rules)
	check(c.strategy_state.city_inventory.sabi.iron==iron and not c.strategy_state.city_production.sabi.iron_procurement.enabled,"capture stops common supply")
func actual_settlement_case() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var q: Dictionary=c.get_recruitment_quote("geumseong",1000)
	check(c.request_recruitment("geumseong",1000).ok,"settlement ordinary recruitment")
	c._advance_month(); c.officer_registry.clock_month=stamp()
	var gold_before: int=c.gold
	c.process_monthly_commerce_income()
	check(c.strategy_state.domestic.settlements.geumseong.tax==q.tax_after,"actual next month tax matches population/governor quote")
	var gold_after: int=c.gold; c.process_monthly_commerce_income()
	check(c.gold==gold_after and gold_after>gold_before,"tax receipt idempotent")
	c.month=9; c.officer_registry.clock_month=stamp()
	c.process_seasonal_harvest()
	var receipt: Dictionary=c.strategy_state.domestic.settlements.geumseong
	check(receipt.harvest==q.next_harvest_after,"actual September collection matches quote once, events separately recorded")
	result_data["settlement"]={"quote":q,"receipt":receipt.duplicate(true)}
func year_case() -> void:
	await start(Scenarios.SCENARIOS[1],"silla","historical"); seed(642)
	result_data.opening=economic_census()
	for n: int in range(12):
		await advance()
		check(origins_valid(),"month origins conserved "+str(n))
		reconcile("mobilization month "+str(n))
		result_data.months.append({"stamp":stamp(),"countries":economic_census()})
		native_save("mobilization-year")
	result_data.closing=economic_census()
	result_data["ai"]=c.strategy_state.get("iron_ai",{})
	result_data["mobilization_ai"]=c.strategy_state.mobilization.ai_log
	result_data["recruits"]=c.strategy_state.faction_economy.recruitment
	result_data["transactions"]=c.strategy_state.faction_economy.entries
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	await population_cases(); await iron_cases(); await actual_settlement_case(); await year_case()
	var file:=FileAccess.open(DIR+"evidence.json",FileAccess.WRITE); file.store_string(JSON.stringify(result_data,"\t")); file.close()
	print("MOBILIZATION TESTS: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
