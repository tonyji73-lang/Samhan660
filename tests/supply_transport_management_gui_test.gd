extends "res://tests/supply_transport_gui_test.gd"

func _run() -> void:
	create_timer(180).timeout.connect(func(): push_error("SUPPLY MANAGEMENT GUI TIMEOUT"); quit(2))
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await events()
	c._on_load_button_pressed(GRESULTS+"gui-final.json"); await settle(); await events()
	var old_gold: int=c.gold
	var old_food: int=c.provinces.geumseong.food_stock
	var id: String=await ship("geumseong","geumgwan",{"grain":100},"cancel")
	c.open_supply("geumseong"); c.supply_overlay.rebuild(id)
	await click(c.supply_overlay.cancel_button)
	check(c.gold==old_gold and c.provinces.geumseong.food_stock==old_food,"UI first-move cancellation refunds exact money and goods")
	check(c.supply_overlay.cancel_button.disabled,"UI cannot cancel twice")
	await screen("canceled"); await escape()
	id=await ship("geumgwan","siljik",{"grain":100},"multi")
	await month_step()
	var order: Dictionary=Supply.ensure(c.strategy_state).orders[id]
	check(order.current=="geumseong" and order.moves==1,"actual multi-edge first arrival")
	c.open_supply("geumseong"); c.supply_overlay.rebuild(id)
	await select_destination(c.supply_overlay,"dalgubeol")
	check(c.supply_overlay.cancel_button.disabled and not c.supply_overlay.reroute_button.disabled,"UI after movement offers reroute not refund")
	old_gold=c.gold
	await screen("reroute_quote"); await click(c.supply_overlay.reroute_button)
	check(c.gold==old_gold-11 and order.path==["geumseong","dalgubeol"],"UI reroute costs additional eleven")
	Supply.process(c.strategy_state,c.provinces,c.year*12+c.month)
	check(order.current=="geumseong","UI reroute does not duplicate month movement")
	await screen("rerouted")
	old_food=c.provinces.geumseong.food_stock; old_gold=c.gold
	await click(c.supply_overlay.unload_button)
	check(order.status=="unloaded" and c.provinces.geumseong.food_stock==old_food+100 and c.gold==old_gold,"UI local unload only current city, no fee refund")
	await screen("unloaded"); await escape()
	# Render the native detail/log panel. Do not expose AI command controls.
	c._on_city_card_detail_requested("geummajeo"); await settle()
	await screen("ai_detail_native")
	var f:=FileAccess.open(GRESULTS+"management-evidence.json",FileAccess.WRITE); f.store_string(JSON.stringify({"orders":Supply.ensure(c.strategy_state).orders,"gold":c.gold,"checks":checks,"failures":failures},"\t")); f.close()
	print("SUPPLY MANAGEMENT GUI TESTS: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
