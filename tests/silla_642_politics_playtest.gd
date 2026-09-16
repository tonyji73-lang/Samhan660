extends "res://tests/faction_economy_test.gd"

const Core=preload("res://noble_politics.gd")
const Industry=preload("res://industry_assignment.gd")
const DIR="res://.godot/silla-642-politics/"
var actions: Array=[]
var months: Array=[]
var occurrences: Array=[]

func stamp() -> int: return c.year*12+c.month

func full_state() -> Dictionary:
	return canonical({"year":c.year,"month":c.month,"faction":c.player_faction,"gold":c.gold,
		"provinces":c.provinces,"strategy":c.strategy_state,"orders":c.pending_transfer_orders})

func settle_events() -> void:
	for n: int in range(40):
		var p: Node=c.event_presentation
		if not p.active: break
		if p.awaiting_choice() and p.current.steps[p.step_index].get("mode","")=="choice":
			var choice: String="reject" if p.view.choice_buttons.has("reject") else "maintain_tax"
			occurrences.append({"month":stamp(),"event":p.current.id,"choice":choice,"source":"normal monthly campaign"})
			p._choose(choice)
		elif p.awaiting_choice(): p.next()
		else: p.skip()
		await process_frame

func screen(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(DIR+label+".png")==OK,"GUI capture "+label)

func click(button: Control) -> void:
	await process_frame
	await process_frame
	var position: Vector2=button.get_global_transform_with_canvas()*(button.size/2.0)
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down; event.position=position
		root.push_input(event,true)
	await process_frame

func appoint(kind: String, target_id: String, officer_id: String) -> void:
	c.open_politics()
	var ui: Node=c.politics_overlay
	for n: int in range(ui.targets.item_count):
		var item: Dictionary=ui.targets.get_item_metadata(n)
		if item.kind==kind and item.target==target_id:
			ui.targets.select(n); ui.targets.item_selected.emit(n); break
	for n: int in range(ui.people.item_count):
		if ui.people.get_item_metadata(n)==officer_id:
			ui.people.select(n); ui.people.item_selected.emit(n); break
	check(not ui.apply_button.disabled,"politics UI enables "+kind)
	if DisplayServer.get_name()=="headless": ui.apply_button.pressed.emit()
	else: await click(ui.apply_button)
	check((c.officer_registry.posts.get("governor:"+target_id,"") if kind=="governor" else c.strategy_state.unit_rosters[target_id].commander_id)==officer_id,"politics UI applies "+kind)
	await screen("appointed-"+kind)
	ui.hide()
	check(not c.map_area.modal_input_locked,"closing politics restores map input")

func industry_orders() -> void:
	var s: Dictionary=c.strategy_state
	for kind: String in ["build","research"]:
		if not Industry.active(s,kind,"geumseong","silla").is_empty(): continue
		var definitions: Array=["smelter","forge"] if kind=="build" else ["basic_smelting","swordsmithing"]
		for requirement: String in definitions:
			var level: int=int(s.province_buildings.geumseong.get(requirement,0)) if kind=="build" else int(s.faction_research[c.player_faction].get(requirement,0))
			if level>0: continue
			var worker: String="historical:001" if kind=="build" else "historical:003"
			var result: Dictionary=Industry.start(s,c.provinces,c.strategy,"silla","geumseong",kind,requirement,worker,stamp(),c.scenario_id,c.iron_supply_rules)
			actions.append({"month":stamp(),"kind":kind,"requirement":requirement,"result":result})
			check(result.ok,"normal paid "+kind+" "+requirement)
			break
	if int(s.province_buildings.geumseong.forge)>0 and int(s.faction_research[c.player_faction].swordsmithing)>0 and Industry.active(s,"research","geumseong","silla").is_empty():
		if Industry.active(s,"production","geumseong","silla").is_empty():
			var job: Dictionary=Industry.start(s,c.provinces,c.strategy,"silla","geumseong","production","","historical:003",stamp(),c.scenario_id,c.iron_supply_rules)
			check(job.ok,"normal noble production manager")
			actions.append({"month":stamp(),"kind":"production","result":job})
		for recipe: String in ["iron_procurement","iron_sword"]:
			if not s.city_production.geumseong.get(recipe,{}).get("enabled",false):
				var result: Dictionary=c.request_production_command("geumseong",recipe,"start")
				check(result.ok,"normal recipe "+recipe)

func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(DIR)
	seed(64220260916)
	await start(Scenarios.SCENARIOS[1],"silla","historical")
	await settle_events()
	var initial: int=stamp()
	check(c.officer_registry.politics.groups.size()==3,"642 new campaign politics enabled")
	c.open_politics(); await screen("initial-politics"); c.politics_overlay.hide()
	await appoint("governor","geumseong","historical:004")
	var uid: String=c.Army.at_city(c.strategy_state,"geumseong","silla")[0]
	await appoint("commander",uid,"historical:004")
	for n: int in range(12):
		industry_orders()
		var previous: int=stamp()
		c._on_end_turn_button_pressed()
		await process_frame
		await settle_events()
		check(stamp()==previous+1,"normal monthly command "+str(n+1))
		months.append({"month":stamp(),"gold":c.gold,"stock":c.strategy_state.city_inventory.geumseong.duplicate(true),"groups":c.officer_registry.politics.groups.duplicate(true),"work":Industry.production_work(c.strategy_state,c.provinces,"geumseong",stamp())})
	check(stamp()==initial+12,"twelve uninterrupted months")
	check(c.strategy_state.city_inventory.geumseong.sword>0,"normal paid military production yields swords")
	check(c.strategy_state.faction_economy.entries.any(func(e): return e.faction_id=="silla" and e.reason=="production" and e.amount<0),"production charges existing treasury rules")
	c.open_politics(); await screen("month-12-politics"); c.politics_overlay.hide()
	c._on_city_card_production_requested("geumseong"); await screen("month-12-production"); c.production_overlay.hide()
	var slot: String="user://silla_642_normal_%d_%d.json" % [int(Time.get_unix_time_from_system()),OS.get_process_id()]
	check(not FileAccess.file_exists(slot) and c._on_save_button_pressed(slot),"normal progress saved in unique host slot")
	var output:=FileAccess.open(DIR+"normal.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"pid":OS.get_process_id(),"slot":slot,"state":full_state(),"actions":actions,"months":months,"events":occurrences,"checks":checks,"failures":failures},"\t")); output.close()
	print("SILLA 642 NORMAL: ",checks," checks, ",failures," failures; events ",occurrences)
	quit(0 if failures==0 else 1)
