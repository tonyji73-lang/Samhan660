extends "base_qa.gd"
const Core=preload("res://noble_politics.gd")
var cases: Array=[]

func write_json(name: String,value: Variant) -> void:
	var f:=FileAccess.open(out.path_join(name),FileAccess.WRITE); f.store_string(JSON.stringify(value,"\t")); f.close()
func read_json(name: String) -> Variant: return JSON.parse_string(FileAccess.get_file_as_string(out.path_join(name)))
func load_slot(path: String) -> void:
	if c==null: get_tree().current_scene._load_selected_game(path); await get_tree().create_timer(3).timeout; c=get_tree().current_scene
	else: c._on_load_button_pressed(path)
	await settle(); await events()
func new_campaign(scenario: String,year: int) -> void:
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":scenario,"scenario_year":year,"scenario_season":"autumn" if year==642 else "spring"})
	get_tree().change_scene_to_file("res://campaign_main.tscn"); await get_tree().create_timer(3).timeout; c=get_tree().current_scene; await events()
func keyboard(code: Key,shift: bool=false) -> void:
	for down: bool in [true,false]:
		var e:=InputEventKey.new(); e.keycode=code; e.shift_pressed=shift; e.pressed=down; root.push_input(e,true)
	await settle()
func choice_ids() -> Array:
	var ids: Array=[]; var p: Node=c.politics_overlay
	for n: int in range(p.choices.item_count): ids.append(p.choices.get_item_metadata(n))
	return ids
func political() -> Dictionary:
	return JSON.parse_string(JSON.stringify({"gold":c.gold,"influence":Core.influence(c.strategy_state,c.provinces,"silla"),"politics":c.officer_registry.politics,"people":c.officer_registry.people,"power":c.Power.records(c.strategy_state),"units":c.strategy_state.unit_rosters,"jobs":c.strategy_state.domestic.jobs}))
func comparable(value: Dictionary) -> Dictionary:
	var copy: Dictionary=value.duplicate(true)
	# Influence bases are membership sets; JSON restore can change dictionary traversal order.
	# All values and every other array (history, jobs, etc.) remain exact comparisons.
	for group: Dictionary in copy.influence.groups.values(): group.cities.sort(); group.units.sort()
	return copy
func save_case(label: String,kind: String,id: String,target: String,choice: String="") -> Dictionary:
	slot="user://windows_export_v1_7_1_%s_%s_%s.json" % [str(int(Time.get_unix_time_from_system())),str(Time.get_ticks_usec()),label]
	check(not FileAccess.file_exists(slot),"new slot preserves all existing saves "+label)
	if FileAccess.file_exists(slot): push_error("Refusing to overwrite existing slot"); finish(2); return {}
	check(c._on_save_button_pressed(slot),"default user path save "+label)
	return {"kind":kind,"id":id,"target":target,"choice":choice,"slot":slot,"snapshot":snapshot(),"political":political(),"choices":choice_ids()}
func show_case(row: Dictionary) -> void:
	if row.kind=="demand": c._show_court_demand()
	else: c.show_power_transfer(row.id)
	await settle()
func restored(row: Dictionary) -> void:
	await load_slot(row.slot)
	check(snapshot()==row.snapshot,"new EXE process restores full campaign "+row.kind+row.choice)
	var actual: Dictionary=political()
	if comparable(actual)!=comparable(row.political): write_json("mismatch-"+row.kind+row.choice+".json",{"expected":row.political,"actual":actual})
	check(comparable(actual)==comparable(row.political),"gold loyalty cooperation influence period units work restored "+row.kind+row.choice)
	await show_case(row)
func court_visuals(label: String) -> void:
	var p: Node=c.politics_overlay; var before: Dictionary=snapshot()
	for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]:
		root.size=resolution; await settle(); await capture(label+"-"+str(resolution.y))
		check(p.ruler.texture!=null and p.member_list.get_child_count()>0,"portrait/member assets exported")
		p.close_button.grab_focus(); await keyboard(KEY_TAB)
		check(root.gui_get_focus_owner()!=p.close_button and p.is_ancestor_of(root.gui_get_focus_owner()),"Tab stays in court")
		await keyboard(KEY_TAB,true); check(root.gui_get_focus_owner()==p.close_button,"Shift Tab reverses")
		for gid: String in p.group_buttons:
			p.group_buttons[gid].grab_focus(); await key(KEY_SPACE); check(p.selected_group==gid,"keyboard group selection "+gid)
		p.member_list.get_parent().get_parent().scroll_vertical=10000; await settle(); await capture(label+"-details-"+str(resolution.y))
		check(p.member_list.get_parent().get_parent().scroll_vertical>0,"group detail scroll")
		if p.history_people.item_count>1: p.history_people.select(1); p.refresh(); await capture(label+"-person-"+str(resolution.y))
		await key(KEY_ESCAPE); check(not c.settlement_overlay.busy(),"Esc restores map input")
		c.select_province("geumseong",false); c.open_politics(); await settle()
	check(before==snapshot(),"all group/person previews are read only")
func prepare() -> void:
	await new_campaign("silla_equilibrium_632",632); c.open_politics(); await settle(); await court_visuals("court")
	for kind: String in ["governor","commander"]:
		await load_slot(out.path_join("normal-concentrated.json")); var target: String="geumseong"
		if kind=="commander":
			for uid: String in c.Army.at_city(c.strategy_state,"geumseong","silla"):
				if c.strategy_state.unit_rosters[uid].commander_id=="historical:004": target=uid; break
		var offer: Dictionary=c.Power.intercept(c,{"kind":kind,"target":target,"officer_id":"historical:001","faction_id":"silla"}); await settle()
		check(offer.has("negotiation_id"),"normal achieved authority offers "+kind)
		cases.append(save_case("pending-"+kind,kind,offer.negotiation_id,target))
		await capture("pending-"+kind)
	# Fresh normal 642 campaign: existing appointments produce the demand threshold.
	await new_campaign("goguryeo_coup_642",642)
	check(c.Noble.appoint(c,"silla","governor","geumseong","historical:004").ok,"normal 642 governor")
	var uid: String=c.Army.at_city(c.strategy_state,"geumseong","silla")[0]
	check(c.Army.appoint(c.strategy_state,c.provinces,"silla",uid,"historical:004").ok,"normal 642 commander")
	var pending: Dictionary=c.Noble.propose(c); check(not pending.is_empty(),"normal demand generated")
	if pending.is_empty(): finish(); return
	c._show_court_demand(); await settle(); cases.append(save_case("pending-demand","demand",pending.occurrence_id,"")); await capture("pending-demand")
	write_json("pending.json",cases); evidence={"cases":cases.map(func(row): return {"kind":row.kind,"slot":row.slot,"id":row.id})}; finish()
func respond(action: String) -> void:
	for row: Dictionary in read_json("pending.json"):
		await restored(row); check(choice_ids()==row.choices,"unanswered choices and targets preserved "+row.kind)
		var p: Node=c.politics_overlay
		var choice: String={"compensate":"gift","wait":"accept","force":"reject"}[action] if row.kind=="demand" else action
		var before: Dictionary=snapshot(); pick(p.choices,choice); var expected: Dictionary=p.model.duplicate(true)
		check(expected.ok and snapshot()==before,"response quote read only "+row.kind+choice)
		p.cancel_button.grab_focus(); await key(KEY_SPACE); check(snapshot()==before and p.apply_button.disabled,"cancel preserves politics")
		pick(p.choices,choice)
		for resolution: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080)]: root.size=resolution; await capture(row.kind+"-"+choice+"-preview-"+str(resolution.y))
		p.apply_button.grab_focus(); await key(KEY_SPACE)
		check(c.gold==expected.gold_after,"actual cost equals preview "+row.kind+choice)
		check(JSON.stringify(c.officer_registry.politics)==JSON.stringify(expected.state.officer_registry.politics),"actual relations period and response equal preview")
		check(JSON.stringify(c.strategy_state.unit_rosters)==JSON.stringify(expected.state.unit_rosters),"actual units equal preview")
		cases.append(save_case(row.kind+"-"+choice,row.kind,row.id,row.target,choice)); await capture(row.kind+"-"+choice+"-applied")
	write_json(action+"-restart.json",cases); evidence={"cases":cases.map(func(row): return {"kind":row.kind,"choice":row.choice,"slot":row.slot,"gold":row.political.gold})}; finish()
func real_month() -> void:
	var pending: Dictionary=c.officer_registry.politics.pending
	if not pending.is_empty(): c.Noble.resolve(c,pending.occurrence_id,"reject")
	c.politics_overlay.hide(); if c.merit_overlay.visible: c.merit_overlay.hide()
	await month()
func reload_response(action: String) -> void:
	var timeline: Array=[]
	for row: Dictionary in read_json(action+"-restart.json"):
		await restored(row); var before: Dictionary=snapshot()
		if row.kind=="demand": c.Noble.resolve(c,row.id,row.choice)
		else: c.Power.resolve(c,row.id,row.choice)
		check(before==snapshot(),"same request ID cannot reapply cost/effects "+row.kind+row.choice)
		await capture(row.kind+"-"+row.choice+"-restored")
		var steps:=1
		if row.kind!="demand":
			var request: Dictionary=c.Power.records(c.strategy_state).requests[row.id]
			if row.choice=="wait": steps=int(request.months)
			elif row.choice=="force":
				steps=2 if row.kind=="governor" else 1
				check(c.Power.city_factor(c.strategy_state,"geumseong")==0.8 if row.kind=="governor" else not c.Power.unit_reason(c.strategy_state,row.target).is_empty(),"restored work/army restriction active")
		for n: int in range(steps):
			await real_month(); timeline.append({"kind":row.kind,"choice":row.choice,"step":n+1,"state":political()})
		if row.kind!="demand":
			var request: Dictionary=c.Power.records(c.strategy_state).requests[row.id]
			check(request.status=="completed","restored handover completes "+row.kind+row.choice)
			check(int(request.cost_paid)==(int(request.gold) if row.choice=="compensate" else 0),"cost paid remains exact after monthly processing")
			if row.choice=="force": check(c.Power.city_factor(c.strategy_state,"geumseong")==1.0 if row.kind=="governor" else c.Power.unit_reason(c.strategy_state,row.target).is_empty(),"restriction expires after exact months")
			before=snapshot(); c.Power.resolve(c,row.id,row.choice); check(before==snapshot(),"completed response ID remains idempotent after month")
		await capture(row.kind+"-"+row.choice+"-month-complete")
	write_json(action+"-timeline.json",timeline); evidence={"monthly_records":timeline.size()}; finish()
func dpi_hold() -> void:
	var row: Dictionary=read_json("pending.json")[0]; await restored(row); root.size=Vector2i(1280,720)
	while true:
		var p: Node=c.politics_overlay; var controls: Dictionary={}
		for gid: String in p.group_buttons:
			var point: Vector2=p.group_buttons[gid].get_global_rect().get_center()/p.size; controls[gid]={"x":point.x,"y":point.y}
		write_json("dpi-live.json",{"size":[root.size.x,root.size.y],"controls":controls,"selected":p.selected_group,"court_visible":p.visible,"busy":c.settlement_overlay.busy(),"scroll":p.member_list.get_parent().get_parent().scroll_vertical,"gold":c.gold})
		await get_tree().create_timer(0.4).timeout
func run() -> void:
	await get_tree().create_timer(3).timeout; resources()
	check(ResourceLoader.exists("res://ui/living_city_v1/court_overlay.gd"),"V1.7 court packed")
	check(ResourceLoader.exists("res://ui/living_city_v1/politics_preview.gd"),"politics preview packed")
	if phase=="prepare": await prepare()
	elif phase.begins_with("respond-"): await respond(phase.trim_prefix("respond-"))
	elif phase.begins_with("reload-"): await reload_response(phase.trim_prefix("reload-"))
	elif phase=="dpi": await dpi_hold()
	elif phase=="visual":
		await restored(read_json("pending.json")[0]); await court_visuals("final-court")
		check(not c.politics_overlay.person_basis("historical:004").contains("industry"),"industry duty uses actual localized job label")
		finish()
