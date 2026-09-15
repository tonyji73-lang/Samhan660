extends "res://tests/officer_registry_test.gd"
const Army=preload("res://army_readiness.gd")
const Economy=preload("res://faction_economy.gd")
const Industry=preload("res://industry_assignment.gd")
const Noble=preload("res://noble_personnel.gd")
const Core=preload("res://noble_politics.gd")
const Supply=preload("res://supply_transport.gd")
const DIR="res://.godot/playability-results/"
var results: Dictionary={"scenarios":[],"politics":[],"war":[]}
var choice_policy: String="reject"
func stamp() -> int: return c.year*12+c.month
func save(label: String) -> void: c._on_save_button_pressed(DIR+label+".json")
func settle_events() -> void:
	c.event_presentation.queue.clear()
	if c.event_presentation.active: c.event_presentation._finish()
	var crop: Dictionary=c.crop_failure_events.get("pending",{})
	if not crop.is_empty(): c.resolve_event_choice(c.CropFailure.EVENT_ID,crop.occurrence_id,"maintain_tax")
	var p: Dictionary=c.officer_registry.get("politics",{}).get("pending",{})
	if not p.is_empty(): Noble.resolve(c,p.occurrence_id,choice_policy if Noble.reason(c,p.occurrence_id,choice_policy).is_empty() else "reject")
func advance() -> void:
	settle_events(); var previous: int=stamp()
	c._on_end_turn_button_pressed(); settle_events()
	check(stamp()==previous+1,"actual month advance")
func metrics(f: String) -> Dictionary:
	var cities: Array=[]; var officers: Array=[]; var troops: int=0; var equipment: int=0; var training: float=0; var ready: int=0; var food: int=0; var inventory: int=0; var available: int=0
	for city: String in Economy.city_ids(c.strategy_state,c.provinces):
		if Economy.resolve(c.strategy_state,c.provinces[city].faction)==f:
			cities.append({"id":city,"name":c.provinces[city].name,"population":c.provinces[city].population,"food":c.provinces[city].food_stock}); food+=int(c.provinces[city].food_stock); inventory+=int(c.strategy_state.city_inventory[city].sword)
	for p: Dictionary in c.officer_registry.people.values():
		if p.active and p.alive and p.faction_id==f:
			var usable: bool=not p.location.is_empty() and Industry.staff_reason(c.strategy_state,c.provinces,f,p.location,p.officer_id,stamp()).is_empty()
			officers.append({"id":p.officer_id,"name":p.name,"city":p.location,"available":usable,"loyalty":p.get("loyalty",null)})
			available+=int(usable)
	for u: Dictionary in c.strategy_state.unit_rosters.values():
		if u.faction_id==f and int(u.troops)>0:
			troops+=int(u.troops); equipment+=mini(int(u.equipment),int(u.troops)); training+=int(u.training_points)
			if Army.training(u)>=70 and Army.ratio(u)>=1: ready+=int(u.troops)
	return {"stamp":stamp(),"cities":cities,"ruler":c.get_ruler(f).get("name",""),"officers":officers,"available":available,"troops":troops,"equipment":equipment,"training":training/maxi(1,troops),"ready":ready,"food":food,"sword":inventory,"finance":c.strategy_state.faction_economy.accounts[f].duplicate(true),"power":Core.influence(c.strategy_state,c.provinces,f),"politics":c.officer_registry.get("politics",{}).duplicate(true)}
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for scenario: Dictionary in Scenarios.SCENARIOS:
		var prepared: Dictionary=Scenarios.get_scenario(scenario.id)
		for f: Dictionary in prepared.factions:
			if not Scenarios.is_faction_playable_by_default(scenario.id,f.id): continue
			await start(scenario,f.id,"historical")
			var row: Dictionary=metrics(f.id); row["year"]=scenario.year; row["faction"]=f.id; row["name"]=f.name
			row["initial_research"]=c.strategy_state.faction_research.get(f.name,{}).duplicate(true)
			row["commands"]=[]
			for city: Dictionary in row.cities:
				row.commands.append({"city":city.id,"recruit":c.get_recruitment_quote(city.id,1000),"staff":c.get_city_officer_ids(city.id)})
			advance(); row["advanced"]=stamp(); results.scenarios.append(row)
			check(not row.cities.is_empty() and not row.ruler.is_empty() and not row.officers.is_empty(),"selectable combination has city ruler people "+str(scenario.year)+f.id)
			save("scenario-"+str(scenario.year)+"-"+f.id)
	await political_branches()
	await war_cases()
	var file:=FileAccess.open(DIR+"evidence.json",FileAccess.WRITE); file.store_string(JSON.stringify(results,"\t")); file.close()
	print("PLAYABILITY AUDIT: %d checks, %d failures" % [checks,failures]); quit(0 if failures==0 else 1)
func political_branches() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	c._on_load_button_pressed("res://.godot/noble-results/audit-silla.json"); settle_events()
	# Normal existing 30-month save, all preparatory changes use paid campaign commands.
	for item: Array in [["build","smelter"],["build","forge"],["research","swordsmithing"]]:
		var q: Dictionary=Industry.start(c.strategy_state,c.provinces,c.strategy,"silla","geumseong",item[0],item[1],"historical:001",stamp(),c.scenario_id,c.iron_supply_rules)
		check(q.ok,"normal baseline paid prerequisite "+str(item[1]))
		if not q.ok: break
		for n: int in range(20):
			if Industry.jobs(c.strategy_state)[q.job_id].status!="pending": break
			advance()
	for recipe: String in ["iron_procurement","iron_sword"]: check(c.request_production_command("geumseong",recipe,"start").ok,"baseline actual production command")
	var move: Dictionary=c.queue_province_transfer({"source_id":"geumgwan","target_id":"geumseong","troops":12000,"officer_ids":[]})
	check(move.ok,"normal political baseline troop transfer")
	advance()
	var units: Array=Army.at_city(c.strategy_state,"geumseong","silla")
	for i: int in range(1,units.size()): Army.merge(c.strategy_state,c.provinces,"silla",units[0],units[i])
	Noble.appoint(c,"silla","governor","geumseong","historical:001")
	for city: String in ["geumseong","sabeol"]:
		Noble.appoint(c,"silla","commander",Army.at_city(c.strategy_state,city,"silla")[0],"historical:003" if city=="geumseong" else "historical:002")
	save("politics-normal-baseline")
	for mode: String in ["A","B","C"]:
		c._on_load_button_pressed(DIR+"politics-normal-baseline.json"); settle_events(); seed(6322026)
		choice_policy="gift" if mode=="C" else "reject"
		var opening: Dictionary=metrics("silla")
		if mode!="C":
			var governor: String="historical:001" if mode=="A" else "historical:004"
			Noble.appoint(c,"silla","governor","geumseong",governor)
			for city: String in ["geumseong","gukwon","sabeol"]:
				var person: String=({"geumseong":"historical:004","gukwon":"historical:006","sabeol":"historical:002"} if mode=="A" else {"geumseong":"historical:004","gukwon":"historical:006","sabeol":"historical:002"})[city]
				var ids: Array=Army.at_city(c.strategy_state,city,"silla")
				if not ids.is_empty(): Noble.appoint(c,"silla","commander",ids[0],person)
		var manager: String="historical:001" if mode=="A" else "historical:004"
		check(Industry.start(c.strategy_state,c.provinces,c.strategy,"silla","geumseong","production","",manager,stamp(),c.scenario_id,c.iron_supply_rules).ok,"policy manager actual assignment "+mode)
		var months: Array=[]
		for n: int in range(12): advance(); months.append(metrics("silla"))
		results.politics.append({"mode":mode,"opening":opening,"months":months,"entries":c.strategy_state.faction_economy.entries.duplicate(true),"jobs":c.strategy_state.domestic.jobs.duplicate(true)})
		save("politics-"+mode+"-12months")
func war_cases() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	c._on_load_button_pressed("res://.godot/army-results/gui-battle.json"); settle_events()
	var before: Dictionary=metrics("silla")
	var q: Dictionary=c.get_recruitment_quote("siljik",1000)
	var recruitment: Dictionary=c.request_recruitment("siljik",1000)
	for n: int in range(3): advance()
	var retry: Dictionary=c.resolve_army_battle("siljik","haslla","silla")
	results.war.append({"type":"normal-defeat-recovery","before":before,"quote":q,"recruitment":recruitment,"retry":retry,"after":metrics("silla")}); save("defeat-recovery")
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	# Find an affordable actual border battle; no changes to armies or abilities.
	var attempts: Array=[]
	for city: String in Economy.city_ids(c.strategy_state,c.provinces):
		if c.provinces[city].faction!=c.player_faction: continue
		for target: String in c.province_connections.get(city,[]):
			if c.provinces[target].faction==c.player_faction: continue
			var result: Dictionary=c.resolve_army_battle(city,target,"silla"); attempts.append(result)
			if result.get("ok",false) and result.get("won",false):
				var officers: Array=c.get_city_officer_ids(target)
				var gov: Dictionary={} if officers.is_empty() else Noble.appoint(c,"silla","governor",target,officers[0])
				for n: int in range(3): advance()
				results.war.append({"type":"normal-victory-recovery","attempts":attempts,"governor":gov,"after":metrics("silla"),"city":c.provinces[target].duplicate(true)})
				save("victory-recovery"); return
	results.war.append({"type":"normal-border-attempts","attempts":attempts})
