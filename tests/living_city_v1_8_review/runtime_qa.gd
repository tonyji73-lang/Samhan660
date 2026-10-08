extends "base_qa.gd"
var p: Node
func write_json(name: String,value: Variant) -> void:
	var f:=FileAccess.open(out.path_join(name),FileAccess.WRITE); f.store_string(JSON.stringify(value,"\t")); f.close()
func keyboard(code: Key,shift: bool=false) -> void:
	for down: bool in [true,false]:
		var e:=InputEventKey.new(); e.keycode=code; e.shift_pressed=shift; e.pressed=down; root.push_input(e,true)
	await settle()
func popup_space(button: Button) -> void:
	button.grab_focus()
	for down: bool in [true,false]:
		var e:=InputEventKey.new(); e.keycode=KEY_SPACE; e.pressed=down; p.confirmation.push_input(e,true)
	await settle()
func open_panel() -> void:
	c._open_diplomacy(); await settle(); p=c.diplomacy_overlay
func select_action(action: String) -> void: p.selected_action=action; p.refresh()
func relation() -> Dictionary: return c.strategy.get_relation(c.strategy_state,"신라","백제")
func trade_paid() -> int:
	var amount:=0
	for row: Dictionary in c.strategy_state.faction_economy.entries:
		if row.faction_id=="silla" and row.reason=="trade": amount+=int(row.amount)
	return amount
func normal_month() -> void:
	c._close_diplomacy()
	if c.politics_overlay.visible: c.politics_overlay.hide()
	var pending: Dictionary=c.officer_registry.politics.pending
	if not pending.is_empty(): c.Noble.resolve(c,pending.occurrence_id,"reject")
	await month()
func take_pair(label: String) -> void:
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]: root.size=size; await capture(label+"-"+str(size.y))
func confirm_action() -> void:
	var model: Dictionary=p.model.duplicate(true); var before: Dictionary=snapshot()
	p.execute_button.grab_focus(); await key(KEY_SPACE)
	check(p.confirmation.visible and snapshot()==before,"confirmation opens without state changes")
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size; p.confirmation.popup_centered(Vector2i(780,420)); await capture("confirm-"+p.selected_action+"-"+str(size.y))
	check(p.confirmation.get_ok_button().size.x>=240,"confirmation button retains readable width")
	await popup_space(p.confirmation.get_ok_button()); check(not p.confirmation.visible,"keyboard confirms modal")
	check(c.gold==int(before.gold)-int(model.result.get("gold_cost",0)),"exact quoted immediate cost")
	check(relation()==model.after,"actual result equals existing command preview")
	var after: Dictionary=snapshot(); p.confirmation.confirmed.emit(); check(after==snapshot(),"repeat confirmation has no effect")
func save_receipt(name: String) -> void:
	slot="user://living_city_v1_8_%d_%d_%s.json" % [int(Time.get_unix_time_from_system()),Time.get_ticks_usec(),name]
	check(not FileAccess.file_exists(slot),"new default user slot")
	if FileAccess.file_exists(slot): finish(2); return
	check(c._on_save_button_pressed(slot),"save normal diplomacy state")
	write_json(name+"-restart.json",{"slot":slot,"snapshot":snapshot(),"target":p.selected_target_id,"envoy":p.selected_envoy_name,"trade_paid":trade_paid()})
func reload_receipt(name: String) -> Dictionary:
	var receipt: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join(name+"-restart.json"))); slot=receipt.slot
	get_tree().current_scene._load_selected_game(slot); await get_tree().create_timer(3).timeout; c=get_tree().current_scene; await settle()
	check(snapshot()==receipt.snapshot,"new process restores full campaign "+name)
	await events(); await open_panel(); p.selected_target_id=receipt.target; p.selected_envoy_name=receipt.envoy; p.refresh(); return receipt
func visuals() -> void:
	var before: Dictionary=snapshot()
	for size: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=size; await capture("diplomacy-"+str(size.y))
		check(p.ruler.texture!=null and p.candidate_buttons.size()>0,"ruler/envoy portrait and candidates")
		p.close_button.grab_focus(); await keyboard(KEY_TAB); check(p.is_ancestor_of(root.gui_get_focus_owner()) and root.gui_get_focus_owner()!=p.close_button,"Tab stays in modal")
		await keyboard(KEY_TAB,true); check(root.gui_get_focus_owner()==p.close_button,"Shift Tab reverses")
		var id: String=p.target_buttons.keys()[0]; p.target_buttons[id].grab_focus(); await key(KEY_SPACE); check(p.selected_target_id==id,"keyboard nation selection")
		p.candidate_list.get_parent().scroll_vertical=10000; await settle(); check(p.candidate_list.get_parent().scroll_vertical>0,"candidate list scrolls internally"); await capture("envoy-scroll-"+str(size.y))
		await key(KEY_ESCAPE); check(not p.visible and not c.end_turn_button.disabled,"Esc restores month button")
		c.select_province("geumseong",false); check(c.selected_province_id=="geumseong","map selection restored")
		await open_panel()
	check(snapshot()==before,"target/envoy browsing changes no game state")
func boundary_checks() -> void:
	var path: String=out.path_join("boundary-baseline.json"); c._on_save_button_pressed(path)
	var worker: String=p.selected_envoy_name
	var job: Dictionary=c.Domestic.start(c.strategy_state,c.provinces,c.player_faction,"geumseong","agriculture",worker,c.gold,c.year*12+c.month)
	check(job.ok,"normal domestic job used for conflict")
	p.refresh(); check(p.candidate_buttons[worker].disabled and not p.model.quote.ok,"busy envoy disabled with existing reason"); await capture("envoy-conflict")
	c._on_load_button_pressed(path); await settle(); await open_panel()
	# Explicit boundary fixture, never used as the normal campaign/export receipt.
	c.gold=199; p.refresh(); var before: Dictionary=snapshot()
	check(p.execute_button.disabled and not p.blocked.text.is_empty(),"insufficient gold explained near confirmation")
	p._act("gift"); check(snapshot()==before and not p.confirmation.visible,"insufficient gold cannot execute")
	await capture("insufficient-gold")
	c._on_load_button_pressed(path); await settle(); await open_panel()
	worker=p.selected_envoy_name; c.officer_registry.people[worker].name="긴 이름 표시 검수 ".repeat(10); p.refresh()
	check(p.candidate_buttons[worker].tooltip_text==c.get_officer(worker).name,"full long name available as tooltip")
	p._act("gift"); await capture("long-name-confirm"); p.confirmation.hide(); p.confirmation.canceled.emit()
	for n: int in range(16): p.button(p.target_list,"긴 국가 목록 표시 검수 ".repeat(4),func(): pass)
	p.target_list.get_parent().scroll_vertical=10000; await settle(); await capture("long-list")
	c.officer_registry.people={}; p.refresh(); check(p.candidate_buttons.is_empty() and p.execute_button.disabled,"empty candidate list safe"); await capture("empty-envoys")
	c._on_load_button_pressed(path); await settle(); await open_panel()
func prepare() -> void:
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":"silla_equilibrium_632","scenario_year":632,"scenario_season":"spring"})
	get_tree().change_scene_to_file("res://campaign_main.tscn"); await get_tree().create_timer(3).timeout; c=get_tree().current_scene; await events(); await open_panel()
	p.selected_target_id="baekje"; select_action("gift"); await visuals(); await boundary_checks()
	p.selected_target_id="baekje"; select_action("gift"); var before: Dictionary=snapshot()
	p._act("gift"); p.confirmation.hide(); p.confirmation.canceled.emit(); check(snapshot()==before,"confirmation cancel preserves state")
	await confirm_action(); check(relation().value==12,"normal gift relationship plus twelve")
	var after: Dictionary=snapshot(); var duplicate: Dictionary=c.request_diplomatic_action("baekje","gift",p.selected_envoy_name)
	check(not duplicate.executed and snapshot()==after,"monthly limit prevents repeated gift")
	await normal_month(); await open_panel(); p.selected_target_id="baekje"; select_action("trade_pact")
	for attempt: int in range(8):
		if relation().treaties.has("통상 조약"): break
		if relation().value<10: select_action("gift"); await confirm_action(); await normal_month(); await open_panel(); select_action("trade_pact")
		for envoy: Dictionary in c.get_diplomacy_envoys():
			p.selected_envoy_name=envoy.officer_id; p.refresh()
			if p.model.result.get("ok",false): break
		check(p.model.quote.ok,"normal trade negotiation available")
		await take_pair("trade-quote"); await confirm_action()
		if not relation().treaties.has("통상 조약"): await normal_month(); await open_panel(); select_action("trade_pact")
	check(relation().treaties.has("통상 조약"),"normal agreement concluded")
	# Existing backend route command with real capital markets. No route UI is added.
	var route: Dictionary=c.strategy.open_trade_route(c.strategy_state,"신라","백제","geumseong","sabi","물산")
	check(route.ok,"existing route backend accepts actual markets and agreement")
	p.refresh(); check(p.model.trade_before.income>0,"conditional trade preview uses existing settlement")
	await take_pair("agreement"); await save_receipt("agreement"); evidence={"relation":relation(),"gold":c.gold,"trade":p.model.trade_before}; finish()
func reload_agreement() -> void:
	await reload_receipt("agreement"); check(relation().treaties.has("통상 조약"),"agreement restored")
	var before: Dictionary=snapshot(); c.request_diplomatic_action("baekje","trade_pact",p.selected_envoy_name); check(snapshot()==before,"restore does not bypass monthly/duplicate pact guard")
	var initial_paid: int=trade_paid(); var saw_ordinary:=false
	for n: int in range(3):
		await normal_month()
		if c.month in [1,4,7,10]: break
		saw_ordinary=true; check(trade_paid()==initial_paid,"ordinary month has no invented recurring treaty income")
	check(saw_ordinary and trade_paid()>initial_paid,"season boundary pays existing route income")
	await open_panel(); select_action("cancel_trade_pact"); await take_pair("cancel-quote")
	check(p.model.trade_after.income==0,"cancellation preview stops route settlement")
	before=snapshot(); p._act("cancel_trade_pact"); p.confirmation.hide(); p.confirmation.canceled.emit(); check(snapshot()==before,"cancel agreement confirmation leaves pact intact")
	await confirm_action(); check(not relation().treaties.has("통상 조약") and not c.strategy_state.trade_routes.is_empty(),"cancel removes pact but preserves route record")
	await save_receipt("cancelled"); evidence={"trade_income":trade_paid()-initial_paid,"relation":relation()}; finish()
func reload_cancelled() -> void:
	await reload_receipt("cancelled"); check(not relation().treaties.has("통상 조약"),"cancelled pact remains cancelled after process restart")
	var before: Dictionary=snapshot(); c.request_diplomatic_action("baekje","cancel_trade_pact",p.selected_envoy_name); check(snapshot()==before,"repeated cancellation does not change gold or relationship")
	var income: int=trade_paid()
	for n: int in range(3): await normal_month()
	check(trade_paid()==income,"cancelled route stops income through next seasonal settlement")
	await open_panel(); await take_pair("cancel-restored"); evidence={"relation":relation(),"gold":c.gold,"trade_income":trade_paid()-income}; finish()
func run() -> void:
	await get_tree().create_timer(3).timeout
	if not OS.has_feature("editor"): resources()
	if phase=="prepare": await prepare()
	elif phase=="reload": await reload_agreement()
	elif phase=="cancel-reload": await reload_cancelled()
