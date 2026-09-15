extends "res://tests/project_foundation_test.gd"
const Noble=preload("res://noble_personnel.gd")
const Core=preload("res://noble_politics.gd")
const Army=preload("res://army_readiness.gd")
const Industry=preload("res://industry_assignment.gd")
const DIR="res://.godot/noble-results/"
var rows: Array=[]
func screen(label: String) -> void:
	if is_instance_valid(c) and c.event_presentation.active: c.event_presentation.view.complete_text()
	await settle(); await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(DIR+label+".png")==OK,"capture "+label)
func pick(p: OptionButton, key: String) -> void:
	for n: int in range(p.item_count):
		if str(p.get_item_metadata(n))==key: p.select(n); p.item_selected.emit(n); return
func target(kind: String, id: String) -> void:
	var p: Node=c.politics_overlay
	for n: int in range(p.targets.item_count):
		var metadata: Dictionary=p.targets.get_item_metadata(n)
		if metadata.kind==kind and metadata.target==id: p.targets.select(n); p.targets.item_selected.emit(n); return
func events() -> void:
	for n: int in range(30):
		var e: Node=c.event_presentation
		if not e.active: return
		if e.awaiting_choice():
			if e.current.steps[e.step_index].get("mode","")=="choice":
				var key: String="reject" if e.view.choice_buttons.has("reject") else "maintain_tax"
				await click(e.view.choice_buttons[key])
			else: e.next(); await settle()
		else: e.skip(); await settle()
func _run() -> void:
	create_timer(500).timeout.connect(func(): push_error("NOBLE GUI TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(DIR)
	root.set_meta("new_game_settings",{"faction":"silla","play_style":"historical","difficulty":"normal","scenario_id":Scenarios.SCENARIOS[0].id,"scenario_year":632,"scenario_season":"spring"})
	change_scene_to_file("res://campaign_main.tscn"); await settle(); c=current_scene; await events()
	c.open_politics(); await settle()
	check(c.politics_overlay.visible and c.map_area.modal_input_locked,"politics opens and map locks")
	target("governor","geumseong"); pick(c.politics_overlay.people,"historical:004")
	await screen("governor-before"); await click(c.politics_overlay.apply_button); await screen("governor-after")
	check(c.officer_registry.posts["governor:geumseong"]=="historical:004","actual UI governor appointment")
	var uid: String=Army.at_city(c.strategy_state,"geumseong","silla")[0]
	target("commander",uid); pick(c.politics_overlay.people,"historical:003")
	await screen("commander-before"); await click(c.politics_overlay.apply_button); await screen("commander-after")
	check(c.strategy_state.unit_rosters[uid].commander_id=="historical:003","actual UI commander appointment")
	await escape(); check(not c.map_area.modal_input_locked,"politics Esc restores map")
	# Reproducible event fixture: only existing Silla units' locations/commanders.
	# No people, troops, resources or skill points are generated.
	for u: Dictionary in c.strategy_state.unit_rosters.values():
		if u.faction_id=="silla" and int(u.troops)>0: u.location="geumseong"; u.commander_id="historical:003"
	var pending: Dictionary=Noble.propose(c)
	check(not pending.is_empty(),"threshold-qualified real appointment demand")
	c._on_save_button_pressed(DIR+"gui-same-pending.json")
	for choice: String in ["accept","gift","reject"]:
		c._on_load_button_pressed(DIR+"gui-same-pending.json"); await settle()
		var request: Dictionary=c.officer_registry.politics.pending.duplicate(true)
		var before: Dictionary={"gold":c.gold,"person":c.officer_registry.people[request.officer_id].duplicate(true),"group":c.officer_registry.politics.groups[request.group_id].duplicate(true)}
		await screen("choice-"+choice+"-before")
		check(c.event_presentation.view.choice_buttons.has(choice),"actual choice button "+choice)
		await click(c.event_presentation.view.choice_buttons[choice]); await screen("choice-"+choice+"-result")
		check(c.officer_registry.politics.pending.is_empty(),"native event resolved "+choice)
		rows.append({"choice":choice,"before":before,"gold":c.gold,"loyalty":c.officer_registry.people[request.officer_id].loyalty,"cooperation":c.officer_registry.politics.groups[request.group_id].cooperation})
		await events(); c.open_politics(); await screen("choice-"+choice+"-politics"); await escape()
	# Build legitimate regional prerequisites using real paid APIs and monthly industry
	# advancement (isolated fixture; no free facilities or inventory).
	c._on_load_button_pressed(DIR+"gui-same-pending.json"); await events()
	var worker: String="historical:001"
	c.officer_registry.politics.last_national=c.year*12+c.month
	c.OfficerRegistry.set_location(c.officer_registry,worker,"geumgwan")
	for item: Array in [["build","smelter"],["build","forge"],["research","swordsmithing"]]:
		var q: Dictionary=Industry.start(c.strategy_state,c.provinces,c.strategy,"silla","geumgwan",item[0],item[1],worker,c.year*12+c.month,c.scenario_id,c.iron_supply_rules)
		check(q.ok,"paid GUI fixture prerequisite "+str(item[1]))
		if not q.ok: quit(1); return
		while Industry.jobs(c.strategy_state)[q.job_id].status=="pending":
			c._advance_month(); c.officer_registry.clock_month=c.year*12+c.month; Industry.process(c.strategy_state,c.provinces,c.year*12+c.month)
	c.OfficerRegistry.set_location(c.officer_registry,"historical:004","geumgwan")
	check(Industry.start(c.strategy_state,c.provinces,c.strategy,"silla","geumgwan","production","","historical:004",c.year*12+c.month,c.scenario_id,c.iron_supply_rules).ok,"actual noble production manager")
	for recipe: String in ["iron_supply","iron_sword"]: check(c.request_production_command("geumgwan",recipe,"start").ok,"real recipe start")
	c._on_save_button_pressed(DIR+"gui-production-baseline.json")
	for coop: int in [0,50,100]:
		c._on_load_button_pressed(DIR+"gui-production-baseline.json"); await events()
		c.officer_registry.politics.groups["silla:military"].cooperation=coop # comparison input only
		c._on_city_card_production_requested("geumgwan"); await screen("production-"+str(coop)+"-before"); await escape()
		var money: int=c.gold
		c._advance_month(); Production.process_all(c.strategy_state,c.provinces,c.year*12+c.month,c.scenario_id,c.iron_supply_rules)
		c._on_city_card_production_requested("geumgwan"); await screen("production-"+str(coop)+"-after")
		rows.append({"production_cooperation":coop,"work":Industry.production_work(c.strategy_state,c.provinces,"geumgwan",c.year*12+c.month),"before_gold":money,"after_gold":c.gold,"inventory":c.strategy_state.city_inventory.geumgwan.duplicate(true),"progress":c.strategy_state.facility_progress.geumgwan.duplicate(true)})
		await escape()
	var file:=FileAccess.open(DIR+"gui-evidence.json",FileAccess.WRITE); file.store_string(JSON.stringify(rows,"\t")); file.close()
	print("NOBLE GUI: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
