extends "res://tests/silla_642_politics_playtest.gd"

var checkpoints: Array=[]

func checkpoint(label: String) -> void:
	var slot: String="user://silla_politics_%s_%d_%d.json" % [label,int(Time.get_unix_time_from_system()),OS.get_process_id()]
	check(not FileAccess.file_exists(slot) and c._on_save_button_pressed(slot),"unique checkpoint "+label)
	checkpoints.append({"label":label,"slot":slot,"state":full_state()})
	var before: Dictionary=full_state()
	for n: int in range(2):
		c._on_load_button_pressed(slot)
		if full_state()!=before and n==0:
			var diagnostic:=FileAccess.open(DIR+label+"-diff.json",FileAccess.WRITE)
			diagnostic.store_string(JSON.stringify({"before":before,"after":full_state()})); diagnostic.close()
		check(full_state()==before,"repeat native restore "+label)

func concentrated() -> void:
	await start(Scenarios.SCENARIOS[1],"silla","historical")
	# Boundary fixture only: existing troops and posts reassigned, no new resources.
	for unit: Dictionary in c.strategy_state.unit_rosters.values():
		if unit.faction_id=="silla" and int(unit.troops)>0:
			unit.location="geumseong"; unit.commander_id="historical:004"
	c.officer_registry.posts["governor:geumseong"]="historical:004"
	c.Army.sync(c.strategy_state,c.provinces)
	c._sync_officer_labels()

func request() -> Dictionary:
	return {"kind":"governor","target":"geumseong","officer_id":"historical:001","faction_id":"silla"}

func _run() -> void:
	create_timer(180).timeout.connect(func(): quit(2))
	DirAccess.make_dir_recursive_absolute(DIR)
	for scenario: Dictionary in [Scenarios.SCENARIOS[0],Scenarios.SCENARIOS[1]]:
		await start(scenario,"silla","historical")
		var raw: Dictionary=Registry.new_game(scenario.id,c.provinces)
		var r: Dictionary=c.officer_registry
		check(r.posts==raw.posts,"initial ruler and posts unchanged "+str(scenario.year))
		var members: Array=[]
		for group: Dictionary in r.politics.groups.values():
			check(group.members.has(group.representative),"active representative "+group.id)
			for id: String in group.members:
				var p: Dictionary=r.people[id]
				check(not members.has(id) and p.alive and p.active and p.faction_id=="silla","unique living Silla member "+id)
				members.append(id)
				for key: String in ["location","stats","family_id","alive","active","faction_id","duties"]:
					check(p[key]==raw.people[id][key],"politics preserves identity "+id+" "+key)
		check(members.size()==(6 if scenario.year==642 else 5),"scenario-specific membership")
		check(r.posts["ruler:silla"]=="historical:001" and r.politics.history.is_empty(),"Seondeok ruler; no retroactive rewards")
		var before: Dictionary=full_state()
		Core.initialize(r,scenario.id,stamp()+12)
		check(full_state()==before,"initialization preserves existing politics")
		await checkpoint("new-"+str(scenario.year))
		# Simulated pre-politics schema, explicitly not a recovered historical save.
		r=c.officer_registry
		r.erase("politics")
		for p: Dictionary in r.people.values():
			p.political_group_id=""; p.erase("loyalty"); p.erase("ambition")
		await checkpoint("legacy-"+str(scenario.year))
		check(not c.officer_registry.has("politics"),"old save remains without politics "+str(scenario.year))
		var legacy: Dictionary=full_state()
		check(is_equal_approx(Core.multiplier(c.strategy_state,"historical:004"),1.0) and c.Noble.propose(c).is_empty(),"old save no new modifier or demand")
		check(full_state()==legacy,"legacy query leaves saved state unchanged")
	for choice: String in ["compensate","wait","force"]:
		await concentrated()
		var q: Dictionary=c.Power.quote(c,request())
		check(q.ok and q.required,"642 concentrated command requires negotiation "+choice)
		var offer: Dictionary=c.Power.intercept(c,request())
		check(not offer.ok and offer.has("negotiation_id"),"common personnel intercept opens negotiation")
		if not offer.has("negotiation_id"): continue
		await checkpoint("offered-"+choice)
		c.event_presentation.restore_state({}); c.power_dialog.hide()
		var money: int=c.gold
		check(c.Power.resolve(c,offer.negotiation_id,choice).ok,"common negotiation choice "+choice)
		if choice=="wait":
			await checkpoint("waiting")
			check(c.officer_registry.posts["governor:geumseong"]=="historical:004","waiting preserves authority")
		else:
			check(c.officer_registry.posts["governor:geumseong"]=="historical:001","handover changes governor once")
			check(c.gold==money-(int(q.gold) if choice=="compensate" else 0),"common exact compensation fee "+choice)
			var before: Dictionary=full_state()
			check(not c.Power.resolve(c,offer.negotiation_id,choice).ok and full_state()==before,"duplicate handover cannot pay or react again")
			if choice=="force": check(c.Power.city_factor(c.strategy_state,"geumseong")==0.8,"common forced handover work modifier")
			await checkpoint("completed-"+choice)
	await concentrated()
	c.officer_registry.posts["governor:geumseong"]="historical:003"
	c._sync_officer_labels()
	var demand: Dictionary=c.Noble.propose(c)
	check(not demand.is_empty(),"642 boundary demand uses existing influence threshold")
	if demand.is_empty(): quit(1); return
	await checkpoint("pending-demand")
	var opening: int=c.gold
	check(not c.Noble.resolve(c,demand.occurrence_id,"gift").is_empty() and c.gold==opening-100,"642 demand gift uses common cost100")
	var after: Dictionary=full_state()
	check(c.Noble.resolve(c,demand.occurrence_id,"gift").is_empty() and full_state()==after,"duplicate demand has no effects")
	# Compare cooperation using actual paid production on the normal-play checkpoint.
	var normal: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"normal.json"))
	var previous_work: int=0
	for coop: int in [0,50,100]:
		c._on_load_button_pressed(normal.slot)
		c.officer_registry.politics.groups["silla:civil"].cooperation=coop
		var work: int=Industry.production_work(c.strategy_state,c.provinces,"geumseong",stamp()+1)
		check(work>previous_work,"642 cooperation monotonically changes production work "+str(coop)); previous_work=work
		var stock: int=c.strategy_state.city_inventory.geumseong.sword
		var money: int=c.gold
		Production.process_all(c.strategy_state,c.provinces,stamp()+1,c.scenario_id,c.iron_supply_rules)
		var made: int=int(c.strategy_state.city_inventory.geumseong.sword)-stock
		check(made>0 and c.gold==money-made*28,"642 full common batch cost for cooperation "+str(coop))
		var produced: Dictionary=full_state()
		Production.process_all(c.strategy_state,c.provinces,stamp()+1,c.scenario_id,c.iron_supply_rules)
		check(full_state()==produced,"production repeated month no extra output or cost")
	var output:=FileAccess.open(DIR+"fixtures.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"pid":OS.get_process_id(),"checkpoints":checkpoints,"checks":checks,"failures":failures},"\t")); output.close()
	print("SILLA 642 FIXTURES: ",checks," checks, ",failures," failures")
	quit(0 if failures==0 else 1)
