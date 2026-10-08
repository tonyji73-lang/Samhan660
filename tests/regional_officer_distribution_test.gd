extends "res://tests/officer_registry_test.gd"
const MAP_SCRIPT = preload("res://map_area.gd")
func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/officers_pre_regional_distribution.json"))
	var definitions := Catalog.definitions()
	var preserved := true
	for id: String in before.definitions: preserved = preserved and canonical(before.definitions[id]) == canonical(definitions[id])
	check(preserved,"all original historical and placeholder templates unchanged")
	var heavy := 0
	var military := 0
	var civilian := 0
	var female := 0
	var male := 0
	var faces: Dictionary = {}
	var names: Dictionary = {}
	var unique := true
	for d: Dictionary in definitions.values():
		if d.origin != "fictional": continue
		heavy += int(d.appearance.overweight)
		military += int(d.character_type == "무관")
		civilian += int(d.character_type == "문관")
		female += int(d.gender == "female")
		male += int(d.gender == "male")
		unique = unique and not names.has(d.display_name) and not faces.has(str(d.portrait.atlas)+":"+str(d.portrait.cell))
		names[d.display_name] = true
		faces[str(d.portrait.atlas)+":"+str(d.portrait.cell)] = true
	check(female == 76 and male == 114 and unique,"190 named fictional profiles with distinct portrait cells; 76 women,114 men")
	check(heavy <= (female+male)/10 and heavy == 19,"overweight at most 10 percent")
	check(military == 95 and civilian == 95,"military and civil profiles independently classified")
	var totals: Array = []
	for scenario: Dictionary in Scenarios.SCENARIOS:
		await start(scenario,"silla","historical")
		var row := {"year":c.year,"factions":{}}
		var valid := true
		var governors := true
		var historical := true
		for city: String in c.provinces:
			var ids: Array = c.get_city_officer_ids(city)
			var faction: String = c.provinces[city].faction
			if not row.factions.has(faction): row.factions[faction] = {"cities":0,"people":0,"min":100,"max":0}
			var f: Dictionary = row.factions[faction]
			f.cities += 1; f.people += ids.size(); f.min = mini(f.min,ids.size()); f.max = maxi(f.max,ids.size())
			valid = valid and ids.size() >= 2 and ids.size() <= 10
			for id: String in ids: valid = valid and Registry.eligible(c.officer_registry,id,c.provinces,city)
			var governor: String = c.get_governor_id(city)
			governors = governors and governor in ids
		for old: Dictionary in before.scenarios[scenario.id].entries:
			var person: Dictionary = c.officer_registry.people[old.officer_id]
			historical = historical and person.active and person.faction_id == old.faction_id and person.name == old.display_name
		check(valid,"all cities have 2-10 locally eligible officers "+str(c.year))
		check(governors,"all existing cities have eligible governors "+str(c.year))
		check(historical,"existing historical identities and factions preserved "+str(c.year))
		for plan: Dictionary in Catalog.data().regional_distribution.city_plans:
			if plan.scenario == scenario.id:
				check(c.get_city_officer_ids(plan.city).size() == maxi(plan.target,plan.historical_or_existing),"target matches actual "+str(c.year)+"/"+plan.city)
		totals.append(row)
		roundtrip("regional-"+str(c.year))
	# Loading a pre-expansion native registry must not redistribute or backfill it.
	await start(Scenarios.SCENARIOS[0],"silla","historical")
	var old_state: Dictionary = c.strategy_state.duplicate(true)
	for id: String in old_state.officer_registry.people.keys():
		if id.begins_with("fictional:"): old_state.officer_registry.people.erase(id)
	for post: String in old_state.officer_registry.posts.keys():
		if str(old_state.officer_registry.posts[post]).begins_with("fictional:"): old_state.officer_registry.posts.erase(post)
	var untouched: Dictionary = canonical(old_state.officer_registry)
	Registry.migrate({},old_state,c.provinces,c.scenario_id,Catalog.data().legacy_campaign)
	check(canonical(old_state.officer_registry) == untouched,"native old save never receives added or relocated officers")
	var f := FileAccess.open("res://.godot/officer-distribution-review/after.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(totals,"\t"))
	print("REGIONAL OFFICERS: ",checks," checks; ",failures," failures")
	quit(1 if failures else 0)