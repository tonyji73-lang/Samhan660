extends "res://qa/base_qa.gd"
var trace: Array=[]
func write_json(name: String,value: Variant) -> void:
	var f:=FileAccess.open(out.path_join(name),FileAccess.WRITE); f.store_string(JSON.stringify(value,"\t")); f.close()
func note(label: String,value: Variant) -> void:
	trace.append({"step":trace.size()+1,"label":label,"year":c.year if c else 0,"month":c.month if c else 0,"value":value}); write_json(phase+"-trace.json",trace)
func buttons(node: Node) -> Array[Button]:
	var result: Array[Button]=[]
	for child: Node in node.get_children():
		if child is Button and child.is_visible_in_tree(): result.append(child)
		result.append_array(buttons(child))
	return result
func window_key(window: Window,code: Key) -> void:
	window.grab_focus()
	for down: bool in [true,false]:
		var e:=InputEventKey.new(); e.keycode=code; e.physical_keycode=code; e.window_id=window.get_window_id(); e.pressed=down
		Input.parse_input_event(e)
		await get_tree().create_timer(0.15).timeout
	await settle()
func choose(option: OptionButton,index: int) -> void:
	await click(option); var popup: PopupMenu=option.get_popup(); popup.set_focused_item(index)
	await window_key(popup,KEY_ENTER)
	check(option.selected==index,"GUI option selection "+option.name)
func menu(id: int) -> void:
	await click(c.settlement_overlay.buttons.menu); var popup: PopupMenu=c.navigation_menu.get_popup()
	popup.set_focused_item(popup.get_item_index(id))
	await window_key(popup,KEY_ENTER); await settle()
func fill(spin: SpinBox,value: String) -> void:
	var edit: LineEdit=spin.get_line_edit(); await click(edit)
	for down: bool in [true,false]:
		var e:=InputEventKey.new(); e.keycode=KEY_A; e.ctrl_pressed=true; e.pressed=down; root.push_input(e,true)
	for character: String in value:
		var e:=InputEventKey.new(); e.unicode=character.unicode_at(0); e.pressed=true; root.push_input(e,true)
	await key(KEY_ENTER)
func settle_events() -> void:
	for n: int in range(80):
		var ep: Node=c.event_presentation
		if ep.active:
			if ep.awaiting_choice():
				var chosen: Button=null
				for b: Button in ep.view.choice_buttons.values():
					if b.is_visible_in_tree() and not b.disabled: chosen=b; break
				if chosen: await click(chosen)
				else: await click(ep.view.next_button)
			else: await click(ep.view.next_button)
			await get_tree().create_timer(0.2).timeout; continue
		if c.politics_overlay.visible:
			var court: Node=c.politics_overlay
			for index: int in range(1,court.choices.item_count):
				if str(court.choices.get_item_metadata(index))=="reject":
					await choose(court.choices,index); note("political response",court.preview.text)
					if not court.apply_button.disabled: await click(court.apply_button)
					break
			await key(KEY_ESCAPE)
			await settle(); continue
		if c.merit_overlay.visible: await click(c.merit_overlay.close_button)
		break
func start_game(faction: String) -> void:
	await click(get_tree().current_scene.new_game_button); await get_tree().create_timer(2).timeout
	var setup: Node=get_tree().current_scene
	for b: Button in buttons(setup):
		if b.text=="632년": await click(b); break
	for b: Button in buttons(setup):
		if b.text=={"silla":"신라","baekje":"백제","goguryeo":"고구려"}[faction]: await click(b); break
	await capture(phase+"-01-selection")
	for b: Button in buttons(setup):
		if b.text.ends_with("로 시작"): await click(b); break
	await get_tree().create_timer(3).timeout; c=get_tree().current_scene
	if not c.has_method("_on_end_turn_button_pressed"): check(false,"GUI start must enter campaign"); finish(1); return
	await settle_events()
	check(c.player_faction_id==faction and c.year==632,"GUI enters actual selected 632 faction")
	await capture(phase+"-02-city"); note("entry",{"faction":c.player_faction_id,"city":c.selected_province_id,"gold":c.gold})
func domestic() -> void:
	await click(c.settlement_overlay.buttons.domestic); var p: Node=c.domestic_overlay
	await click(p.choose_button); await capture(phase+"-03-officers")
	for b: Button in buttons(p.picker_cards):
		var id: String=str(b.get_meta("officer_id",""))
		if c.get_domestic_quote(p.city,p.kind,id).ok: await click(b); break
	if p.choosing_officer: await click(p.cancel_button)
	note("domestic quote",{"text":p.officer_summary.text,"enabled":not p.execute_button.disabled})
	if not p.execute_button.disabled: await click(p.execute_button)
	await capture(phase+"-04-development"); await key(KEY_ESCAPE)
func production_setup() -> void:
	await click(c.settlement_overlay.buttons.production); var p: Node=c.production_overlay; await capture(phase+"-05-production")
	note("production requirements",p.details.text)
	await click(p.manager_button); var i: Node=c.industry_overlay
	for n: int in range(1,i.officer_selector.item_count):
		await choose(i.officer_selector,n)
		if not i.execute_button.disabled: break
	note("production manager",i.execute_button.disabled)
	if not i.execute_button.disabled: await click(i.execute_button)
	await key(KEY_ESCAPE); await click(c.settlement_overlay.buttons.production)
	if not p.start_button.disabled: await click(p.start_button)
	if p.research_button.visible and not p.research_button.disabled:
		await click(p.research_button); await industry_execute(); await click(c.settlement_overlay.buttons.production)
	if p.building_button.visible and not p.building_button.disabled:
		await click(p.building_button); await industry_execute(); await click(c.settlement_overlay.buttons.production)
	if not p.transport_button.disabled:
		await click(p.transport_button); var s: Node=c.supply_overlay; await fill(s.amounts.grain,"100")
		note("transport quote",s.details.text); await capture(phase+"-06-transport")
		if not s.execute_button.disabled: await click(s.execute_button)
		await key(KEY_ESCAPE)
	if p.visible: await key(KEY_ESCAPE)
func industry_execute() -> void:
	var i: Node=c.industry_overlay
	for n: int in range(1,i.officer_selector.item_count):
		await choose(i.officer_selector,n)
		if not i.execute_button.disabled: break
	note("industry quote",{"kind":i.kind,"enabled":not i.execute_button.disabled})
	await capture(phase+"-industry-"+str(i.kind))
	if not i.execute_button.disabled: await click(i.execute_button)
	await key(KEY_ESCAPE)
func army_prepare() -> void:
	await click(c.settlement_overlay.buttons.army); var a: Node=c.army_overlay
	await click(a.mode_buttons.formation); await capture(phase+"-07-army")
	if not a.split_button.disabled: await fill(a.amount,"1000"); await click(a.split_button)
	for n: int in range(buttons(a.unit_list).size()):
		await click(buttons(a.unit_list)[n])
		if c.Army.units(c.strategy_state).get(a.id(),{}).get("troops",0)==1000: break
	note("equipment",a.equip_summary.text)
	if not a.equip_button.disabled: await click(a.equip_button)
	await click(a.mode_buttons.training)
	for n: int in range(a.candidate_buttons.size()):
		if not a.candidate_buttons[n].disabled: await click(a.candidate_buttons[n])
		if not a.train_button.disabled: break
	note("training",a.training_summary.text); await capture(phase+"-08-training")
	if not a.train_button.disabled: await click(a.train_button)
	await key(KEY_ESCAPE)
func diplomacy_and_court() -> void:
	await menu(5); await capture(phase+"-09-court"); await key(KEY_ESCAPE)
	await menu(4); var p: Node=c.diplomacy_overlay; await capture(phase+"-10-diplomacy")
	note("diplomacy",{"reason":p.blocked.text,"cost":p.cost.text})
	if not p.execute_button.disabled:
		await click(p.execute_button); await window_key(p.confirmation,KEY_ENTER)
	await key(KEY_ESCAPE)
func advance_month() -> void:
	var previous: int=c.year*12+c.month; var money: int=c.gold
	await click(c.settlement_overlay.buttons.month); await settle_events()
	if c.year*12+c.month==previous:
		await click(c.settlement_overlay.buttons.month); await settle_events()
	check(c.year*12+c.month==previous+1,"GUI advances one actual month")
	note("monthly report",{"gold_before":money,"gold_after":c.gold,"text":c.log_label.text,"jobs":c.strategy_state.domestic.jobs,"production":c.strategy_state.city_production})
	await capture(phase+"-month-"+str(c.year)+"-"+str(c.month))
func save_new() -> void:
	slot="user://ui_flow_v1_10_%s_%d_%d.json" % [phase,int(Time.get_unix_time_from_system()),OS.get_process_id()]
	check(not FileAccess.file_exists(slot) and c._on_save_button_pressed(slot),"new native save slot")
	write_json(phase+"-restart.json",{"slot":slot,"snapshot":snapshot()})
func report_checks() -> void:
	var state: Dictionary=snapshot()
	await click(c.settlement_overlay.buttons.report); var p: Node=c.flow_overlay
	check(p.visible and c.settlement_overlay.busy(),"report opens and blocks map")
	check(snapshot()==state,"report query leaves state unchanged")
	await capture("report-720")
	await choose(p.history,0); await capture("guide-720")
	var previous: Control=root.gui_get_focus_owner()
	await key(KEY_TAB); check(p.is_ancestor_of(root.gui_get_focus_owner()),"report Tab remains inside")
	for down: bool in [true,false]:
		var e:=InputEventKey.new(); e.keycode=KEY_TAB; e.shift_pressed=true; e.pressed=down; root.push_input(e,true)
	await settle(); check(root.gui_get_focus_owner()==previous,"report Shift Tab reverses focus")
	await key(KEY_ESCAPE); await settle()
	check(not p.visible and not c.settlement_overlay.busy() and not c.settlement_overlay.map.input_locked,"report Esc restores visible map input")
	await click(c.settlement_overlay.buttons.report); p.routes.production.grab_focus(); await key(KEY_ENTER)
	check(c.production_overlay.visible and c.production_overlay.province_id==c.selected_province_id,"report route uses current city")
	await capture("production-route-720"); await key(KEY_ESCAPE)
	root.size=Vector2i(1920,1080); await settle(); await click(c.settlement_overlay.buttons.report); await capture("report-1080")
	var scroll: ScrollContainer=p.body.get_parent()
	for n: int in range(15):
		var e:=InputEventMouseButton.new(); e.button_index=MOUSE_BUTTON_WHEEL_DOWN; e.pressed=true; e.position=scroll.get_global_rect().get_center(); root.push_input(e,true)
	await settle(); check(scroll.scroll_vertical>0,"report wheel scroll exposes complete records")
	await capture("report-scroll-1080"); await key(KEY_ESCAPE)
	root.size=Vector2i(1280,720)
func recovery() -> void:
	get_tree().current_scene._load_selected_game("user://living_city_v1_9_defeat_1790817154_40100.json"); await get_tree().create_timer(3).timeout; c=get_tree().current_scene; await settle_events()
	var popup: PopupMenu=c.navigation_menu.get_popup()
	for n: int in range(popup.item_count):
		if popup.get_item_text(n).contains("전투 결과"): await menu(popup.get_item_id(n)); break
	var result: Node=c.merit_overlay; check(result.visible,"existing defeat accessible through GUI battle history")
	await capture("recovery-result-720")
	await click(result.recovery.get_child(0)); var r: Node=c.recruitment_overlay
	note("recruitment",r.details.text); await capture("recovery-recruit-720")
	if not r.execute_button.disabled: await click(r.execute_button)
	await click(r.army_button); var a: Node=c.army_overlay
	await click(a.mode_buttons.formation); note("survivors and recruitment",a.unit_summary.text); await capture("recovery-units-720")
	var uid: String=a.id(); await click(a.preparation_buttons.production); await capture("recovery-equipment-supply-720")
	await click(c.production_overlay.preparation_back)
	check(a.visible and a.id()==uid,"equipment supply return preserves surviving unit")
	note("equipment and prerequisites",a.preparation.text)
	await key(KEY_ESCAPE); await army_prepare()
	await click(c.settlement_overlay.buttons.army); await click(a.mode_buttons.formation); await click(a.attack_button)
	var map: Control=c.settlement_overlay.map
	var point: Vector2=map.get_global_transform_with_canvas()*map.anchor("ungjin")
	for down: bool in [true,false]:
		var e:=InputEventMouseButton.new(); e.position=point; e.button_index=MOUSE_BUTTON_LEFT; e.pressed=down; root.push_input(e,true)
	await settle(); check(c.selected_province_id=="ungjin","actual map click selects adjacent enemy")
	await capture("recovery-target-720")
	if phase=="recovery_before":
		note("missing sortie confirmation route",{"selected":c.selected_province_id,"source":c.attack_source_id,"buttons":c.settlement_overlay.buttons.keys()}); evidence={"trace":trace}; finish(); return
	var before_preview: Dictionary=snapshot()
	check(not Rect2(c.settlement_overlay.attack_bar.position,c.settlement_overlay.attack_bar.size).intersects(Rect2(c.settlement_overlay.buttons.zoom_out.position,c.settlement_overlay.buttons.zoom_out.size)),"sortie route bar does not overlap map zoom")
	root.size=Vector2i(1920,1080); await settle(); await capture("recovery-target-1080"); root.size=Vector2i(1280,720); await settle()
	c.settlement_overlay.buttons.attack_preview.grab_focus(); await key(KEY_ENTER)
	check(c.sortie_overlay.visible,"recovery reaches actual sortie readiness")
	await capture("recovery-sortie-720"); note("sortie quote",c.sortie_overlay.quote)
	await key(KEY_ESCAPE); check(snapshot()==before_preview,"sortie preview and cancel preserve all resources")
	await click(c.settlement_overlay.buttons.army); await click(a.mode_buttons.formation); await click(a.attack_button); await key(KEY_ESCAPE)
	check(c.attack_source_id.is_empty(),"map preparation Esc clears target mode")
	root.size=Vector2i(1920,1080); await click(c.settlement_overlay.buttons.army); await capture("recovery-army-1080"); await key(KEY_ESCAPE)
	await save_new(); evidence={"trace":trace}; finish()
func dpi_live() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("after-restart.json")))
	get_tree().current_scene._load_selected_game(data.slot); await get_tree().create_timer(3).timeout; c=get_tree().current_scene; await settle_events()
	await click(c.settlement_overlay.buttons.report)
	for n: int in range(2400):
		var p: Node=c.flow_overlay; var controls: Dictionary={}
		for id: String in p.routes:
			var center: Vector2=p.routes[id].get_global_transform_with_canvas()*(p.routes[id].size/2); controls[id]={"x":center.x/root.size.x,"y":center.y/root.size.y}
		var b: Button=c.settlement_overlay.buttons.report; var center: Vector2=b.get_global_transform_with_canvas()*(b.size/2); controls.report={"x":center.x/root.size.x,"y":center.y/root.size.y}
		write_json("dpi-live.json",{"report":p.visible,"production":c.production_overlay.visible,"busy":c.settlement_overlay.busy(),"scroll":p.body.get_parent().scroll_vertical,"controls":controls,"focus":str(root.gui_get_focus_owner())})
		await get_tree().create_timer(0.25).timeout
	finish()
func run() -> void:
	await get_tree().create_timer(2).timeout; root.size=Vector2i(1280,720); root.always_on_top=true
	if phase in ["recovery","recovery_before"]: await recovery(); return
	if phase=="recovery_complete":
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join("recovery-restart.json")))
		get_tree().current_scene._load_selected_game(data.slot); await get_tree().create_timer(3).timeout; c=get_tree().current_scene; await settle_events()
		var id: String=""
		for job: Dictionary in c.strategy_state.domestic.jobs.values():
			if job.kind=="training" and job.get("faction_id","")=="silla" and job.status=="pending": id=job.id; break
		check(not id.is_empty(),"normal recovery resumes pending training")
		if id.is_empty(): finish(1); return
		await advance_month(); await advance_month()
		var job: Dictionary=c.strategy_state.domestic.jobs[id]
		check(job.status=="completed" and int(job.cost_paid)==100,"actual two-month training completes with quoted total cost")
		await click(c.settlement_overlay.buttons.army); var a: Node=c.army_overlay
		for b: Button in buttons(a.unit_list):
			if b.text.contains(str(job.unit_id)): await click(b); break
		await click(a.mode_buttons.training); await capture("recovery-training-completed-720"); note("completed training",{"job":job,"unit":c.strategy_state.unit_rosters[job.unit_id],"summary":a.training_summary.text})
		await key(KEY_ESCAPE); await save_new(); evidence={"trace":trace}; finish(); return
	if phase=="dpi": await dpi_live(); return
	if phase in ["reload","after_reload","recovery_reload"]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.path_join({"reload":"silla","after_reload":"after","recovery_reload":"recovery"}[phase]+"-restart.json")))
		get_tree().current_scene._load_selected_game(data.slot); await get_tree().create_timer(3).timeout; c=get_tree().current_scene
		check(snapshot()==data.snapshot,"new process restores exact campaign"); await capture("restored"); finish(); return
	if phase=="after":
		await start_game("silla"); await click(c.settlement_overlay.buttons.report); await capture("guide-start-720"); await key(KEY_ESCAPE)
		await domestic(); await production_setup(); await diplomacy_and_court(); await advance_month()
		await report_checks(); await army_prepare(); await advance_month(); await save_new(); evidence={"trace":trace}; finish(); return
	await start_game(phase); await domestic(); await production_setup(); await army_prepare(); await diplomacy_and_court()
	for month_index: int in range(12 if phase=="silla" else 3): await advance_month()
	if phase=="silla" and c.get("flow_overlay")!=null: await report_checks()
	await save_new(); evidence={"trace":trace}; finish()
