extends "res://tests/officer_registry_test.gd"

const Economy=preload("res://faction_economy.gd")
const Recruit=preload("res://recruitment_system.gd")
const Production=preload("res://production_system.gd")
const RESULTS="res://.godot/economy-results/"
var evidence: Dictionary={"recruitment":[],"months":[],"accounts":{}}

func city_for(id: String) -> String:
	for city: String in Economy.city_ids(c.strategy_state,c.provinces):
		if Economy.resolve(c.strategy_state,str(c.provinces[city].faction))==id: return city
	return ""

func reconcile(label: String) -> void:
	for id: String in c.strategy_state.faction_economy.accounts:
		var a: Dictionary=c.strategy_state.faction_economy.accounts[id]
		var income: int=0
		var expense: int=0
		for e: Dictionary in c.strategy_state.faction_economy.entries:
			if e.faction_id!=id: continue
			income+=maxi(0,int(e.amount)); expense+=maxi(0,-int(e.amount))
		check(int(a.opening)+income-expense==int(a.balance) and income==int(a.income) and expense==int(a.expense),label+" "+id+" opening + journal income - expense = balance")

func native_save(label: String) -> void:
	var before: Dictionary=snapshot()
	c._on_save_button_pressed(RESULTS+label+".json")
	for n: int in range(3):
		c._on_load_button_pressed(RESULTS+label+".json")
		check(snapshot()==before,label+" repeated load %d preserves all authoritative state" % n)

func recruitment_cases() -> void:
	for id: String in ["silla","baekje","goguryeo"]:
		await start(Scenarios.SCENARIOS[1],id,"historical")
		var city: String=city_for(id)
		var other: String="baekje" if id=="silla" else "silla"
		var other_city: String=city_for(other)
		var other_before: int=c.get_faction_gold(other)
		var food_before: int=c.provinces[city].food_stock
		var troops_before: int=c.provinces[city].troops
		var q: Dictionary=c.get_recruitment_quote(city,1000)
		check(q.ok and q.gold_cost==150 and q.food_cost==200,id+" default quote 1000 = 150 gold / 200 local food")
		var result: Dictionary=c.request_recruitment(city,1000)
		check(result.ok and c.gold==850 and c.provinces[city].food_stock==food_before-200 and c.provinces[city].troops==troops_before+1000,id+" actual player recruitment pays once")
		evidence.recruitment.append(c.strategy_state.faction_economy.recruitment.back().duplicate(true))
		check(c.get_faction_gold(other)==other_before,id+" other national treasury untouched")
		var before: Dictionary=snapshot()
		check(not Recruit.execute(c.strategy_state,c.provinces,id,other,other_city,100, c.year*12+c.month).ok,"actor cannot charge another nation")
		check(not c.request_recruitment(other_city,100).ok,"actor cannot recruit in another nation's city")
		check(canonical(c.provinces)==before.provinces and c.get_faction_gold(other)==other_before,"rejected cross-country orders leave resources and troops intact")
		var ai_food: int=c.provinces[other_city].food_stock
		var ai_troops: int=c.provinces[other_city].troops
		check(c.recruit_for_faction(other,other_city,1000).ok and c.get_faction_gold(other)==other_before-150 and c.provinces[other_city].food_stock==ai_food-200 and c.provinces[other_city].troops==ai_troops+1000,"AI exact same 1000-person cost")
		evidence.recruitment.append(c.strategy_state.faction_economy.recruitment.back().duplicate(true))
		c.provinces[other_city].food_stock=19
		check(Recruit.affordable(c.strategy_state,c.provinces,other,other_city,500)==0,"AI cannot borrow another city's food")
		var balance: int=c.get_faction_gold(other)
		check(not c.recruit_for_faction(other,other_city,100).ok and c.get_faction_gold(other)==balance,"19 food rejects minimum with no gold debit")
		c.provinces[other_city].food_stock=10000
		Economy.post(c.strategy_state,other,14-balance,"test_fixture",c.year*12+c.month)
		check(Recruit.affordable(c.strategy_state,c.provinces,other,other_city,500)==0 and not c.recruit_for_faction(other,other_city,100).ok,"14 gold cannot recruit minimum")
		Economy.post(c.strategy_state,other,31,"test_fixture",c.year*12+c.month)
		check(Recruit.affordable(c.strategy_state,c.provinces,other,other_city,500)==300,"45 gold caps target500 at300")
		check(not c.get_recruitment_quote(city,150).ok,"non100 quantity rejected")
		native_save(id+"-paid-troops")
		var roster: Dictionary=c.Army.projection(c.strategy_state,city)
		var total: int=0
		for unit: Dictionary in roster.values(): total+=int(unit.troops)
		check(total==c.provinces[city].troops,"paid troops and unit roster preserved on repeated load")
		reconcile(id)

func production_cases() -> void:
	await start(Scenarios.SCENARIOS[1],"silla","historical")
	var cities: Dictionary={}
	for id: String in ["silla","baekje","goguryeo"]:
		var city: String=city_for(id); cities[id]=city
		var name: String=c.strategy_state.faction_economy.factions[id]
		c.strategy_state.faction_research[name].swordsmithing=1
		c.strategy_state.province_buildings[city].forge=1
		c.strategy_state.city_inventory[city].iron=10
		check(Production.set_enabled(c.strategy_state,c.provinces,city,"iron_sword",name,true,c.scenario_id).ok,id+" valid production enabled")
	Production.process_all(c.strategy_state,c.provinces,c.year*12+c.month,c.scenario_id)
	for id: String in cities:
		check(c.get_faction_gold(id)==990 and c.strategy_state.city_inventory[cities[id]].sword==1,id+" concurrent national production debits its treasury")
	var before: Dictionary=snapshot()
	Production.process_all(c.strategy_state,c.provinces,c.year*12+c.month,c.scenario_id)
	check(snapshot()==before,"all-country production repeat no-op")
	native_save("all-production")
	var captured: String=cities.baekje
	c.provinces[captured].faction="신라"
	Production.stop_on_capture(c.strategy_state,captured)
	var old_balance: int=c.get_faction_gold("baekje")
	c.month+=1
	Production.process_all(c.strategy_state,c.provinces,c.year*12+c.month,c.scenario_id)
	check(c.get_faction_gold("baekje")==old_balance and c.strategy_state.city_inventory[captured].sword==1,"capture stops old production with no charge or gift")
	var tax: int=c.city_operation_quote(captured).tax
	var b: int=c.gold
	c.process_monthly_commerce_income()
	check(c.gold>=b+tax,"captured city tax belongs to current owner")
	reconcile("production-capture")

func migration_cases() -> void:
	await start(Scenarios.SCENARIOS[1],"silla","historical")
	c.gold=777
	var city: String="geumseong"
	var id: String=c.get_city_officer_ids(city)[0]
	var started: Dictionary=c.start_domestic(city,"commerce",id)
	check(started.ok,"pending domestic migration fixture")
	c._on_save_button_pressed(RESULTS+"legacy-source.json")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RESULTS+"legacy-source.json"))
	saved.strategy_state.erase("faction_economy")
	saved.strategy_state.erase("production_months")
	for job: Dictionary in saved.strategy_state.domestic.jobs.values(): job.erase("payer_faction_id")
	var file:=FileAccess.open(RESULTS+"legacy.json",FileAccess.WRITE); file.store_string(JSON.stringify(saved)); file.close()
	c._on_load_button_pressed(RESULTS+"legacy.json")
	check(c.gold==677 and c.get_faction_gold("baekje")==1000,"legacy exact player gold; AI one-time validation seed")
	check(c.strategy_state.domestic.jobs[started.job_id].payer_faction_id=="silla","legacy pending job payer migrated")
	var ai: int=c.get_faction_gold("baekje")
	check(c.cancel_domestic(started.job_id).ok and c.gold==777 and c.get_faction_gold("baekje")==ai,"refund only original payer")
	check(not c.cancel_domestic(started.job_id).ok and c.gold==777,"refund exactly once")
	native_save("converted-refund")
	var before: Dictionary=snapshot()
	Economy.initialize(c.strategy_state,Scenarios.SCENARIOS[1],"silla",9999,true)
	check(snapshot()==before,"native ledger never re-seeded by legacy initialization")
	reconcile("migration")

func ai_and_attack_cases() -> void:
	await start(Scenarios.SCENARIOS[1],"silla","historical")
	var city: String=city_for("baekje")
	for target: String in Economy.city_ids(c.strategy_state,c.provinces):
		if c.provinces[target].faction!="신라": c.provinces[target].food_stock=0
	Economy.post(c.strategy_state,"baekje",-986,"test_fixture",c.year*12+c.month)
	c.provinces[city].food_stock=10000
	var troops: int=c.provinces[city].troops
	c.run_enemy_ai_turns()
	check(c.get_faction_gold("baekje")==14 and c.provinces[city].troops==troops,"actual AI turn with14gold skips recruitment without automatic subsidy")
	check(c.strategy_state.faction_economy.recruitment.all(func(r): return int(r.recruited)==0),"actual AI food-empty cities all skip recruitment")
	c.month+=1
	Economy.post(c.strategy_state,"baekje",31,"test_fixture",c.year*12+c.month)
	c.provinces[city].food_stock=40
	c.run_enemy_ai_turns()
	check(c.get_faction_gold("baekje")==45 and c.provinces[city].food_stock==40 and c.provinces[city].troops==troops,"AI preserves three-month upkeep:40food cannot support paid recruitment")
	var before: Dictionary=snapshot()
	c.run_enemy_ai_turns()
	check(snapshot()==before,"same AI month cannot recruit twice")
	c.month+=1; c.ai_recruitment_amount=0; c.provinces[city].food_stock=10000
	c.run_enemy_ai_turns()
	check(c.strategy_state.faction_economy.recruitment.all(func(r): return int(r.month)!=c.year*12+c.month or int(r.recruited)==0),"AI zero target never recruits minimum100; transport costs remain independent")
	await start(Scenarios.SCENARIOS[1],"silla","historical")
	for ai: bool in [false,true]:
		await start(Scenarios.SCENARIOS[1],"silla","historical")
		var source: String="ungjin" if ai else "gukwon"
		var target: String="gukwon" if ai else "ungjin"
		c.provinces[source].food_stock=499
		before=snapshot()
		if ai: c.resolve_ai_attack(source,target)
		else: c.resolve_attack(source,target)
		check(snapshot()==before,"%s direct attack rejects499localfood before combat" % ai)
		c.provinces[source].food_stock=500
		var other_food: int=c.provinces[target].food_stock
		if ai: c.resolve_ai_attack(source,target)
		else: c.resolve_attack(source,target)
		check(c.provinces[source].food_stock==0 and c.provinces[target].food_stock==other_food,"%s attack charges500 exactly at actual source" % ai)
	check(c.strategy_state.faction_economy.food_entries.filter(func(e): return e.reason=="attack").size()==1,"each fresh attack fixture retains local food payment receipt")

func trade_cases() -> void:
	await start(Scenarios.SCENARIOS[1],"silla","historical")
	var relation: Dictionary=c.strategy._ensure_relation(c.strategy_state,"신라","백제")
	relation.status="중립"; relation.treaties=["통상 조약"]
	c.strategy_state.province_buildings.geumseong.market=1
	c.strategy_state.province_buildings.sabi.market=1
	check(c.strategy.open_trade_route(c.strategy_state,"신라","백제","geumseong","sabi","철").ok,"existing valid trade route fixture")
	var expected: int=maxi(20,int((int(c.provinces.geumseong.commerce)+int(c.provinces.sabi.commerce))/5)+30-int(c.strategy_state.trade_routes[0].get("risk",10)))
	c._process_strategy_season()
	check(c.gold==1000+expected and c.get_faction_gold("baekje")==1000+expected and c.get_faction_gold("goguryeo")==1000,"season trade credits both counterpart treasuries only")
	var before: Dictionary=snapshot()
	c._process_strategy_season()
	check(snapshot()==before,"repeated seasonal trade no duplicate income or relation changes")
	native_save("bilateral-trade")

func advance() -> void:
	for n: int in range(30):
		var e: Node=c.event_presentation
		if not e.active: break
		if e.awaiting_choice():
			if e.current.steps[e.step_index].get("mode","")=="choice": e._choose("maintain_tax")
			else: e.view.next_button.pressed.emit()
		else: e.skip()
		await process_frame
	c._on_end_turn_button_pressed()
	await process_frame
	await process_frame
func twelve_months() -> void:
	await start(Scenarios.SCENARIOS[1],"silla","historical")
	seed(642)
	for n: int in range(12):
		var before: Dictionary=c.strategy_state.faction_economy.accounts.duplicate(true)
		var food_before: Dictionary={"silla":0,"baekje":0,"goguryeo":0}
		var troops_before: Dictionary=food_before.duplicate()
		for city: String in Economy.city_ids(c.strategy_state,c.provinces):
			var owner: String=Economy.resolve(c.strategy_state,str(c.provinces[city].faction))
			if food_before.has(owner):
				food_before[owner]+=int(c.provinces[city].food_stock)
				troops_before[owner]+=int(c.provinces[city].troops)
		var old_stamp: int=c.year*12+c.month
		await advance()
		check(c.year*12+c.month==old_stamp+1,"642 actual month handler advances %d" % n)
		for id: String in ["silla","baekje","goguryeo"]:
			var a: Dictionary=c.strategy_state.faction_economy.accounts[id]
			var grain: int=0; var troops: int=0; var recruited: int=0; var recruit_gold: int=0; var recruit_food: int=0
			for city: String in Economy.city_ids(c.strategy_state,c.provinces):
				if Economy.resolve(c.strategy_state,str(c.provinces[city].faction))==id:
					grain+=int(c.provinces[city].food_stock); troops+=int(c.provinces[city].troops)
			for r: Dictionary in c.strategy_state.faction_economy.recruitment:
				if r.faction_id==id and int(r.month)==c.year*12+c.month:
					recruited+=int(r.recruited); recruit_gold+=int(r.gold_cost); recruit_food+=int(r.food_cost)
			var row: Dictionary={"year":c.year,"month":c.month,"faction_id":id,"start":before[id].balance,"income":int(a.income)-int(before[id].income),"expense":int(a.expense)-int(before[id].expense),"end":a.balance,"food":grain,"troops":troops,"recruited":recruited,"recruit_gold":recruit_gold,"recruit_food":recruit_food}
			row["food_start"]=food_before[id]; row["food_delta"]=grain-int(food_before[id]); row["troops_start"]=troops_before[id]
			evidence.months.append(row)
			check(int(row.start)+int(row.income)-int(row.expense)==int(row.end),"monthly reconciliation %d %s" % [n,id])
		var snapshot_before: Dictionary=snapshot()
		c.process_monthly_commerce_income(); c.process_seasonal_harvest(); c.process_monthly_troop_food_upkeep(); c.process_monthly_storage_losses(); c.run_enemy_ai_turns()
		Production.process_all(c.strategy_state,c.provinces,c.year*12+c.month,c.scenario_id)
		if c.month in [1,4,7,10]: c._process_strategy_season()
		check(snapshot()==snapshot_before,"same month all economic phases no duplicate %d" % n)
		native_save("month-%02d" % n)
	evidence.accounts=c.strategy_state.faction_economy.accounts.duplicate(true)
	evidence.journal=c.strategy_state.faction_economy.entries.duplicate(true)
	evidence.recruitment_12months=c.strategy_state.faction_economy.recruitment.duplicate(true)
	reconcile("12months")

func _run() -> void:
	create_timer(150).timeout.connect(func(): push_error("ECONOMY TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(RESULTS)
	await recruitment_cases()
	await production_cases()
	await migration_cases()
	await ai_and_attack_cases()
	await trade_cases()
	await twelve_months()
	var file:=FileAccess.open(RESULTS+"evidence.json",FileAccess.WRITE); file.store_string(JSON.stringify(evidence,"\t")); file.close()
	print("FACTION ECONOMY TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
