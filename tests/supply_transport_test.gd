extends "res://tests/officer_registry_test.gd"
const Supply=preload("res://supply_transport.gd")
const Production=preload("res://production_system.gd")
const Economy=preload("res://faction_economy.gd")
const RESULTS="res://.godot/supply-results/"
var evidence: Dictionary={"cargo":[],"costs":[],"ai":[],"monthly":[]}
func stamp() -> int: return c.year*12+c.month
func total(item: String) -> int:
	var count: int=0
	for city: String in c.provinces: count+=Production.get_stock(c.strategy_state,c.provinces,city,item)
	for order: Dictionary in Supply.ensure(c.strategy_state).orders.values(): count+=int(order.cargo.get(item,0))
	return count
func send(source: String,target: String,cargo: Dictionary,faction: String="silla") -> Dictionary:
	return Supply.start(c.strategy_state,c.provinces,faction,source,target,cargo,stamp())
func fixture_stock(city: String,cargo: Dictionary) -> void:
	for item: String in cargo:
		if item=="grain": c.provinces[city].food_stock=cargo[item]
		else: c.strategy_state.city_inventory[city][item]=cargo[item]
func native_save(label: String) -> void:
	var before: Dictionary=snapshot()
	c._on_save_button_pressed(RESULTS+label+".json")
	for n: int in range(3):
		c._on_load_button_pressed(RESULTS+label+".json")
		if snapshot()!=before and n==0:
			var d:=FileAccess.open(RESULTS+label+"-diff.json",FileAccess.WRITE); d.store_string(JSON.stringify({"before":before,"after":snapshot()},"\t")); d.close()
		check(snapshot()==before,label+" native restore has no inventory or movement side effects %d" % n)
func tick() -> void:
	c._advance_month(); c.officer_registry.clock_month=stamp(); Supply.process(c.strategy_state,c.provinces,stamp())
func events() -> void:
	var e: Node=c.event_presentation
	for n: int in range(40):
		if not e.active: break
		if e.awaiting_choice():
			if e.current.steps[e.step_index].get("mode","")=="choice": e.view.choice_buttons.maintain_tax.pressed.emit()
			else: e.view.next_button.pressed.emit()
		else: e.skip()
		await process_frame

func cargo_cases() -> void:
	for cargo: Dictionary in [{"grain":400},{"iron":12},{"sword":8},{"food_stock":400,"iron":12,"weapons":8}]:
		await start(Scenarios.SCENARIOS[0],"silla","historical")
		fixture_stock("geumseong",{"grain":2000,"iron":20,"sword":20})
		var initial: Dictionary={}
		for item: String in Supply.WEIGHTS: initial[item]=total(item)
		var gold: int=c.gold
		var source_before: Dictionary=Production.get_inventory_view(c.strategy_state,c.provinces,"geumseong")
		var q: Dictionary=send("geumseong","geumgwan",cargo)
		check(q.ok,"single/mixed cargo accepted "+str(cargo))
		var o: Dictionary=Supply.ensure(c.strategy_state).orders[q.order_id]
		check(c.gold==gold-q.cost and o.path==["geumseong","geumgwan"],"one edge exact payment and route")
		for item: String in Supply.WEIGHTS:
			check(total(item)==initial[item] and Production.get_stock(c.strategy_state,c.provinces,"geumseong",item)==int(source_before[item])-int(o.cargo[item]),"dispatch conserves and removes "+item)
		Supply.process(c.strategy_state,c.provinces,stamp()); check(o.moves==0,"no same-month movement")
		native_save("cargo-"+str(checks))
		tick(); o=Supply.ensure(c.strategy_state).orders[q.order_id]
		check(o.status=="arrived" and o.moves==1,"next month one edge arrival")
		var before: Dictionary=snapshot(); Supply.process(c.strategy_state,c.provinces,stamp()); check(snapshot()==before,"arrival cannot repeat")
		for item: String in Supply.WEIGHTS: check(total(item)==initial[item],"arrival conserves "+item)
		evidence.cargo.append({"input":cargo,"quote":q,"order":o.duplicate(true),"source_before":source_before,"source_after":Production.get_inventory_view(c.strategy_state,c.provinces,"geumseong"),"target_after":Production.get_inventory_view(c.strategy_state,c.provinces,"geumgwan"),"gold_before":gold,"gold_after":c.gold})

func validation_cases() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	fixture_stock("geumseong",{"grain":3000,"iron":10,"sword":4})
	for cargo: Dictionary in [{"grain":2001},{"iron":11},{"grain":-1},{"grain":1.5},{"unknown":1},{"grain":0},{"sword":1,"weapons":2}]:
		var case_before: Dictionary=snapshot(); check(not send("geumseong","geumgwan",cargo).ok and snapshot()==case_before,"invalid cargo is atomic "+str(cargo))
	check(Supply.cargo_quote({"sword":2,"weapons":2}).cargo.sword==2,"same alias value does not double inventory")
	for target: String in ["sabi","geumseong","missing","ulleung","tamna"]:
		check(not send("geumseong",target,{"grain":1}).ok,"enemy/sea/same/noncity path blocked "+target)
	check(not Supply.graph().get("haslla",[]).has("ulleung"),"sea excluded even when friendly")
	check(Supply.graph().get("gukwon",[]).has("jukryeong"),"mountain included")
	check(not Supply.quote(c.strategy_state,c.provinces,"baekje","geumseong","geumgwan",{"grain":1},stamp()).ok,"other faction cannot use source")
	c.gold=0; var before: Dictionary=snapshot(); check(not send("geumseong","geumgwan",{"grain":1}).ok and snapshot()==before,"insufficient gold no cost/cargo")
	c.gold=1000
	for level: int in range(4):
		c.strategy_state.faction_research[c.player_faction].logistics=level
		var q: Dictionary=send("geumseong","geumgwan",{"grain":1000})
		check(q.ok and q.cost==[20,18,16,14][level],"logistics exact tier "+str(level))
		check(Supply.command(c.strategy_state,c.provinces,"silla",q.order_id,"cancel","",stamp()).ok and c.gold==1000,"pre-move exact paid refund")
		before=snapshot(); check(not Supply.command(c.strategy_state,c.provinces,"silla",q.order_id,"cancel","",stamp()).ok and snapshot()==before,"no duplicate refund")
		evidence.costs.append({"level":level,"base":q.base_cost,"paid":q.cost,"restored":c.gold})
	c.strategy_state.faction_research[c.player_faction].logistics=3
	var rounded: Dictionary=Supply.quote(c.strategy_state,c.provinces,"silla","geumseong","geumgwan",{"grain":1},stamp())
	check(rounded.cost==8,"final discounted cost rounds up")

func lifecycle_cases() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var q: Dictionary=send("geumgwan","siljik",{"grain":100})
	check(q.ok and q.path==["geumgwan","geumseong","siljik"],"deterministic multihop")
	tick(); var o: Dictionary=Supply.ensure(c.strategy_state).orders[q.order_id]
	check(o.current=="geumseong","one of two edges moved")
	check(not Supply.command(c.strategy_state,c.provinces,"silla",o.id,"cancel","",stamp()).ok,"cannot cancel after departure")
	c.provinces.geumgwan.faction="백제"; Supply.capture(c.strategy_state,c.provinces,"geumgwan",stamp())
	check(o.status=="transit" and o.cargo.grain==100,"past city capture does not erase distant cargo")
	c.provinces.siljik.faction="백제"; tick()
	check(o.status=="waiting" and o.current=="geumseong","future enemy city pauses at current city")
	native_save("waiting")
	o=Supply.ensure(c.strategy_state).orders[q.order_id]
	var before_gold: int=c.gold
	var reroute: Dictionary=Supply.quote(c.strategy_state,c.provinces,"silla",o.current,"dalgubeol",o.cargo,stamp(),true)
	check(Supply.command(c.strategy_state,c.provinces,"silla",o.id,"reroute","dalgubeol",stamp()).ok and c.gold==before_gold-reroute.cost,"reroute pays new route")
	Supply.process(c.strategy_state,c.provinces,stamp()); check(o.current=="geumseong","reroute does not move again this month")
	tick(); check(o.status=="arrived" and o.current=="dalgubeol","reroute arrives next month")
	q=send("geumseong","dalgubeol",{"grain":100}); o=Supply.ensure(c.strategy_state).orders[q.order_id]
	var sum_before: int=total("grain"); before_gold=c.gold
	check(Supply.command(c.strategy_state,c.provinces,"silla",o.id,"unload","",stamp()).ok and total("grain")==sum_before and c.gold==before_gold,"local unload conserves no refund")
	q=send("geumseong","dalgubeol",{"grain":100}); o=Supply.ensure(c.strategy_state).orders[q.order_id]
	c.provinces.geumseong.faction="백제"; var city_before: int=c.provinces.geumseong.food_stock
	Supply.capture(c.strategy_state,c.provinces,"geumseong",stamp()); Supply.process(c.strategy_state,c.provinces,stamp())
	check(o.status=="captured" and o.cargo.grain==0 and c.provinces.geumseong.food_stock==city_before+100,"capture city receives cargo once")
	check(total("grain")==sum_before and c.gold==before_gold-11,"capture conserves stocks and no refund")
	native_save("captured")
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var worker: String=c.get_city_officer_ids("geumseong")[0]
	check(c.queue_province_transfer({"source_id":"geumseong","target_id":"geumgwan","officer_ids":[worker],"troops":0},true).ok,"existing officer order created")
	var transfer_before: Array=c.pending_transfer_orders.duplicate(true)
	c.strategy_state.erase("supply_transport"); c._on_save_button_pressed(RESULTS+"legacy.json"); c._on_load_button_pressed(RESULTS+"legacy.json")
	check(Supply.ensure(c.strategy_state).orders.is_empty() and canonical(c.pending_transfer_orders)==canonical(transfer_before),"old save adds empty cargo and preserves officer orders")

func ai_cases() -> void:
	for faction: String in ["silla","baekje","goguryeo"]:
		await start(Scenarios.SCENARIOS[0],"silla","historical")
		var pair: Array={"silla":["geumseong","geumgwan"],"baekje":["sabi","geummajeo"],"goguryeo":["pyongyang","daedonggang"]}[faction]
		for city: String in Economy.city_ids(c.strategy_state,c.provinces):
			if Supply.owner(c.strategy_state,c.provinces,city)==faction: c.provinces[city].food_stock=Supply.upkeep(c.provinces[city])*6
		fixture_stock(pair[0],{"grain":10000}); fixture_stock(pair[1],{"grain":0})
		var old: int=Economy.balance(c.strategy_state,faction)
		Supply.ai(c.strategy_state,c.provinces,faction,stamp(),500,{},c.scenario_id,c.iron_supply_rules)
		var orders: Array=Supply.ensure(c.strategy_state).orders.values()
		check(orders.size()==1 and orders[0].target==pair[1],"AI targets shortage "+faction)
		var case_o: Dictionary=orders[0]
		var player_quote: Dictionary=Supply.quote(c.strategy_state,c.provinces,faction,case_o.source,case_o.target,case_o.cargo,stamp(),true)
		check(old-Economy.balance(c.strategy_state,faction)==player_quote.cost and case_o.moves==0,"AI same cost and no immediate move "+faction)
		var before: Dictionary=snapshot(); Supply.ai(c.strategy_state,c.provinces,faction,stamp(),500,{},c.scenario_id,c.iron_supply_rules); check(snapshot()==before,"AI one monthly call "+faction)
		check(Supply.incoming(c.strategy_state,c.provinces,faction,case_o.target,"grain",stamp()+10,stamp())==case_o.cargo.grain,"incoming counted")
		tick(); check(case_o.status=="arrived","AI one-edge arrival "+faction)
		evidence.ai.append({"faction":faction,"order":case_o.duplicate(true),"log":Supply.ensure(c.strategy_state).ai_log.duplicate(true)})
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	# Live AI entry point; only shortage/donor fixtures, no direct transport call.
	c.provinces.geummajeo.food_stock=0; c.provinces.sabi.food_stock=10000
	await events(); c._on_end_turn_button_pressed(); await events()
	var all_orders: Array=Supply.ensure(c.strategy_state).orders.values()
	check(not all_orders.is_empty(),"real campaign monthly AI creates transport")
	var o: Dictionary=all_orders[0]; var sent: int=int(o.cargo.grain); var target: String=o.target
	var before_food: int=c.provinces[target].food_stock
	c._on_end_turn_button_pressed(); await events()
	check(o.status=="arrived" and c.provinces[target].food_stock>before_food,"real campaign AI shipment arrives before upkeep/recruitment")
	evidence.monthly.append({"order":o.duplicate(true),"sent":sent,"target_before":before_food,"target_after":c.provinces[target].food_stock,"ledger":c.strategy_state.faction_economy.duplicate(true),"ai_log":Supply.ensure(c.strategy_state).ai_log.duplicate(true)})
	native_save("live-ai")

func _run() -> void:
	create_timer(160).timeout.connect(func(): push_error("SUPPLY TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(RESULTS)
	await cargo_cases(); await validation_cases(); await lifecycle_cases(); await ai_cases(); await policy_cases(); await phase_cases()
	var f:=FileAccess.open(RESULTS+"evidence.json",FileAccess.WRITE); f.store_string(JSON.stringify(evidence,"\t")); f.close()
	print("SUPPLY TRANSPORT TESTS: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)

func policy_cases() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	for city: String in Economy.city_ids(c.strategy_state,c.provinces):
		if Supply.owner(c.strategy_state,c.provinces,city)=="baekje": c.provinces[city].food_stock=Supply.upkeep(c.provinces[city])*6
	c.provinces.geummajeo.food_stock=0
	var food_before: int=total("grain")
	Supply.ai(c.strategy_state,c.provinces,"baekje",stamp(),500,{},c.scenario_id,c.iron_supply_rules)
	check(Supply.ensure(c.strategy_state).orders.is_empty() and total("grain")==food_before,"AI cannot take donors six-month reserve or create supplies")
	c.provinces.sabi.food_stock=10000
	c.strategy_state.faction_economy.accounts.baekje.balance=0
	Supply.ai(c.strategy_state,c.provinces,"baekje",stamp()+1,500,{},c.scenario_id,c.iron_supply_rules)
	check(Supply.ensure(c.strategy_state).orders.is_empty() and c.strategy_state.faction_economy.accounts.baekje.balance==0,"AI no treasury refill on shipping failure")
	check(not Supply.ensure(c.strategy_state).ai_log.back().attempts.is_empty(),"AI failed quote reason retained")
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	# A two-edge valid incoming shipment fully covers the target; don't duplicate it next month.
	for city: String in Economy.city_ids(c.strategy_state,c.provinces):
		if Supply.owner(c.strategy_state,c.provinces,city)=="baekje": c.provinces[city].food_stock=10000
	c.provinces.geummajeo.food_stock=0
	var q: Dictionary=send("gosa","geummajeo",{"grain":1000},"baekje")
	tick(); Supply.ai(c.strategy_state,c.provinces,"baekje",stamp(),500,{},c.scenario_id,c.iron_supply_rules)
	check(Supply.ensure(c.strategy_state).orders.size()==1,"incoming cargo prevents duplicate need shipment")
	var o: Dictionary=Supply.ensure(c.strategy_state).orders[q.order_id]
	c.provinces.geummajeo.faction="신라"
	Supply.ai(c.strategy_state,c.provinces,"baekje",stamp()+1,500,{},c.scenario_id,c.iron_supply_rules)
	check(o.status=="unloaded" and o.current=="sabi","AI blocked destination locally unloads without teleport or refund")
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	# Valid existing production order, controlled facility/material fixture. Historical region/recipe requirements unchanged.
	for city: String in Economy.city_ids(c.strategy_state,c.provinces):
		if Supply.owner(c.strategy_state,c.provinces,city)=="baekje": c.provinces[city].food_stock=10000
	c.strategy_state.province_buildings.sabi.forge=1
	c.strategy_state.faction_research["백제"].swordsmithing=1
	fixture_stock("geummajeo",{"iron":12})
	Production.set_enabled(c.strategy_state,c.provinces,"sabi","iron_sword","백제",true,c.scenario_id,c.iron_supply_rules)
	Supply.ai(c.strategy_state,c.provinces,"baekje",stamp(),500,{},c.scenario_id,c.iron_supply_rules)
	var orders: Array=Supply.ensure(c.strategy_state).orders.values()
	check(orders.size()==1 and orders[0].cargo.iron==8 and orders[0].target=="sabi","AI supports actually valid material-blocked recipe after food priority")
	tick(); var old_gold: int=Economy.balance(c.strategy_state,"baekje")
	Production.process_all(c.strategy_state,c.provinces,stamp(),c.scenario_id,c.iron_supply_rules)
	check(c.strategy_state.city_inventory.sabi.sword==1 and c.strategy_state.city_inventory.sabi.iron==6 and Economy.balance(c.strategy_state,"baekje")==old_gold-10,"AI delivered iron pays exact production recipe")
	evidence.ai.append({"case":"material_support","orders":orders.duplicate(true),"decisions":Supply.ensure(c.strategy_state).ai_log.duplicate(true)})

func resource_balances() -> Dictionary:
	return {"grain":total("grain"),"iron":total("iron"),"sword":total("sword")}

func phase_cases() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	await events()
	var audit: Array=[]
	for n: int in range(9):
		var q: Dictionary=send("geumseong","geumgwan",{"grain":100})
		check(q.ok,"monthly balance freight accepted")
		var opening: Dictionary=resource_balances()
		c._advance_month(); c.officer_registry.clock_month=stamp()
		c.Industry.process(c.strategy_state,c.provinces,stamp())
		Supply.process(c.strategy_state,c.provinces,stamp())
		var arrived: Dictionary=resource_balances()
		c.process_monthly_commerce_income(); c.process_seasonal_harvest()
		var harvest: Dictionary=resource_balances()
		c.process_monthly_troop_food_upkeep()
		var upkeep_after: Dictionary=resource_balances()
		c.process_monthly_storage_losses()
		var storage: Dictionary=resource_balances()
		Production.process_all(c.strategy_state,c.provinces,stamp(),c.scenario_id,c.iron_supply_rules)
		var production: Dictionary=resource_balances()
		c.process_public_order(); c.process_pending_transfer_orders(); c.run_enemy_ai_turns()
		if c.month in [1,4,7,10]: c._process_strategy_season()
		var closing: Dictionary=resource_balances()
		var row: Dictionary={"year":c.year,"month":c.month,"opening":opening,"transport_delta":int(arrived.grain)-int(opening.grain),"harvest_and_events":int(harvest.grain)-int(arrived.grain),"upkeep":int(harvest.grain)-int(upkeep_after.grain),"storage_loss":int(upkeep_after.grain)-int(storage.grain),"production_grain_delta":int(production.grain)-int(storage.grain),"ai_and_other_delta":int(closing.grain)-int(production.grain),"closing":closing}
		check(row.transport_delta==0,"arrival keeps global city+transit conservation")
		check(int(opening.grain)+int(row.harvest_and_events)-int(row.upkeep)-int(row.storage_loss)+int(row.production_grain_delta)+int(row.ai_and_other_delta)==int(closing.grain),"whole month grain balance including autumn %d" % c.month)
		audit.append(row)
	evidence["phase_balances"]=audit
