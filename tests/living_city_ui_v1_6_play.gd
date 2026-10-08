extends "res://tests/industry_assignment_gui_test.gd"
const Army = preload("res://army_readiness.gd")
var phase: String = "before"
const REVIEW = "res://tests/living_city_v1_6_review/"
func shot(label: String) -> void:
	await settle(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(REVIEW+phase+"_"+str(root.size.y)+"_"+label+".png")==OK,"capture "+label)
func pick(control: OptionButton, value: String) -> void:
	for n: int in range(control.item_count):
		if str(control.get_item_metadata(n))==value: control.select(n); control.item_selected.emit(n); return
func key(code: Key, shift: bool=false) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new(); event.keycode=code; event.shift_pressed=shift; event.pressed=down; root.push_input(event,true)
	await settle()
func focus_cycle(panel: Control, first: Control) -> void:
	await settle(); var controls: Array[Control]=[]; panel.UI._collect_focus(panel,controls)
	first.grab_focus()
	for n: int in range(controls.size()):
		await key(KEY_TAB)
		var focus: Control=root.gui_get_focus_owner()
		check(focus!=null and panel.is_ancestor_of(focus),"Tab stays in dialog")
	check(root.gui_get_focus_owner()==first,"Tab wraps full dialog")
	await key(KEY_TAB,true); await key(KEY_TAB)
	check(root.gui_get_focus_owner()==first,"Shift Tab reverses")
func interactions(uid: String) -> void:
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await settle()
		c._on_city_card_production_requested("geumseong"); var p: Node=c.production_overlay
		await focus_cycle(p,p.recipe_selector)
		p.start_button.grab_focus(); await key(KEY_SPACE)
		check(c.strategy_state.city_production.geumseong.iron_sword.enabled,"keyboard production reservation")
		p.stop_button.grab_focus(); await key(KEY_SPACE)
		check(not c.strategy_state.city_production.geumseong.iron_sword.enabled,"keyboard production stop")
		p.scroll_container.scroll_vertical=10000; await settle()
		check(p.scroll_container.scroll_vertical>0 and not p.scroll_container.get_h_scroll_bar().visible,"production internal scrolling")
		await shot("supply_scroll"); await escape(); check(not p.visible and not c.settlement_overlay.busy(),"production Esc restores map")
		c._on_city_card_production_requested("geumseong"); var logistics_before: Dictionary=state()
		await click(p.transport_button)
		check(c.supply_overlay.visible and c.supply_overlay.target()=="geumseong","supply link selects existing destination")
		check(state()==logistics_before,"opening transport changes no stock or money")
		await escape(); check(not c.supply_overlay.visible,"transport Esc closes")
		c.open_army("geumseong"); var a: Node=c.army_overlay; a.rebuild(uid)
		for mode: String in ["formation","training"]:
			a.show_mode(mode); await focus_cycle(a,a.mode_buttons[mode])
			check(a.close_button.get_global_rect().end.y<a.size.y,"footer within window")
		var selected_worker: String=c.get_city_officer_ids("geumseong")[0]; a.select_officer(selected_worker)
		await click(a.preparation_buttons.production)
		await click(p.transport_button); await escape()
		check(a.visible and a.id()==uid and a.officer()==selected_worker,"transport returns to original unit and officer")
		a.show_mode("formation")
		var roster_button: Button=a.unit_list.get_child(0).get_child(0).get_child(1)
		roster_button.grab_focus(); await key(KEY_SPACE)
		check(root.gui_get_focus_owner()!=null and a.unit_list.is_ancestor_of(root.gui_get_focus_owner()),"unit selection retains keyboard focus")
		a.rebuild(uid); a.show_mode("training")
		var before: Dictionary=state(); a.select_officer(c.get_city_officer_ids("geumseong")[0]); a.cancel_selection.pressed.emit(); await settle()
		check(state()==before,"officer selection and cancellation are pure preview")
		a.select_officer(c.get_city_officer_ids("geumseong")[0])
		for n: int in range(15):
			a.UI.card(a.candidate_list,c,a.officer(),false,"긴 이름·설명 경계 검사 ".repeat(8),"업무 충돌 사유 표시",func(): pass)
		await settle(); a.candidate_list.get_parent().scroll_vertical=10000; await settle()
		check(a.candidate_list.get_parent().scroll_vertical>0 and not a.candidate_list.get_parent().get_h_scroll_bar().visible,"many candidate cards scroll inside")
		await shot("many_candidates"); a.refresh()
		a.officers.clear(); a.refresh(); await settle()
		check(a.candidate_buttons.is_empty() and a.train_button.disabled,"empty candidates disable training")
		await shot("empty_candidates"); a.rebuild(uid)
		await escape(); check(not a.visible and not c.settlement_overlay.busy(),"army Esc restores map")
		c.open_industry("geumseong","research","swordsmithing"); var industry: Node=c.industry_overlay
		industry.officer_selector.select(1); industry.officer_selector.item_selected.emit(1)
		industry.execute_button.grab_focus(); await key(KEY_TAB); check(root.gui_get_focus_owner()!=null,"research Tab focus")
		await key(KEY_TAB,true); check(root.gui_get_focus_owner()==industry.execute_button,"research Shift Tab returns")
		var gold: int=c.gold; industry.execute_button.grab_focus(); await key(KEY_SPACE)
		check(not industry.job().is_empty() and c.gold==gold-200,"research keyboard confirm")
		industry.cancel_button.grab_focus(); await key(KEY_SPACE)
		check(industry.job().is_empty() and c.gold==gold,"research keyboard cancel")
		await escape(); check(not industry.visible,"research Esc closes")
		c.select_province("geumseong",false); c.open_domestic("agriculture"); await settle()
		var panorama: Control=c.domestic_overlay.find_child("CityPanorama",true,false)
		check(absf(panorama.size.x/c.domestic_overlay.size.x-0.65)<0.01,"domestic 65 percent preserved")
		await shot("domestic_unchanged"); await escape()
func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(REVIEW)
	if OS.get_cmdline_user_args().has("--after"): phase="after"
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await events()
	var uid: String=Army.at_city(c.strategy_state,"geumseong","silla")[0]
	var divided: Dictionary=Army.split(c.strategy_state,c.provinces,"silla",uid,1000)
	uid=divided.unit_id; Army.sync(c.strategy_state,c.provinces)
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await settle()
		c._on_city_card_production_requested("geumseong"); await shot("supply"); await escape()
		c.open_army("geumseong"); var a: Node=c.army_overlay; a.rebuild(uid)
		if a.has_method("show_mode"): a.show_mode("formation")
		await shot("formation")
		pick(a.officers,c.get_city_officer_ids("geumseong")[0])
		if a.has_method("show_mode"): a.show_mode("training")
		await shot("training"); await escape()
	if phase=="after": await interactions(uid)
	print("V1.6 VISUAL: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
