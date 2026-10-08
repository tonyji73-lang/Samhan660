extends "res://tests/industry_assignment_gui_test.gd"
const REVIEW="res://tests/living_city_v1_7_review/"
var rows: Array=[]
func key(code: Key,shift: bool=false) -> void:
	for down: bool in [true,false]:
		var e:=InputEventKey.new(); e.keycode=code; e.shift_pressed=shift; e.pressed=down; root.push_input(e,true)
	await settle()
func shot(label: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(REVIEW+label+"-"+str(root.size.y)+".png")==OK,"capture "+label)
func pick(b: OptionButton,id: String) -> void:
	for n: int in range(b.item_count):
		if str(b.get_item_metadata(n))==id: b.select(n); b.item_selected.emit(n); return
func snapshot() -> Dictionary:
	return JSON.parse_string(JSON.stringify({"state":c.OfficerRegistry.export_strategy(c.strategy_state),"provinces":c.provinces,"gold":c.gold,"month":c.year*12+c.month}))
func campaign_start(faction: String="silla",scenario: int=0) -> void:
	root.set_meta("new_game_settings",{"faction":faction,"play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[scenario].id,"scenario_year":Scenarios.SCENARIOS[scenario].year,"scenario_season":Scenarios.SCENARIOS[scenario].season})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await events()
func normal_load() -> void:
	c._on_load_button_pressed(REVIEW+"normal-concentrated.json"); await settle(); await events()
func focus(panel: Control) -> void:
	panel.UI.wire_focus(panel); panel.close_button.grab_focus(); await key(KEY_TAB)
	check(root.gui_get_focus_owner()!=panel.close_button and panel.is_ancestor_of(root.gui_get_focus_owner()),"Tab stays in court")
	await key(KEY_TAB,true); check(root.gui_get_focus_owner()==panel.close_button,"Shift Tab returns")
func match_model(m: Dictionary,label: String) -> void:
	check(c.gold==m.gold_after,"preview gold equals actual "+label)
	check(JSON.stringify(c.officer_registry.politics)==JSON.stringify(m.state.officer_registry.politics),"preview complete politics equals actual "+label)
	check(JSON.stringify(c.strategy_state.unit_rosters)==JSON.stringify(m.state.unit_rosters),"preview units equal actual "+label)
func month_real() -> void:
	c.politics_overlay.hide(); if c.merit_overlay.visible: c.merit_overlay.hide()
	var pending: Dictionary=c.officer_registry.politics.pending
	if not pending.is_empty(): c.Noble.resolve(c,pending.occurrence_id,"reject")
	var before: int=c.year*12+c.month; await click(c.settlement_overlay.buttons.month); await events()
	check(c.year*12+c.month==before+1,"real monthly processing")
func _run() -> void:
	create_timer(600).timeout.connect(func(): push_error("V1.7 TIMEOUT"); quit(2))
	await campaign_start()
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; var before: Dictionary=snapshot(); c.open_politics(); var p: Node=c.politics_overlay; await settle()
		check(p.group_buttons.size()==3,"actual Silla groups")
		await shot("after-court"); await focus(p)
		for gid: String in p.group_buttons.keys():
			p.group_buttons[gid].grab_focus(); await key(KEY_SPACE); check(p.selected_group==gid,"keyboard group selection "+gid)
		check(snapshot()==before,"group selection and opening are read-only")
		p.member_list.get_parent().get_parent().scroll_vertical=10000; await settle(); check(p.member_list.get_parent().get_parent().scroll_vertical>0,"group detail scrolls internally"); await shot("group-details")
		for n: int in range(12): p.button(p.group_list,"표시 경계 검사 · 긴 집단 이름 ".repeat(4),func(): pass)
		p.close_button.grab_focus(); await settle(); p.group_list.get_parent().scroll_vertical=10000; await settle()
		check(p.group_list.get_parent().scroll_vertical>0 and p.close_button.get_global_rect().end.y<=p.size.y,"many long entries scroll with close visible")
		check(snapshot()==before,"display-only long list fixture leaves data unchanged"); await shot("long-list"); p.refresh()
		await key(KEY_ESCAPE); check(not p.visible and not c.settlement_overlay.busy(),"Esc restores settlement input")
		c.select_province("geumseong",false); c.open_domestic("agriculture"); await settle()
		check(absf(c.domestic_overlay.find_child("CityPanorama",true,false).size.x/c.domestic_overlay.size.x-0.65)<0.01,"domestic 65 percent preserved"); await key(KEY_ESCAPE)
	# Same normal-play save for each outcome. No resource/authority injection.
	for kind: String in ["governor","commander"]:
		for choice: String in ["compensate","wait","force"]:
			await normal_load()
			var target: String="geumseong"
			if kind=="commander":
				for uid: String in c.Army.at_city(c.strategy_state,"geumseong","silla"):
					if c.strategy_state.unit_rosters[uid].commander_id=="historical:004": target=uid; break
			var offer: Dictionary=c.Power.intercept(c,{"kind":kind,"target":target,"officer_id":"historical:001","faction_id":"silla"}); await settle()
			check(offer.has("negotiation_id"),"normal authority offer "+kind)
			if not offer.has("negotiation_id"): continue
			var id: String=offer.negotiation_id; var p: Node=c.politics_overlay
			check(p.visible and not c.power_dialog.visible,"existing command routes to new court")
			var before: Dictionary=snapshot(); pick(p.choices,choice); await settle(); var expected: Dictionary=p.model.duplicate(true)
			check(expected.ok and snapshot()==before,"choice preview is isolated "+kind+choice)
			p.cancel_button.grab_focus(); await key(KEY_SPACE); check(snapshot()==before and p.apply_button.disabled,"keyboard cancel leaves real state")
			pick(p.choices,choice)
			for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]: root.size=resolution; await shot(kind+"-"+choice+"-preview")
			p.apply_button.grab_focus(); await key(KEY_SPACE); match_model(expected,kind+choice)
			var applied: Dictionary=snapshot(); p.execute(); check(snapshot()==applied,"double confirmation not applied twice")
			var path: String=REVIEW+kind+"-"+choice+"-save.json"
			check(c._on_save_button_pressed(path),"new test save "+kind+choice); c._on_load_button_pressed(path); await settle()
			check(snapshot()==applied,"pending/effects restore exactly "+kind+choice)
			c.show_power_transfer(id); await settle(); await shot(kind+"-"+choice+"-result")
			if choice=="wait":
				for n: int in range(int(c.Power.records(c.strategy_state).requests[id].months)): await month_real()
				check(c.Power.records(c.strategy_state).requests[id].status=="completed","waiting completes by real month "+kind)
			elif choice=="force":
				for n: int in range(2 if kind=="governor" else 1): await month_real()
				check(c.Power.city_factor(c.strategy_state,"geumseong")==1.0 if kind=="governor" else c.Power.unit_reason(c.strategy_state,target).is_empty(),"force disruption expires "+kind)
			rows.append({"kind":kind,"choice":choice,"gold_before":expected.gold_before,"gold_after":expected.gold_after,"reactions":expected.reactions})
	# Propose from normal achieved influence, without editing dates or attributes.
	await campaign_start("silla",1)
	check(c.Noble.appoint(c,"silla","governor","geumseong","historical:004").ok,"642 normal governor appointment")
	var main: String=c.Army.at_city(c.strategy_state,"geumseong","silla")[0]
	check(c.Army.appoint(c.strategy_state,c.provinces,"silla",main,"historical:004").ok,"642 normal commander appointment")
	var pending: Dictionary=c.Noble.propose(c)
	check(not pending.is_empty(),"normal gameplay demand generated")
	if not pending.is_empty():
		var path: String=REVIEW+"demand-start.json"; c._on_save_button_pressed(path)
		for choice: String in ["gift","reject","accept"]:
			c._on_load_button_pressed(path); await settle(); await events(); c._show_court_demand(); await settle()
			var p: Node=c.politics_overlay; var before: Dictionary=snapshot(); pick(p.choices,choice); await settle(); var expected: Dictionary=p.model.duplicate(true)
			check(expected.ok and before==snapshot(),"demand preview pure "+choice)
			await shot("demand-"+choice); await click(p.apply_button); match_model(expected,"demand-"+choice)
			var after: Dictionary=snapshot(); c.Noble.resolve(c,pending.occurrence_id,choice); check(after==snapshot(),"demand response duplicate safe")
	for faction: String in ["baekje","goguryeo"]:
		await campaign_start(faction); c.open_politics(); await settle(); var p: Node=c.politics_overlay
		check(p.group_buttons.is_empty() and p.details.text.contains("정의된 정치 집단이 없습니다"),"no invented groups "+faction)
		check(p.member_list.get_child_count()>0 and p.ruler.texture!=null,"actual faction people and ruler "+faction)
		await shot(faction+"-court"); await key(KEY_ESCAPE)
	var f:=FileAccess.open(REVIEW+"result.json",FileAccess.WRITE); f.store_string(JSON.stringify({"checks":checks,"failures":failures,"responses":rows},"\t")); f.close()
	print("V1.7 GUI: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
