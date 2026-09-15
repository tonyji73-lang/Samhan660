extends "res://tests/campaign_playability_audit_test.gd"
func _run() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	c._on_load_button_pressed(DIR+"victory-recovery.json"); settle_events()
	var city: String="hwanghae"; var moves: Array=[]; var appointed: Dictionary={}
	for p: Dictionary in c.officer_registry.people.values():
		if not p.active or not p.alive or p.faction_id!="silla" or p.location.is_empty(): continue
		var route: Array=officer_route(p.location,city)
		if route.is_empty(): continue
		for n: int in range(1,route.size()):
			var q: Dictionary=c.queue_province_transfer({"source_id":route[n-1],"target_id":route[n],"troops":0,"officer_ids":[p.officer_id]},true)
			moves.append(q); if not q.ok: break
			advance()
		appointed=Noble.appoint(c,"silla","governor",city,p.officer_id); break
	check(appointed.is_empty() and moves.is_empty(),"observed occupied enclave has no reachable existing officer; governorship remains vacant")
	var shipment: Dictionary={}
	for donor: String in Economy.city_ids(c.strategy_state,c.provinces):
		if donor==city: continue
		var q: Dictionary=Supply.quote(c.strategy_state,c.provinces,"silla",donor,city,{"grain":1000},stamp())
		if q.ok:
			shipment=Supply.start(c.strategy_state,c.provinces,"silla",donor,city,{"grain":1000},stamp()); break
	check(shipment.is_empty(),"observed conquest isolated by real counterattacks has no friendly land supply route")
	if shipment.get("ok",false):
		for n: int in range(12):
			if Supply.ensure(c.strategy_state).orders[shipment.order_id].status=="arrived": break
			advance()
		check(Supply.ensure(c.strategy_state).orders[shipment.order_id].status=="arrived","normal occupied city supply arrives")
	var out: Dictionary={"moves":moves,"appointed":appointed,"supply":shipment,"city":c.provinces[city].duplicate(true),"state":metrics("silla")}
	save("occupation-governed")
	# Loss/route test is explicitly a controlled ownership experiment on a normal
	# funded production save, not a claimed campaign battle victory.
	c._on_load_button_pressed(DIR+"politics-normal-baseline.json"); settle_events()
	var money: int=c.gold
	c.provinces.geumgwan.faction="백제"; Supply.capture(c.strategy_state,c.provinces,"geumgwan",stamp()); c.ProductionSystem.stop_on_capture(c.strategy_state,"geumgwan")
	check(Supply.route(c.strategy_state,c.provinces,"silla","geumgwan","geumseong").is_empty(),"lost origin is not friendly cargo source")
	var before: int=c.strategy_state.city_inventory.geumseong.sword
	advance()
	check(c.strategy_state.city_inventory.geumseong.sword>before,"existing inland common procurement survives regional city loss without grants")
	out["controlled_loss"]={"gold_before":money,"gold_after":c.gold,"sword_before":before,"sword_after":c.strategy_state.city_inventory.geumseong.sword}
	var file:=FileAccess.open(DIR+"recovery.json",FileAccess.WRITE); file.store_string(JSON.stringify(out,"\t")); file.close()
	print("PLAYABILITY RECOVERY: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)

func officer_route(source: String, target: String) -> Array:
	var queue: Array=[[source]]; var seen: Dictionary={source:true}
	while not queue.is_empty():
		var path: Array=queue.pop_front()
		if path.back()==target: return path
		for city: String in c.province_connections.get(path.back(),[]):
			if seen.has(city) or c.provinces[city].faction!=c.player_faction: continue
			seen[city]=true; var next: Array=path.duplicate(); next.append(city); queue.append(next)
	return []