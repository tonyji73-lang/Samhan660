extends "res://tests/officer_registry_test.gd"

const Industry=preload("res://industry_assignment.gd")
const Production=preload("res://production_system.gd")
const Economy=preload("res://faction_economy.gd")
const RESULTS="res://.godot/industry-results/"
var evidence: Dictionary={"completion":[],"production":[]}

func stamp() -> int: return c.year*12+c.month

func officer(city: String, stat: int = 90) -> String:
	var id: String=c.get_city_officer_ids(city)[0]
	Registry.set_stats(c.officer_registry,id,{"politics":stat,"intelligence":stat})
	return id

func begin(city: String, kind: String, requirement: String, id: String) -> Dictionary:
	var owner: String=Economy.resolve(c.strategy_state,str(c.provinces[city].faction))
	return Industry.start(c.strategy_state,c.provinces,c.strategy,owner,city,kind,requirement,id,stamp(),c.scenario_id,c.iron_supply_rules)

func tick(produce: bool = false) -> void:
	c._advance_month(); c.officer_registry.clock_month=stamp()
	Industry.process(c.strategy_state,c.provinces,stamp())
	if produce: Production.process_all(c.strategy_state,c.provinces,stamp(),c.scenario_id,c.iron_supply_rules)

func finish(id: String) -> int:
	var months: int=0
	while Industry.jobs(c.strategy_state)[id].status=="pending" and months<30:
		tick(); months+=1
	return months

func save_case(label: String) -> void:
	var before: Dictionary=snapshot()
	c._on_save_button_pressed(RESULTS+label+".json")
	for n: int in range(3):
		c._on_load_button_pressed(RESULTS+label+".json")
		if snapshot()!=before and n==0:
			var diagnostic:=FileAccess.open(RESULTS+label+"-comparison.json",FileAccess.WRITE); diagnostic.store_string(JSON.stringify({"before":before,"after":snapshot()},"\t")); diagnostic.close()
		check(snapshot()==before,label+" native load %d" % n)

func ability_cases() -> void:
	for faction: String in ["silla","baekje","goguryeo"]:
		for stat: int in [90,30]:
			await start(Scenarios.SCENARIOS[0],faction,"historical")
			var city: String={"silla":"geumseong","baekje":"sabi","goguryeo":"pyongyang"}[faction]
			var id: String=officer(city,stat)
			for kind: String in ["build","research"]:
				var requirement: String="academy" if kind=="build" else "archery"
				var result: Dictionary=begin(city,kind,requirement,id)
				check(result.ok and result.required==600 and result.work==50+stat,faction+" "+kind+" real definition 2seasons =6months=600")
				var months: int=finish(result.job_id)
				check(months==(5 if stat==90 else 8),"ability %d %s completes in %d months" % [stat,kind,months])
				var before: Dictionary=snapshot()
				Industry.process(c.strategy_state,c.provinces,stamp())
				check(snapshot()==before,"completion and cost cannot repeat")
				check(not Industry.cancel(c.strategy_state,c.provinces,faction,result.job_id,stamp()).ok,"completed job cannot refund")
				evidence.completion.append({"faction":faction,"kind":kind,"efficiency":stat,"months":months,"cost":result.gold_cost,"remaining_gold":c.gold})

func lifecycle() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var city: String="geumseong"
	var id: String=officer(city)
	var people: Array=c.get_city_officer_ids(city)
	var second: String=people[1]
	Registry.set_stats(c.officer_registry,second,{"politics":30,"intelligence":30})
	var result: Dictionary=begin(city,"build","academy",id)
	var job: Dictionary=Industry.jobs(c.strategy_state)[result.job_id]
	check(c.gold==480 and not begin(city,"research","archery",id).ok,"one duty across construction/research")
	check(not c.cancel_domestic(job.id).ok and c.gold==480,"domestic cancel cannot bypass industry cancellation rules")
	check(not c.start_domestic(city,"agriculture",id).ok,"construction blocks agriculture")
	check(not c.get_diplomatic_action_quote("baekje","gift",id).ok and not Registry.action_available(c.officer_registry,id,c.provinces,"move",city) and not Registry.action_available(c.officer_registry,id,c.provinces,"attack",city),"common envoy/move/attack conflicts")
	check(Registry.action_available(c.officer_registry,id,c.provinces,"defense",city),"defense retained")
	check(c._apply_governor_appointment(city,id).ok or c.get_governor_id(city)==id,"governor can share local construction")
	check(c.start_domestic(city,"commerce",second).ok,"different officer allows domestic and build concurrently")
	var development: Dictionary=c.Domestic.active_job(c.strategy_state,city)
	var third: String=people[2]
	var simultaneous: Dictionary=begin(city,"production","",third)
	check(simultaneous.ok and job.status=="pending" and development.status=="pending","three separate people concurrently develop/build/manage production")
	Industry.cancel(c.strategy_state,c.provinces,"silla",simultaneous.job_id,stamp())
	c.cancel_domestic(development.id)
	var production: Dictionary=begin(city,"production","",second)
	check(production.ok and not begin(city,"production","",id).ok,"one production manager per city, separate construction slot")
	Industry.cancel(c.strategy_state,c.provinces,"silla",production.job_id,stamp())
	check(Industry.cancel(c.strategy_state,c.provinces,"silla",job.id,stamp()).refund==520 and c.gold==1000,"before first work refunds exact paid520 once")
	check(not Industry.cancel(c.strategy_state,c.provinces,"silla",job.id,stamp()).ok,"second cancel denied")
	result=begin(city,"build","academy",id); job=Industry.jobs(c.strategy_state)[result.job_id]
	tick(); check(job.progress==140,"first month140")
	check(Industry.assign(c.strategy_state,c.provinces,"silla",job.id,city,second,stamp()).ok and job.progress==140 and c.gold==480,"replacement retains progress and payment")
	tick(); check(job.progress==220,"replacement changes next month to80")
	Industry.pause(c.strategy_state,"silla",job.id,stamp()); tick()
	check(job.progress==220 and Registry.action_available(c.officer_registry,second,c.provinces,"move",city),"pause retains work and releases duty")
	save_case("paused")
	job=Industry.jobs(c.strategy_state)[result.job_id]
	check(Industry.assign(c.strategy_state,c.provinces,"silla",job.id,city,id,stamp()).ok,"paused save resumes with selected officer")
	Industry.process(c.strategy_state,c.provinces,stamp())
	check(job.progress==220,"resume cannot replay an already elapsed month")
	tick(); check(job.progress==360,"resumed work keeps220 then adds140")
	check(Industry.cancel(c.strategy_state,c.provinces,"silla",job.id,stamp()).refund==0 and c.gold==480,"after progress cancel has no refund")
	result=begin(city,"research","archery",id); job=Industry.jobs(c.strategy_state)[result.job_id]
	tick(); var progress: int=job.progress
	c.provinces[city].faction="백제"; Production.stop_on_capture(c.strategy_state,city)
	check(job.status=="paused" and job.progress==progress and c.strategy_state.faction_research["백제"].archery==0,"research base loss pauses original country only")
	Registry.set_location(c.officer_registry,id,"geumgwan")
	check(Industry.assign(c.strategy_state,c.provinces,"silla",job.id,"geumgwan",id,stamp()).ok,"research resumes at real friendly base")
	finish(job.id)
	check(c.strategy_state.faction_research["신라"].archery==1 and c.strategy_state.faction_research["백제"].archery==0,"research never transfers to occupier")
	Registry.set_location(c.officer_registry,second,"geumgwan")
	result=begin("geumgwan","build","market",second)
	check(result.ok,"construction loss fixture")
	var balance: int=c.gold; c.provinces.geumgwan.faction="백제"; Production.stop_on_capture(c.strategy_state,"geumgwan")
	check(Industry.jobs(c.strategy_state)[result.job_id].status=="interrupted" and c.gold==balance and not Industry.cancel(c.strategy_state,c.provinces,"silla",result.job_id,stamp()).ok,"construction capture ends without refund")

func prepare_production(manager: bool) -> String:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	# This unit fixture advances industry only, not harvest. Mark excluded event
	# years explicitly; the GUI test exercises actual harvest and choice processing.
	for event_year: int in [632,633]:
		c.crop_failure_events.years[str(event_year)]={"evaluated":true,"province_id":""}
		c.harvest_events.years[str(event_year)]={"evaluated":true,"province_id":""}
	var id: String=officer("geumseong",100)
	Registry.set_location(c.officer_registry,id,"geumgwan")
	for item: Array in [["build","smelter"],["build","forge"],["research","swordsmithing"]]:
		var result: Dictionary=begin("geumgwan",item[0],item[1],id)
		check(result.ok,"native632 legal production prerequisite "+str(item[1]))
		finish(result.job_id)
	check(c.gold==240,"real prerequisite costs240+320+200=760 without altered technology/region rules")
	if manager: check(begin("geumgwan","production","",id).ok,"manager uses free officer after completion")
	for recipe: String in ["iron_supply","iron_sword"]:
		check(c.request_production_command("geumgwan",recipe,"start").ok,"native pilot recipe starts "+recipe)
	return id

func production_cases() -> void:
	for manager: bool in [false,true]:
		await prepare_production(manager)
		for n: int in range(6):
			var quoted: Dictionary=Production.city_quote(c.strategy_state,c.provinces,"geumgwan",stamp()+1,c.scenario_id,c.iron_supply_rules)
			var gold_before: int=c.gold
			tick(true)
			check(canonical(c.strategy_state.city_inventory.geumgwan)==canonical(quoted.forge.inventory) and c.gold==gold_before-int(quoted.smelter.gold_cost)-int(quoted.forge.gold_cost),"city quote and execution share preceding supply outputs and exact costs")
			if n==0:
				check(c.strategy_state.facility_progress.geumgwan.forge.remainder==(50 if manager else 0),"fractional facility work retained separately")
				save_case("fractional-"+str(manager))
				if manager:
					var current: Dictionary=Industry.active(c.strategy_state,"production","geumgwan","silla")
					var person: String=current.officer_id
					Industry.pause(c.strategy_state,"silla",current.id,stamp())
					Industry.assign(c.strategy_state,c.provinces,"silla",current.id,"geumgwan",person,stamp())
					c.request_production_command("geumgwan","iron_sword","stop"); c.request_production_command("geumgwan","iron_sword","start")
					Production.process_all(c.strategy_state,c.provinces,stamp(),c.scenario_id)
					check(c.strategy_state.city_inventory.geumgwan.sword==1 and c.strategy_state.facility_progress.geumgwan.forge.remainder==50,"stop/resume and manager replacement cannot duplicate same-month fractional work")
		check(c.strategy_state.city_inventory.geumgwan.sword==(9 if manager else 6),"six months manager%s cumulative production" % manager)
		check(c.gold==(96 if manager else 144) and c.strategy_state.city_inventory.geumgwan.iron==0,"every extra batch pays6+10gold and2iron")
		evidence.production.append({"manager":manager,"months":6,"swords":c.strategy_state.city_inventory.geumgwan.sword,"start_gold":240,"end_gold":c.gold,"iron":c.strategy_state.city_inventory.geumgwan.iron})
		var before: Dictionary=snapshot(); Production.process_all(c.strategy_state,c.provinces,stamp(),c.scenario_id)
		check(snapshot()==before,"same month facility work/cost/output no duplicate")
		save_case("production-"+str(manager))
	c.request_production_command("geumgwan","iron_supply","stop")
	for n: int in range(5): tick(true)
	check(c.strategy_state.city_inventory.geumgwan.sword==9 and c.strategy_state.facility_progress.geumgwan.forge.remainder<100,"material-blocked months do not bank integer batches")
	c.gold=5; c.request_production_command("geumgwan","iron_supply","start")
	tick(true)
	check(c.gold==5 and c.strategy_state.city_inventory.geumgwan.sword==9,"gold blocked both facilities no output or debit")
	c.gold=32; tick(true)
	check(c.strategy_state.city_inventory.geumgwan.sword==10,"unblocked month no historical catch-up batches")
	var manager_job: Dictionary=Industry.active(c.strategy_state,"production","geumgwan","silla")
	Industry.pause(c.strategy_state,"silla",manager_job.id,stamp())
	check(Industry.production_work(c.strategy_state,c.provinces,"geumgwan",stamp())==100,"no valid manager preserves base production")
	c.provinces.geumgwan.faction="백제"; Production.stop_on_capture(c.strategy_state,"geumgwan")
	check(manager_job.status=="interrupted" and c.strategy_state.facility_progress.geumgwan.forge.remainder==0 and not c.strategy_state.city_production.geumgwan.iron_sword.enabled,"capture clears manager orders and residual work")

func migration_cases() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	c.strategy_state.construction_queues.geumseong={"building_id":"academy","target_level":1,"remaining_turns":1,"assigned_officer":"","cost_paid":260,"payer_faction_id":"silla"}
	c.strategy_state.research_queues["신라"]={"research_id":"archery","target_level":1,"remaining_turns":2,"assigned_officer":""}
	var balance: int=c.gold
	Industry.normalize(c.strategy_state,c.provinces,c.strategy,stamp())
	var build: Dictionary=Industry.active(c.strategy_state,"build","geumseong","silla")
	var research: Dictionary=Industry.active(c.strategy_state,"research","","silla")
	check(build.required==600 and build.progress==300 and build.cost_paid==260 and build.status=="paused","old remaining season converted to300 work without discarding past progress/cost")
	check(research.city_id=="" and research.officer_id=="" and research.status=="paused" and not research.cost_known,"unknown old performer/base/payment never invented")
	save_case("legacy-migrated")
	build=Industry.active(c.strategy_state,"build","geumseong","silla")
	tick(); check(build.progress==300 and c.gold==balance,"unassigned legacy work remains paused without payment")
	var id: String=officer("geumseong")
	check(Industry.assign(c.strategy_state,c.provinces,"silla",build.id,"geumseong",id,stamp()).ok,"legacy work accepts explicit assignment")
	check(finish(build.id)==3 and c.gold==balance,"remaining300 resumes with no repayment")
	research=Industry.active(c.strategy_state,"research","","silla")
	check(Industry.cancel(c.strategy_state,c.provinces,"silla",research.id,stamp()).refund==0 and c.gold==balance,"unknown legacy payment never creates inferred refund")
	c.strategy_state.construction_queues.geumseong={"building_id":"market","target_level":2,"remaining_turns":1,"assigned_officer":c.get_officer(id).name,"cost_paid":400,"payer_faction_id":"silla"}
	Industry.normalize(c.strategy_state,c.provinces,c.strategy,stamp())
	var preserved: Dictionary=Industry.active(c.strategy_state,"build","geumseong","silla")
	check(preserved.officer_id==id and preserved.status=="pending" and c.gold==balance,"explicit legacy assigned name resolves to existing ID without reassignment or payment")

func concurrent_cases() -> void:
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var cities: Dictionary={"silla":"geumseong","baekje":"sabi","goguryeo":"pyongyang"}
	for faction: String in cities:
		var city: String=cities[faction]
		var case_id: String=officer(city,100)
		check(begin(city,"build","forge",case_id).ok,"concurrent national building "+faction)
	for n: int in range(4): tick()
	for faction: String in cities:
		check(c.strategy_state.province_buildings[cities[faction]].forge==1,"all nations complete before production")
		check(begin(cities[faction],"research","swordsmithing",c.get_city_officer_ids(cities[faction])[0]).ok,"concurrent national research "+faction)
	for n: int in range(2): tick()
	for faction: String in cities:
		var city: String=cities[faction]
		check(c.strategy_state.faction_research[c.provinces[city].faction].swordsmithing==1,"real prerequisite research complete "+faction)
		# Existing imported inventory fixture, no technology or region permission injection.
		c.strategy_state.city_inventory[city].iron=10
		Production.set_enabled(c.strategy_state,c.provinces,city,"iron_sword",c.provinces[city].faction,true,c.scenario_id)
	tick(true)
	for faction: String in cities:
		check(Economy.balance(c.strategy_state,faction)==470 and c.strategy_state.city_inventory[cities[faction]].sword==1,"same-month national production pays own320+200+10 "+faction)
	var id: String=c.get_city_officer_ids("geumseong")[0]
	var result: Dictionary=begin("geumseong","production","",id)
	Registry.set_alive(c.officer_registry,id,false)
	tick(true)
	check(Industry.jobs(c.strategy_state)[result.job_id].status=="paused" and Industry.production_work(c.strategy_state,c.provinces,"geumseong",stamp())==100,"lost qualification pauses manager but preserves base100")
	Registry.set_alive(c.officer_registry,id,true)
	Registry.set_location(c.officer_registry,id,"geumseong") # restore the removed location in this qualification fixture
	result=begin("geumseong","build","market",id)
	check(result.ok,"paused manager releases person for a different task")
	tick(); var progress: int=Industry.jobs(c.strategy_state)[result.job_id].progress
	Registry.set_alive(c.officer_registry,id,false); tick()
	check(Industry.jobs(c.strategy_state)[result.job_id].status=="paused" and Industry.jobs(c.strategy_state)[result.job_id].progress==progress,"builder qualification loss preserves accumulated work without advancing")

func _run() -> void:
	create_timer(150).timeout.connect(func(): push_error("INDUSTRY TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(RESULTS)
	check(Industry.efficiency({"politics":90,"intelligence":10},"build")==66 and Industry.efficiency({"politics":90,"intelligence":10},"research")==26 and Industry.efficiency({"politics":90,"intelligence":10},"production")==50,"distinct weighted efficiency formulas")
	await ability_cases(); await lifecycle(); await production_cases(); await migration_cases(); await concurrent_cases()
	var file:=FileAccess.open(RESULTS+"evidence.json",FileAccess.WRITE); file.store_string(JSON.stringify(evidence,"\t")); file.close()
	print("INDUSTRY ASSIGNMENT TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
