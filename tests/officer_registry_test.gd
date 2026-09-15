extends SceneTree

const Registry = preload("res://officer_registry.gd")
const Catalog = preload("res://officer_catalog.gd")
const Scenarios = preload("res://scenario_data.gd")
const Campaign = preload("res://campaign_main.tscn")
const OUT = "res://.godot/officer-results/"
var checks: int = 0
var failures: int = 0
var c: Node
var census: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else: print("PASS: " + label)

func canonical(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func start(scenario: Dictionary, faction: String, mode: String) -> void:
	if is_instance_valid(c):
		c.queue_free()
		await process_frame
	root.set_meta("new_game_settings", {"faction":faction,"play_style":mode,"difficulty":"normal",
		"scenario_id":scenario.id,"scenario_year":scenario.year,"scenario_season":scenario.season})
	c = Campaign.instantiate()
	root.add_child(c)
	current_scene = c
	c.event_presentation.display_level = "minimal"
	await process_frame
	await process_frame

func snapshot() -> Dictionary:
	var state: Dictionary = Registry.export_strategy(c.strategy_state)
	state.erase("unit_rosters") # pre-existing battle cache, not authoritative troop count
	return canonical({"registry":c.officer_registry,"state":state,"provinces":c.provinces,
		"orders":c.pending_transfer_orders,"gold":c.gold,"year":c.year,"month":c.month,
		"crop":c.crop_failure_events,"harvest":c.harvest_events})

func roundtrip(label: String) -> void:
	var before: Dictionary = snapshot()
	var path: String = OUT+label+".json"
	c._on_save_button_pressed(path)
	for n: int in range(3):
		c._on_load_button_pressed(path)
		check(snapshot() == before,label+": repeated native load %d preserves complete state" % n)
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(not stored.has("officers_by_province") and not stored.strategy_state.dynasty.has("people") and not stored.strategy_state.has("emergent_officers"),label+": one serialized registry")

func census_case(scenario: Dictionary, mode: String) -> void:
	var r: Dictionary = c.officer_registry
	var entries: Array = Catalog.scenario(scenario.id).entries
	var ids: Dictionary = {}
	var valid: bool = true
	for row: Dictionary in entries:
		valid = valid and not ids.has(row.officer_id)
		ids[row.officer_id] = true
		var p: Dictionary = r.people.get(row.officer_id,{})
		valid = valid and not p.is_empty() and p.active and p.alive and p.faction_id == row.faction_id and p.location == row.location
		if not row.location.is_empty(): valid = valid and Registry.eligible(r,row.officer_id,c.provinces,row.location)
		var d: Dictionary = Catalog.definitions()[row.catalog_id]
		valid = valid and (int(d.birth.year) == 0 or int(d.birth.year) <= c.year)
		valid = valid and (int(d.death.year) == 0 or int(d.death.year) >= c.year)
		valid = valid and (int(d.birth.game_year) <= c.year or not str(row.exception).is_empty())
		if row.ruler: valid = valid and r.posts.get("ruler:"+row.faction_id,"") == row.officer_id
	for id: String in r.people:
		valid = valid and (not r.people[id].active or ids.has(id)) and r.people[id].origin not in ["generated","dynastic"]
	check(valid,"%s/%s all AI and player entries, identity, dates, positions and rulers" % [scenario.id,mode])
	if mode != "historical": return
	for faction: String in r.factions:
		var row: Dictionary = {"year":c.year,"faction":faction,"name":r.factions[faction],"rulers":0,"active":0,"placed":0,"unplaced":0,"cities":0,"vacant":0}
		for p: Dictionary in r.people.values():
			if p.active and p.faction_id == faction:
				row.active += 1
				if p.location.is_empty(): row.unplaced += 1
				else: row.placed += 1
		row.rulers = 1 if r.posts.has("ruler:"+faction) else 0
		for city: String in c.provinces:
			if c.provinces[city].faction == row.name:
				row.cities += 1
				if c.get_governor_id(city).is_empty(): row.vacant += 1
		row["shortage"] = maxi(0,maxi(2,int(row.cities)+1)-int(row.placed)) if row.cities > 0 else 0
		census.append(row)
	var extra_owners: Dictionary = {}
	for city: String in c.provinces:
		var owner: String = c.provinces[city].faction
		if Registry.faction_id(r,owner).is_empty(): extra_owners[owner]=int(extra_owners.get(owner,0))+1
	for owner: String in extra_owners:
		census.append({"year":c.year,"faction":"unrepresented","name":owner,"rulers":0,"active":0,"placed":0,"unplaced":0,"cities":extra_owners[owner],"vacant":extra_owners[owner],"shortage":int(extra_owners[owner])+1})

func _run() -> void:
	create_timer(180.0).timeout.connect(func(): push_error("OFFICER TIMEOUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	check(Catalog.definitions().size()==69,"71 DB entries consolidate to 69 templates")
	check(Catalog.resolve("고교쿠 천황")==Catalog.resolve("사이메이 천황") and Catalog.resolve("나카노오에 황자")==Catalog.resolve("덴지 천황"),"sourced Japanese title aliases share identity")
	check(Catalog.resolve("문무왕")==Catalog.resolve("김법민") and Catalog.resolve("무열왕")==Catalog.resolve("김춘추"),"Korean royal title aliases")
	var combinations: int = 0
	for scenario: Dictionary in Scenarios.SCENARIOS:
		var expected: Dictionary = {}
		for mode: String in ["historical","fictional"]:
			var first: bool = true
			for faction: String in Scenarios.get_active_faction_ids(scenario.id):
				if not Scenarios.is_faction_playable_by_default(scenario.id,faction): continue
				await start(scenario,faction,mode)
				combinations += 1
				check(c.year==scenario.year and c.player_faction_id==faction and c.play_style==mode,"actual startup %s/%s/%s" % [scenario.id,faction,mode])
				if expected.is_empty(): expected=canonical(c.officer_registry)
				check(canonical(c.officer_registry)==expected,"same full roster regardless of selected player/mode")
				if first: census_case(scenario,mode)
				first=false
	check(combinations==24,"12 selectable scenario/faction combinations in both modes")
	var file := FileAccess.open(OUT+"census.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(census,"\t")); file.close()
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	generated_actions()
	migration_fixture()
	legacy_foundation()
	print("OFFICER REGISTRY TESTS: %d checks, %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)

func generated_actions() -> void:
	c.strategy.auto_fill_officer_shortages(c.strategy_state,c.year,c.provinces,c.officers_by_province,Scenarios.get_scenario(c.scenario_id))
	var r: Dictionary = c.officer_registry
	var generated: Array[String] = []
	for id: String in r.people:
		if r.people[id].origin=="generated" and r.people[id].faction_id=="silla": generated.append(id)
	check(generated.size()==2,"existing automatic cap: two Silla recruits")
	if generated.is_empty(): return
	var count_before: int = r.people.size()
	c.strategy.auto_fill_officer_shortages(c.strategy_state,c.year,c.provinces,c.officers_by_province,Scenarios.get_scenario(c.scenario_id))
	check(r.people.size()==count_before,"same year automatic generation is idempotent")
	var id: String = generated[0]
	var source: String = r.people[id].location
	check(c.get_city_officer_ids(source).has(id),"generated recruit appears in city list")
	check(c._apply_governor_appointment(source,id).ok and c.get_governor_id(source)==id,"generated recruit appointed governor")
	check(c.get_best_commander(source).officer_id==id,"generated recruit selected as actual commander in newly staffed city")
	var found: bool = false
	for envoy: Dictionary in c.get_diplomacy_envoys(): found = found or envoy.officer_id==id
	check(found,"generated recruit available as diplomatic envoy")
	var result: Dictionary = c.request_diplomatic_action("baekje","gift",id)
	check(result.get("executed",false),"generated envoy executes real gift action")
	roundtrip("generated-envoy")
	check(not c.request_diplomatic_action("baekje","gift",id).get("executed",false),"envoy monthly action restriction survives load")
	var target: String = ""
	for city: String in c.provinces:
		if city!=source and c.provinces[city].faction==c.player_faction and c.are_provinces_connected(source,city): target=city; break
	check(not target.is_empty(),"generated recruit has valid adjacent destination")
	if target.is_empty(): return
	var order: Dictionary = {"source_id":source,"target_id":target,"officer_ids":[id],"troops":0}
	check(c.queue_province_transfer(order,true).ok and c.is_officer_transfer_pending(id),"generated governor enters transfer queue")
	check(c.get_governor_id(source).is_empty() and not c.validate_governor_appointment(source,id).ok,"departed governor cannot be appointed")
	check(not c.strategy.get_diplomatic_envoy(c.strategy_state,c.player_faction,id,c.provinces,{},{}).ok,"in-transit generated envoy unavailable")
	roundtrip("generated-transit")
	c.process_pending_transfer_orders()
	check(c.get_city_officer_ids(target).has(id) and not c.is_officer_transfer_pending(id),"generated officer arrives once")
	var after: Dictionary = canonical(c.officer_registry)
	c.process_pending_transfer_orders()
	check(canonical(c.officer_registry)==after,"reprocessing arrivals cannot duplicate officer")
	roundtrip("generated-arrived")
	# Existing age-16 growth path, isolated child fixture; no mass recruitment.
	var child_id: String = Registry.register_generated(c.officer_registry,{"name":"성장검증","birth_year":616,"stats":{"leadership":61,"war":62,"intelligence":63,"politics":64,"authority":65}},"신라","","dynastic","dynastic:test-child")
	c.officer_registry.people[child_id].active=false
	c.strategy_state.dynasty.children["test-child"]={"id":"test-child","officer_id":child_id,"name":"성장검증","birth_year":616,"adult":false,"faction":"신라","parent_a":"","parent_b":"","mentor":"","education":"balanced","stats":c.officer_registry.people[child_id].stats}
	c.strategy._registry_dynasty_year(c.strategy_state,632,c.provinces,Scenarios.get_scenario(c.scenario_id))
	check(c.officer_registry.people[child_id].active and not c.officer_registry.people[child_id].location.is_empty(),"grown child enters same registry with existing ID")
	var child_before: Dictionary = canonical(c.officer_registry)
	c.strategy._registry_dynasty_year(c.strategy_state,632,c.provinces,Scenarios.get_scenario(c.scenario_id))
	check(canonical(c.officer_registry)==child_before,"grown child not registered twice")
	roundtrip("grown-child")
	# No new annual history enforcement: a live transferred person survives 700.
	c.strategy._registry_dynasty_year(c.strategy_state,700,c.provinces,Scenarios.get_scenario(c.scenario_id))
	check(c.get_officer("선덕여왕").alive,"historical death year never forcibly removes playing character")
	var first_id: String = Registry.register_generated(c.officer_registry,{"name":"동명이인검증"},"신라",target)
	var second_id: String = Registry.register_generated(c.officer_registry,{"name":"동명이인검증"},"신라",target)
	check(first_id!=second_id and Registry.resolve(c.officer_registry,"동명이인검증").is_empty(),"same name never merges distinct generated identities")
	check(c.get_officer(first_id).name==c.get_officer(second_id).name and c.validate_governor_appointment(target,first_id).ok and c.validate_governor_appointment(target,second_id).ok,"ambiguous names remain individually appointable by ID")
	roundtrip("duplicate-display-names")
	Registry.set_identity_links(c.officer_registry,first_id,"test-family","test-group")
	Registry.set_duties(c.officer_registry,first_id,[{"kind":"test-duty"}])
	check(c.get_officer(first_id).family_id=="test-family" and c.get_officer(first_id).political_group_id=="test-group" and c.get_officer(first_id).authority==50,"family/group/duty links do not reinterpret authority")

func migration_fixture() -> void:
	var source: Dictionary = {"officers_by_province":{"a":["김유신","낯선 인물"],"b":["김유신"]},"pending_transfer_orders":[{"source_id":"a","target_id":"b","faction":"신라","officers":["생성검증"],"remaining_turns":1}]}
	var stats: Dictionary = {"leadership":61,"war":62,"intelligence":63,"politics":64,"authority":65,"name":"생성검증","birth_year":600}
	var state: Dictionary = {"officer_metadata":{"김유신":{"faction":"백제","origin":"historical"},"생성검증":{"faction":"신라","origin":"generated"}},"emergent_officers":{"생성검증":stats},
		"dynasty":{"people":{"생성검증":{"stats":stats,"spouse":"관계만 존재","alive":true}},"marriages":[{"person_a":"생성검증","person_b":"관계만 존재"}],"children":{}}}
	var provinces: Dictionary = {"a":{"faction":"당","governor":"낯선 인물"},"b":{"faction":"신라","governor":"생성검증"}}
	var r: Dictionary = Registry.migrate(source,state,provinces,Scenarios.SCENARIOS[0].id,Catalog.data().legacy_campaign)
	var id: String = r.legacy_reference_map["생성검증"]
	check(r.people[id].stats.politics==64 and r.people[id].birth_year==600,"legacy generated stats and year preserved")
	check(r.people[r.legacy_reference_map["김유신"]].faction_id=="baekje","saved affiliation beats initial roster and city ownership")
	check(r.people.has(r.people[id].spouse) and state.dynasty.marriages[0].person_a==id,"relation-only unknown and marriage references preserved by ID")
	check(r.people.has(r.legacy_reference_map["낯선 인물"]) and r.posts["governor:a"]==r.legacy_reference_map["낯선 인물"],"unknown governor preserved without inventing affiliation")
	check(r.diagnostics.size()>=3 and r.legacy_archive.assignments==source.officers_by_province,"unknown and duplicate original records recoverable with diagnostics")
	var orders: Array = Registry.migrate_orders(r,source.pending_transfer_orders)
	check(orders[0].officer_ids==[id] and r.people[id].in_transit,"legacy generated transfer reference migrated")
	var native: Dictionary = canonical(Registry.export_strategy(state))
	var again: Dictionary = Registry.migrate({},native,provinces,Scenarios.SCENARIOS[0].id,{})
	check(canonical(again)==canonical(r),"migrated IDs remain stable on native reload")

func legacy_foundation() -> void:
	var path: String = "res://tests/fixtures/officer_legacy_foundation.json"
	if not FileAccess.file_exists(path): check(false,"actual foundation legacy save exists"); return
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(not old.strategy_state.has("officer_registry"),"actual previous integration save is name-based")
	c._on_load_button_pressed(path)
	check(c.gold==old.gold and c.year==old.year and c.month==old.month,"actual legacy save resources and date preserved")
	var unchanged: bool = true
	for key: String in old.strategy_state:
		if key not in ["officer_metadata","emergent_officers","dynasty","unit_rosters"]:
			var restored: Variant=canonical(c.strategy_state.get(key))
			if key=="city_production":
				for city: String in restored:
					if not old.strategy_state[key].get(city,{}).has("iron_procurement"):
						check(not restored[city].iron_procurement.enabled,"legacy new common recipe stays disabled")
						restored[city].erase("iron_procurement")
			unchanged = unchanged and restored==old.strategy_state[key]
	check(unchanged,"production, diplomacy, event receipts and monthly stamps survive actual migration")
	var military: bool = true
	for city: String in old.provinces:
		for key: String in ["faction","troops","food"]: military = military and c.provinces[city].get(key)==old.provinces[city].get(key)
	check(military,"city owners, troops and food untouched by migration")
	roundtrip("migrated-foundation")
