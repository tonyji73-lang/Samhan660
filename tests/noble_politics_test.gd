extends "res://tests/industry_assignment_test.gd"
const Noble=preload("res://noble_personnel.gd")
const Core=preload("res://noble_politics.gd")
const Army=preload("res://army_readiness.gd")
const DIR="res://.godot/noble-results/"
var proofs: Dictionary={"choices":[],"production":[],"audit":[]}
func politics_save(label: String) -> void:
	var before: Variant=canonical(c.officer_registry.politics)
	var money: int=c.gold
	c._on_save_button_pressed(DIR+label+".json")
	for n: int in range(3):
		c._on_load_button_pressed(DIR+label+".json")
		check(canonical(c.officer_registry.politics)==before and c.gold==money,"politics native repeat load "+label)
	c.event_presentation._finish()
func setup_power() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	# Controlled influence fixture: move existing troop units, no creation or strength edit.
	for u: Dictionary in c.strategy_state.unit_rosters.values():
		if u.faction_id=="silla" and int(u.troops)>0:
			u.location="geumseong"; u.commander_id="historical:004"
	check(not Noble.propose(c).is_empty(),"real authority gain candidate at influence >=20")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var r: Dictionary=c.officer_registry
	check(r.politics.groups.size()==3 and r.politics.history.is_empty(),"three existing-person groups without retroactive awards")
	var base: Dictionary=Core.influence(c.strategy_state,c.provinces,"silla")
	check(base.unassigned.troops>0 and base.groups["silla:royal"].troops==0,"unassigned troops are not royal direct control")
	var id: String="historical:004"; var old: String=str(r.posts["governor:geumseong"])
	check(Noble.appoint(c,"silla","governor","geumseong",id).ok,"royal governor appointment")
	check(r.people[id].loyalty==58 and r.people[old].loyalty==40 and r.politics.groups["silla:military"].cooperation==54 and r.politics.groups["silla:civil"].cooperation==44,"cross-group exact personal and cooperation effects")
	var h: int=r.politics.history.size()
	check(not Noble.appoint(c,"silla","governor","geumseong",id).ok and h==r.politics.history.size(),"same appointment no effects")
	Noble.appoint(c,"silla","governor","geumseong",old); Noble.appoint(c,"silla","governor","geumseong",id)
	check(r.people[id].loyalty==48,"six-month personal positive cooldown blocks appointment farming")
	var before: Variant=canonical(r.politics)
	Registry.set_location(r,id,"geumgwan")
	check(canonical(r.politics)==before,"automatic move dismissal has no political penalty")
	r.politics.groups["silla:military"].cooperation=0
	politics_save("zero")
	for choice: String in ["accept","gift","reject"]:
		await setup_power()
		politics_save("pending-"+choice)
		var request: Dictionary=c.officer_registry.politics.pending.duplicate(true)
		var person: String=request.officer_id
		var balance: int=c.gold; var case_loyalty: int=c.officer_registry.people[person].loyalty
		var coop: int=c.officer_registry.politics.groups[request.group_id].cooperation
		var result: Dictionary=Noble.resolve(c,request.occurrence_id,choice)
		check(not result.is_empty(),"resolve "+choice)
		check(c.gold==balance-(100 if choice=="gift" else 0),"exact choice treasury "+choice)
		check(c.officer_registry.people[person].loyalty==case_loyalty+({"accept":8,"gift":5,"reject":-6}[choice]),"exact choice loyalty "+choice)
		check(c.officer_registry.politics.groups[request.group_id].cooperation==coop+({"accept":4,"gift":6,"reject":-6}[choice]),"exact choice cooperation "+choice)
		var state: Variant=canonical(c.officer_registry.politics)
		check(Noble.resolve(c,request.occurrence_id,choice).is_empty() and canonical(c.officer_registry.politics)==state,"duplicate choice no effect "+choice)
		check(Noble.propose(c).is_empty(),"national demand cooldown "+choice)
		proofs.choices.append({"choice":choice,"request":request,"gold_before":balance,"gold_after":c.gold,"loyalty":c.officer_registry.people[person].loyalty,"cooperation":c.officer_registry.politics.groups[request.group_id].cooperation})
		politics_save("resolved-"+choice)
	for invalid: String in ["dead","moved","captured"]:
		await setup_power()
		var request: Dictionary=c.officer_registry.politics.pending
		if invalid=="dead": c.officer_registry.people[request.officer_id].alive=false
		elif invalid=="moved":
			# v1 power constraint: a voluntary move may no longer silently abandon concentrated command.
			check(not Registry.set_location(c.officer_registry,request.officer_id,"geumgwan") and c.officer_registry.people[request.officer_id].location=="geumseong","concentrated command move requires authority handover")
			continue
		else: c.provinces.geumseong.faction="백제"
		var gold: int=c.gold; var n: int=c.officer_registry.politics.history.size()
		check(not Noble.resolve(c,request.occurrence_id,"gift").is_empty() and c.gold==gold and c.officer_registry.politics.history.size()==n and c.officer_registry.politics.pending.is_empty(),"invalid demand clears without effects "+invalid)
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var uid: String=Army.at_city(c.strategy_state,"geumseong","silla")[0]
	Army.appoint(c.strategy_state,c.provinces,"silla",uid,"historical:004")
	var power: Dictionary=Core.influence(c.strategy_state,c.provinces,"silla")
	var loyalty: int=c.officer_registry.people["historical:004"].loyalty
	var split: Dictionary=Army.split(c.strategy_state,c.provinces,"silla",uid,100)
	Army.appoint(c.strategy_state,c.provinces,"silla",split.unit_id,"historical:004")
	check(c.officer_registry.people["historical:004"].loyalty==loyalty,"smaller command no positive award")
	Army.merge(c.strategy_state,c.provinces,"silla",uid,split.unit_id)
	Army.appoint(c.strategy_state,c.provinces,"silla",uid,"historical:004")
	check(Core.influence(c.strategy_state,c.provinces,"silla").troops==power.troops and c.officer_registry.people["historical:004"].loyalty==loyalty,"split merge conserve basis and cooldown")
	for coop: int in [0,50,100]:
		await prepare_production(false)
		# Paid native prerequisites; controlled manager ability 100 and cooperation only.
		Registry.set_location(c.officer_registry,"historical:004","geumgwan")
		Registry.set_stats(c.officer_registry,"historical:004",{"politics":100,"intelligence":100})
		check(begin("geumgwan","production","","historical:004").ok,"noble manager")
		c.officer_registry.politics.groups["silla:military"].cooperation=coop
		var money: int=c.gold
		for n: int in range(6): tick(true)
		var count: int=c.strategy_state.city_inventory.geumgwan.sword
		check(count==(8 if coop==0 else 9) and c.gold==money-count*16,"cooperation actual six-month batches and full material cost "+str(coop))
		proofs.production.append({"cooperation":coop,"work":Industry.production_work(c.strategy_state,c.provinces,"geumgwan",stamp()),"sword":count,"start_gold":money,"end_gold":c.gold,"progress":c.strategy_state.facility_progress.geumgwan.duplicate(true)})
		var snap: Variant=canonical(c.strategy_state)
		Production.process_all(c.strategy_state,c.provinces,stamp(),c.scenario_id,c.iron_supply_rules)
		check(canonical(c.strategy_state)==snap,"political production monthly idempotence")
	for scenario: Dictionary in Scenarios.SCENARIOS:
		if scenario.year in [632,642]: continue
		await start(scenario,"silla","historical")
		check(not c.officer_registry.has("politics"),"non-enabled scenario unchanged "+str(scenario.year))
	await audit_supply()
	var file:=FileAccess.open(DIR+"evidence.json",FileAccess.WRITE); file.store_string(JSON.stringify(proofs,"\t")); file.close()
	print("NOBLE POLITICS: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
func audit_supply() -> void:
	for player: String in ["silla","baekje"]:
		await start(Scenarios.SCENARIOS[0],player,"historical")
		for n: int in range(30):
			c.event_presentation._finish()
			var crop: Dictionary=c.crop_failure_events.get("pending",{})
			if not crop.is_empty(): c.resolve_event_choice(c.CropFailure.EVENT_ID,crop.occurrence_id,"maintain_tax")
			var pending: Dictionary=c.officer_registry.get("politics",{}).get("pending",{})
			if not pending.is_empty(): Noble.resolve(c,pending.occurrence_id,"reject")
			c._on_end_turn_button_pressed()
		c._on_save_button_pressed(DIR+"audit-"+player+".json")
		proofs.audit.append({"player":player,"year":c.year,"month":c.month,"iron_ai":c.strategy_state.get("iron_ai",{}),"jobs":c.strategy_state.domestic.jobs,"accounts":c.strategy_state.faction_economy.accounts,"entries":c.strategy_state.faction_economy.entries,"politics_ai":c.officer_registry.politics.ai_log})
