extends RefCounted
const Power=preload("res://noble_power_constraints.gd")

const Politics=preload("res://noble_politics.gd")
const Catalog = preload("res://officer_catalog.gd")
const STATS = ["leadership", "war", "intelligence", "politics", "authority"]

static func empty(scenario_id: String) -> Dictionary:
	return {"version": 1, "scenario_id": scenario_id, "people": {}, "posts": {},
		"factions": Catalog.scenario(scenario_id).get("factions", {}).duplicate(true),
		"diagnostics": [], "legacy_archive": {}, "next_generated_id": 1}

static func new_game(scenario_id: String, provinces: Dictionary) -> Dictionary:
	var registry: Dictionary = empty(scenario_id)
	# Inactive named people remain addressable without being recruited or killed
	# by an annual date check. Generic unknown chiefs are scenario-scoped people.
	for id: String in Catalog.definitions():
		var d: Dictionary = Catalog.definitions()[id]
		if d.origin == "placeholder":
			continue
		var p: Dictionary = _from_definition(d, id)
		p["active"] = false
		p["life_status"] = "unknown"
		var start_year: int = int(Catalog.scenario(scenario_id).year)
		if d.death.certainty == "confirmed" and int(d.death.year) > 0 and int(d.death.year) < start_year:
			p.alive = false
			p.life_status = "deceased_before_start"
		elif d.birth.certainty == "confirmed" and int(d.birth.year) > start_year:
			p.alive = false
			p.life_status = "not_born_at_start"
		p["availability_reason"] = Catalog.scenario(scenario_id).get("excluded", {}).get(id, "not_in_start_activity_roster")
		registry.people[id] = p
	for row: Dictionary in Catalog.scenario(scenario_id).get("entries", []):
		var p: Dictionary = _from_definition(Catalog.definitions()[row.catalog_id], row.officer_id)
		p["name"] = row.display_name
		p["active"] = true
		p["life_status"] = "alive_at_start"
		p["faction_id"] = row.faction_id
		p["location"] = row.location
		p["availability_reason"] = row.get("exception", "")
		p["placement_note"] = row.placement_note
		p["desired_location"] = row.desired_location
		if not p.location.is_empty() and not provinces.has(p.location):
			p.location = ""
			diagnose(registry, "unrepresented_location", row)
		registry.people[p.officer_id] = p
		if row.ruler:
			registry.posts["ruler:" + row.faction_id] = p.officer_id
	# Governor appointment is explicit first-placed order within the manifest.
	# Ruler status does not grant governorship; rulers may be appointed manually.
	for row: Dictionary in Catalog.scenario(scenario_id).get("entries", []):
		var p: Dictionary = registry.people[row.officer_id]
		if not row.ruler and eligible(registry, p.officer_id, provinces, p.location):
			var key: String = "governor:" + str(p.location)
			if not registry.posts.has(key):
				registry.posts[key] = p.officer_id
	return registry

static func _from_definition(d: Dictionary, id: String) -> Dictionary:
	return {"officer_id": id, "catalog_id": d.officer_id, "name": d.display_name,
		"aliases": d.aliases.duplicate(), "stats": d.base_stats.duplicate(true),
		"origin": d.origin, "active": false, "alive": true, "faction_id": "", "location": "", "in_transit": false,
		"family_id": "", "political_group_id": "", "duties": [],
		"birth_year": d.birth.game_year, "death_year": d.death.game_year, "date_basis": "legacy_game_years; historical confidence in catalog",
		"gender": "unknown", "spouse": "", "parents": [], "children": [], "rng_identity": d.display_name}

static func resolve(registry: Dictionary, reference: String) -> String:
	if registry.get("people", {}).has(reference):
		return reference
	var matches: Array[String] = []
	for id: String in registry.get("people", {}):
		var p: Dictionary = registry.people[id]
		if p.name == reference or p.get("aliases", []).has(reference):
			matches.append(id)
	return matches[0] if matches.size() == 1 else ""

static func get_person(registry: Dictionary, reference: String) -> Dictionary:
	return registry.get("people", {}).get(resolve(registry, reference), {})

static func faction_id(registry: Dictionary, faction: String) -> String:
	if registry.get("factions", {}).has(faction):
		return faction
	for id: String in registry.get("factions", {}):
		if registry.factions[id] == faction or id == "yamato" and faction in ["왜(야마토)", "왜(야마토 조정)"]:
			return id
	return ""

static func faction_name(registry: Dictionary, p: Dictionary) -> String:
	return registry.get("factions", {}).get(p.get("faction_id", ""), p.get("legacy_faction", ""))

static func view(registry: Dictionary, reference: String) -> Dictionary:
	var p: Dictionary = get_person(registry, reference)
	if p.is_empty():
		return {}
	var result: Dictionary = p.duplicate(true)
	result.merge(p.stats, true)
	result["faction"] = faction_name(registry, p)
	result["is_historical"] = p.origin == "historical"
	result["faction_screen_eligible"] = p.origin == "historical"
	return result

static func name_view(registry: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for id: String in registry.get("people", {}):
		var p: Dictionary = registry.people[id]
		# Ambiguous names are deliberately not aliases for either person.
		if resolve(registry, p.name) == id:
			result[p.name] = view(registry, id)
	return result

static func at_city(registry: Dictionary, city: String) -> Array[String]:
	var result: Array[String] = []
	for id: String in registry.get("people", {}):
		var p: Dictionary = registry.people[id]
		if p.get("active", false) and p.get("alive", true) and not p.get("in_transit", false) and p.get("location", "") == city and not city.is_empty():
			result.append(id)
	return result

static func assignments(registry: Dictionary, names: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for id: String in registry.get("people", {}):
		var p: Dictionary = registry.people[id]
		var city: String = str(p.get("location", ""))
		if city.is_empty() or not p.get("active", false) or not p.get("alive", true) or p.get("in_transit", false):
			continue
		if not result.has(city): result[city] = []
		result[city].append(p.name if names and resolve(registry, p.name) == id else id)
	return result

static func eligible(registry: Dictionary, reference: String, provinces: Dictionary, city: String = "") -> bool:
	var p: Dictionary = get_person(registry, reference)
	if p.is_empty() or not p.get("active", false) or not p.get("alive", true) or p.get("in_transit", false):
		return false
	var place: String = str(p.get("location", ""))
	return not place.is_empty() and (city.is_empty() or place == city) and provinces.has(place) and faction_name(registry, p) == str(provinces[place].get("faction", ""))

static func set_stats(registry: Dictionary, reference: String, stats: Dictionary) -> bool:
	var p: Dictionary = get_person(registry, reference)
	if p.is_empty(): return false
	for key: String in STATS:
		if stats.has(key): p.stats[key] = int(stats[key])
	return true

static func action_available(registry: Dictionary, reference: String, provinces: Dictionary, action: String, city: String = "") -> bool:
	if not eligible(registry,reference,provinces,city): return false
	if action in ["defense","governor"]: return true
	for duty: Variant in get_person(registry,reference).get("duties",[]):
		if duty is Dictionary and duty.get("kind","") in ["domestic","industry","training"]: return false
	return true

static func set_location(registry: Dictionary, reference: String, city: String, in_transit: bool = false) -> bool:
	var id: String = resolve(registry, reference)
	if id.is_empty(): return false
	var p: Dictionary = registry.people[id]
	if not Power.location_reason(registry,id,city,in_transit).is_empty(): return false
	if p.location != city or in_transit:
		for post: String in registry.posts.keys():
			if post.begins_with("governor:") and registry.posts[post] == id: set_post(registry,post,"","이동")
	p.location = city
	p.in_transit = in_transit
	return true

static func set_faction(registry: Dictionary, reference: String, new_faction_id: String) -> bool:
	var p: Dictionary = get_person(registry, reference)
	if p.is_empty() or not registry.factions.has(new_faction_id): return false
	p.faction_id = new_faction_id
	for post: String in registry.posts.keys():
		if registry.posts[post] == p.officer_id: set_post(registry,post,"","소속 변경")
	return true

static func set_post(registry: Dictionary, post: String, reference: String, reason: String = "임명/해임") -> bool:
	var id: String = resolve(registry,reference) if not reference.is_empty() else ""
	if not reference.is_empty() and id.is_empty(): return false
	var previous: String = str(registry.posts.get(post,""))
	if previous==id: return true
	if not Power.guard_post(registry,post,id,reason): return false
	if post.begins_with("governor:") and not id.is_empty():
		for other: String in registry.posts.keys():
			if other!=post and other.begins_with("governor:") and registry.posts[other]==id: set_post(registry,other,"","다른 도시 임명")
	if id.is_empty(): registry.posts.erase(post)
	else: registry.posts[post]=id
	if not registry.has("post_history"): registry.post_history=[]
	Politics.post_changed(registry,post,previous,id,reason)
	registry.post_history.append({"post":post,"city_id":post.trim_prefix("governor:") if post.begins_with("governor:") else "","officer_id":id if not id.is_empty() else previous,"previous_id":previous,"new_id":id,"month":registry.get("clock_month",0),"reason":reason})
	return true

static func set_duties(registry: Dictionary, reference: String, duties: Array) -> bool:
	var p: Dictionary = get_person(registry, reference)
	if p.is_empty(): return false
	p.duties = duties.duplicate(true)
	return true

static func set_identity_links(registry: Dictionary, reference: String, family: String, political_group: String) -> bool:
	var p: Dictionary = get_person(registry, reference)
	if p.is_empty(): return false
	p.family_id = family
	p.political_group_id = political_group
	return true

static func set_alive(registry: Dictionary, reference: String, alive: bool) -> bool:
	var p: Dictionary = get_person(registry, reference)
	if p.is_empty(): return false
	p.alive = alive
	if not alive:
		set_location(registry, p.officer_id, "")
		for post: String in registry.posts.keys():
			if registry.posts[post] == p.officer_id: set_post(registry,post,"","생존 자격 변경")
	return true

static func governor_id(registry: Dictionary, city: String) -> String:
	return str(registry.get("posts", {}).get("governor:" + city, ""))

static func sync_province_labels(registry: Dictionary, provinces: Dictionary) -> void:
	for city: String in provinces:
		var p: Dictionary = get_person(registry, governor_id(registry, city))
		provinces[city]["governor"] = str(p.name) if not p.is_empty() else "태수 없음"
		provinces[city]["generals"] = []

static func register_generated(registry: Dictionary, officer: Dictionary, faction: String, city: String, origin: String = "generated", stable_id: String = "") -> String:
	var id: String = stable_id
	if id.is_empty():
		id = "generated:%s:%06d" % [registry.scenario_id, int(registry.next_generated_id)]
		registry.next_generated_id = int(registry.next_generated_id) + 1
	if registry.people.has(id): return id
	var stats: Dictionary = {}
	for key: String in STATS: stats[key] = int(officer.get(key, officer.get("stats", {}).get(key, 50)))
	registry.people[id] = {"officer_id": id, "catalog_id": "", "name": str(officer.get("name", id)), "aliases": [], "stats": stats,
		"origin": origin, "active": true, "alive": true, "location": city, "faction_id": faction_id(registry, faction), "legacy_faction": faction,
		"in_transit": false, "birth_year": officer.get("birth_year", 0), "death_year": officer.get("death_year", 0), "gender": officer.get("gender", "unknown"),
		"family_id": "", "political_group_id": "", "duties": [], "spouse": "", "parents": [], "children": [],
		"skills": officer.get("skills", []).duplicate(), "quality_tier": officer.get("quality_tier", "ordinary"), "rng_identity": str(officer.get("name", id))}
	return id

static func diagnose(registry: Dictionary, code: String, details: Variant) -> void:
	var entry: Dictionary = {"code": code, "details": details.duplicate(true) if details is Dictionary or details is Array else details}
	if not registry.diagnostics.has(entry): registry.diagnostics.append(entry)

static func bind_dynasty(state: Dictionary) -> void:
	var r: Dictionary = state.get("officer_registry", {})
	if r.is_empty(): return
	# Shared references, not parallel mutable copies. Serialization omits mirrors.
	state.dynasty.people = r.people
	for child_id: String in state.dynasty.get("children", {}):
		var child: Dictionary = state.dynasty.children[child_id]
		var id: String = str(child.get("officer_id", "dynastic:" + child_id))
		child["officer_id"] = id
		if r.people.has(id): child["stats"] = r.people[id].stats
	state.erase("officer_metadata")
	state.erase("emergent_officers")

static func export_strategy(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	if result.has("officer_registry"):
		result.dynasty.erase("people")
		for child: Dictionary in result.dynasty.get("children", {}).values(): child.erase("stats")
		result.erase("officer_metadata")
		result.erase("emergent_officers")
	return result

static func migrate(save: Dictionary, state: Dictionary, provinces: Dictionary, scenario_id: String, legacy_defaults: Dictionary) -> Dictionary:
	if state.get("officer_registry", {}) is Dictionary and not state.get("officer_registry", {}).is_empty():
		var native: Dictionary = state.officer_registry
		bind_dynasty(state)
		return native
	var r: Dictionary = empty(scenario_id)
	var metadata: Dictionary = state.get("officer_metadata", {})
	var emergent: Dictionary = state.get("emergent_officers", {})
	var people: Dictionary = state.get("dynasty", {}).get("people", {})
	var assignments_value: Dictionary = save.get("officers_by_province", {})
	r.legacy_archive = {"metadata": metadata.duplicate(true), "emergent": emergent.duplicate(true), "dynasty": state.get("dynasty", {}).duplicate(true),
		"assignments": assignments_value.duplicate(true), "transfer_orders": save.get("pending_transfer_orders", []).duplicate(true), "officers":save.get("officers",{}).duplicate(true), "governors": {}}
	var refs: Dictionary = {}
	var names: Dictionary = {}
	var child_names: Dictionary = {}
	for source: Dictionary in [metadata, emergent, people, save.get("officers", {})]:
		for key: String in source: names[key] = true
	for values: Array in assignments_value.values():
		for key: String in values: names[key] = true
	for order: Dictionary in save.get("pending_transfer_orders", []):
		for key: String in order.get("officers", []): names[key] = true
	for city: String in provinces:
		var label: String = str(provinces[city].get("governor", ""))
		r.legacy_archive.governors[city] = label
		if not label in ["", "태수 없음", "수비대장"]: names[label] = true
	# Include relation-only references without silently losing missing people.
	for person: Dictionary in people.values():
		for key: String in person.get("parents", []) + person.get("children", []):
			if not key.is_empty(): names[key] = true
		if not str(person.get("spouse", "")).is_empty(): names[str(person.spouse)] = true
	for marriage: Dictionary in state.get("dynasty", {}).get("marriages", []):
		for field: String in ["person_a", "person_b"]:
			if not str(marriage.get(field, "")).is_empty(): names[str(marriage[field])] = true
	for child: Dictionary in state.get("dynasty", {}).get("children", {}).values():
		child_names[str(child.get("name", ""))] = true
		for field: String in ["name", "parent_a", "parent_b", "mentor"]:
			if not str(child.get(field, "")).is_empty(): names[str(child[field])] = true
	for name: String in names:
		var raw: Dictionary = people.get(name, {}).duplicate(true)
		var origin: String = str(metadata.get(name, {}).get("origin", raw.get("origin", "historical")))
		if child_names.has(name): origin = "dynastic"
		elif emergent.has(name) and origin == "historical": origin = "generated"
		var catalog_id: String = Catalog.resolve(name) if origin == "historical" and not emergent.has(name) else ""
		var id: String = catalog_id if not catalog_id.is_empty() else "legacy:" + (origin + "|" + name).sha256_text().substr(0, 24)
		refs[name] = id
		if r.people.has(id):
			diagnose(r, "alias_records_consolidated", {"alias": name, "id": id})
			continue
		var p: Dictionary
		if not catalog_id.is_empty():
			p = _from_definition(Catalog.definitions()[id], id)
		else:
			register_generated(r, {"name": name}, "", "", origin if emergent.has(name) or child_names.has(name) else "legacy_unresolved", id)
			p = r.people[id]
			if not emergent.has(name): diagnose(r, "unidentified_preserved", {"reference":name,"officer_id":id})
		p.name = name
		p["rng_identity"] = name
		p.active = true
		p.alive = bool(raw.get("alive", true))
		var saved_faction: String = str(metadata.get(name, {}).get("faction", raw.get("faction", "")))
		if saved_faction.is_empty() and not catalog_id.is_empty():
			for row: Dictionary in Catalog.scenario(scenario_id).get("entries", []):
				if row.catalog_id == catalog_id: saved_faction = r.factions.get(row.faction_id, "")
		p.faction_id = faction_id(r, saved_faction)
		p["legacy_faction"] = saved_faction
		if not catalog_id.is_empty():
			for row: Dictionary in Catalog.scenario(scenario_id).get("entries", []):
				if row.catalog_id == catalog_id and row.faction_id != p.faction_id:
					diagnose(r,"saved_faction_preserved_over_initial",{"id":id,"saved":saved_faction,"initial":row.faction_id})
		var stats: Dictionary = raw.get("stats", legacy_defaults.get(name, Catalog.legacy_database().get(name, {})))
		if save.get("officers", {}).has(name): stats = save.officers[name]
		if emergent.has(name): stats = emergent[name]
		for stat: String in STATS:
			if stats.has(stat): p.stats[stat] = int(stats[stat])
		for field: String in ["birth_year", "death_year", "gender", "spouse", "parents", "children"]:
			if raw.has(field): p[field] = raw[field]
			elif emergent.get(name, {}).has(field): p[field] = emergent[name][field]
		for field: String in ["skills", "quality_tier", "role", "portrait_profile"]:
			if emergent.get(name, {}).has(field): p[field] = emergent[name][field]
		r.people[id] = p
	for city: String in assignments_value:
		for name: String in assignments_value[city]:
			var id: String = refs.get(name, "")
			if id.is_empty(): continue
			if not r.people[id].location.is_empty() and r.people[id].location != city:
				diagnose(r, "duplicate_assignment_preserved_in_archive", {"id":id,"kept":r.people[id].location,"other":city})
				continue
			r.people[id].location = city
	for city: String in provinces:
		var id: String = refs.get(str(provinces[city].get("governor", "")), "")
		if not id.is_empty():
			if r.people[id].location.is_empty(): r.people[id].location = city
			if r.people[id].location == city: r.posts["governor:"+city] = id
			else: diagnose(r,"conflicting_governor_preserved_in_archive", {"city":city,"id":id})
	for row: Dictionary in Catalog.scenario(scenario_id).get("entries", []):
		if row.ruler and r.people.has(row.officer_id): r.posts["ruler:"+row.faction_id] = row.officer_id
	for p: Dictionary in r.people.values():
		if not p.location.is_empty() and (not provinces.has(p.location) or provinces[p.location].get("faction","") != faction_name(r,p)):
			diagnose(r,"saved_location_faction_mismatch_preserved",{"id":p.officer_id,"location":p.location,"faction_id":p.faction_id})
		p.spouse = refs.get(str(p.get("spouse", "")), "")
		for field: String in ["parents", "children"]:
			var converted: Array = []
			for ref: String in p.get(field, []): converted.append(refs.get(ref, ref))
			p[field] = converted
	for marriage: Dictionary in state.get("dynasty", {}).get("marriages", []):
		marriage["legacy_rng_pair"] = [marriage.get("person_a",""), marriage.get("person_b","")]
		for field: String in ["person_a", "person_b"]: marriage[field] = refs.get(str(marriage.get(field, "")), "")
	for child: Dictionary in state.get("dynasty", {}).get("children", {}).values():
		child["officer_id"] = refs.get(str(child.get("name", "")), "")
		for field: String in ["parent_a", "parent_b", "mentor"]: child[field] = refs.get(str(child.get(field, "")), "")
		if r.people.has(child.officer_id):
			var p: Dictionary = r.people[child.officer_id]
			p.active = bool(child.get("adult", false))
			p.birth_year = child.get("birth_year", p.birth_year)
			p.parents = [child.parent_a, child.parent_b]
			if child.has("stats") and not p.active: p.stats = child.stats.duplicate(true)
	r["legacy_reference_map"] = refs
	state["officer_registry"] = r
	bind_dynasty(state)
	return r

static func migrate_orders(registry: Dictionary, orders: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source: Dictionary in orders:
		var order: Dictionary = source.duplicate(true)
		var ids: Array[String] = []
		for ref: String in order.get("officer_ids", order.get("officers", [])):
			var id: String = str(registry.get("legacy_reference_map", {}).get(ref, resolve(registry, ref)))
			if id.is_empty():
				id = "legacy:order:" + ref.sha256_text().substr(0,24)
				register_generated(registry,{"name":ref},str(order.get("faction","")),"","legacy_unresolved",id)
				diagnose(registry,"unidentified_order_reference",ref)
			if not ids.has(id): ids.append(id)
			set_location(registry,id,"",true)
		order.erase("officers")
		order["officer_ids"] = ids
		result.append(order)
	return result
