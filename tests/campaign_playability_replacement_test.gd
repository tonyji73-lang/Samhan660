extends "res://tests/campaign_playability_audit_test.gd"
func _run() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	c._on_load_button_pressed("res://.godot/army-results/gui-battle.json"); settle_events(); seed(6322026)
	var opening: Dictionary=metrics("silla"); var r: Dictionary=c.request_recruitment("siljik",1000)
	check(r.ok,"normal defeat recovery recruits actual1000")
	if not r.ok: quit(1); return
	var id: String=r.unit_id
	for n: int in range(12):
		if int(c.strategy_state.city_inventory.geumgwan.sword)>=10: break
		advance()
	var sent: Dictionary=Supply.start(c.strategy_state,c.provinces,"silla","geumgwan","siljik",{"sword":10},stamp())
	check(sent.ok,"normal produced replacement weapons dispatched")
	if not sent.ok: quit(1); return
	for n: int in range(12):
		if Supply.ensure(c.strategy_state).orders[sent.order_id].status=="arrived": break
		advance()
	var issued: Dictionary=Army.equip(c.strategy_state,c.provinces,"silla",id,10,stamp()); check(issued.ok,"replacement stock arrives and is consumed")
	var trained: Dictionary=Army.train(c.strategy_state,c.provinces,"silla",id,"historical:001",stamp()); check(trained.ok,"actual replacement unit enters training")
	for n: int in range(6):
		if Army.training(c.strategy_state.unit_rosters[id])>=70: break
		advance()
	check(Army.training(c.strategy_state.unit_rosters[id])>=70 and Army.ratio(c.strategy_state.unit_rosters[id])==1,"normal replacement1000 fully prepared")
	var ready: Dictionary=c.strategy_state.unit_rosters[id].duplicate(true); save("defeat-replacement-ready")
	var battle: Dictionary=c.resolve_army_battle("siljik","haslla","silla")
	check(battle.ok,"fully prepared replacement participates in actual re-sortie")
	var out: Dictionary={"opening":opening,"recruitment":r,"shipment":Supply.ensure(c.strategy_state).orders[sent.order_id],"ready":ready,"battle":battle,"closing":metrics("silla")}
	save("defeat-replacement-battle")
	var units: Variant=canonical(c.strategy_state.unit_rosters); var gold: int=c.gold
	c._on_load_button_pressed(DIR+"defeat-replacement-battle.json")
	check(canonical(c.strategy_state.unit_rosters)==units and c.gold==gold,"replacement battle save restores exact army and treasury")
	var file:=FileAccess.open(DIR+"replacement.json",FileAccess.WRITE); file.store_string(JSON.stringify(out,"\t")); file.close()
	print("PLAYABILITY REPLACEMENT: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
