extends SceneTree

const Harvest = preload("res://bountiful_harvest.gd")
const Campaign = preload("res://campaign_main.tscn")
const SCENARIO: String = "baekje_fall_660"
const CITY: String = "geumseong"
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, label: String) -> void:
	checks += 1
	if condition:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func qualifying_year(ids: Array, limit: int = 400) -> int:
	for candidate: int in range(632, 5632):
		var matches: bool = true
		for id: String in ids:
			matches = matches and Harvest.roll_bp(SCENARIO, candidate, id) < limit
		if matches:
			return candidate
	return -1


func receipt(state: Dictionary, target_year: int) -> Dictionary:
	return state.get("years", {}).get(str(target_year), {})


func _unit_cases() -> void:
	check(Harvest.chance_bp({}) == 400, "base probability is four percent")
	check(Harvest.chance_bp({"agriculture": 50, "public_order": 50}) == 800, "agriculture and order increase probability")
	check(Harvest.chance_bp({"agriculture": 100, "public_order": 100}) == 1200, "probability reaches twelve percent")
	check(Harvest.chance_bp({"agriculture": 999, "public_order": 999}) == 1200 and Harvest.chance_bp({"agriculture": -5, "public_order": -8}) == 400, "stats and probability are clamped")
	check(Harvest.roll_bp(SCENARIO, 660, CITY) == 2276, "SHA256 roll matches independent golden vector")
	var target_year: int = qualifying_year([CITY])
	var fixture: Dictionary = {CITY: {"name": "금성", "faction": "신라", "agriculture": 80, "public_order": 70, "food_stock": 2520}}
	var state: Dictionary = {}
	check(Harvest.apply_september(state, SCENARIO, target_year, 8, fixture, "신라", {CITY: 2520}).is_empty() and state.is_empty(), "August does not evaluate")
	check(Harvest.apply_september(state, SCENARIO, target_year, 10, fixture, "신라", {CITY: 1080}).is_empty() and state.is_empty(), "October does not evaluate")
	var result: Dictionary = Harvest.apply_september(state, SCENARIO, target_year, 9, fixture, "신라", {CITY: 2520})
	check(result.grain_delta == 630 and fixture[CITY].food_stock == 3150, "bonus is 25 percent of actual September harvest")
	check(result.public_order_delta == 3 and fixture[CITY].public_order == 73, "public order gains three")
	check(result.occurrence_id.contains(SCENARIO) and result.occurrence_id.ends_with(CITY), "occurrence identity includes scenario year and province")
	check(Harvest.apply_september(state, SCENARIO, target_year, 9, fixture, "신라", {CITY: 2520}).is_empty() and fixture[CITY].food_stock == 3150, "annual receipt blocks duplicate reward")
	var next_year: int = target_year + 1
	while Harvest.roll_bp(SCENARIO, next_year, CITY) >= 400:
		next_year += 1
	check(not Harvest.apply_september(state, SCENARIO, next_year, 9, fixture, "신라", {CITY: 2520}).is_empty() and state.years.size() == 2, "following years can each evaluate independently")
	for initial_order: int in [98, 99, 100]:
		fixture[CITY].public_order = initial_order
		result = Harvest.apply_september({}, SCENARIO, target_year, 9, fixture, "신라", {CITY: 2520})
		check(result.public_order_delta == 100 - initial_order and fixture[CITY].public_order == 100, "actual capped order delta from %d" % initial_order)
	var two_year: int = qualifying_year([CITY, "sabi"], 1200)
	var cities: Dictionary = {
		"sabi": {"faction": "신라", "agriculture": 100, "public_order": 100, "food_stock": 0},
		CITY: {"faction": "신라", "agriculture": 100, "public_order": 100, "food_stock": 0},
	}
	state = {}
	result = Harvest.apply_september(state, SCENARIO, two_year, 9, cities, "신라", {"sabi": 200, CITY: 200})
	check(result.province_id == CITY and cities[CITY].food_stock == 50 and cities.sabi.food_stock == 0, "two eligible cities produce one winner in sorted ID order")
	cities.erase(CITY)
	check(Harvest.apply_september(state, SCENARIO, two_year, 9, cities, "신라", {"sabi": 200}).is_empty(), "capture/removal cannot select a second winner")
	var foreign: Dictionary = {CITY: {"faction": "백제", "agriculture": 100, "public_order": 100, "food_stock": 0}}
	state = {}
	check(Harvest.apply_september(state, SCENARIO, target_year, 9, foreign, "신라", {CITY: 200}).is_empty() and foreign[CITY].food_stock == 0, "foreign province is never rewarded")
	foreign[CITY].faction = "신라"
	check(Harvest.apply_september(state, SCENARIO, target_year, 9, foreign, "신라", {CITY: 200}).is_empty(), "failed year is final even after ownership change")
	check(Harvest.apply_september({}, SCENARIO, target_year, 9, foreign, "신라", {CITY: 0}).is_empty(), "no harvest cannot grant grain")
	check(Harvest.restore_state(null, target_year, 8).years.is_empty(), "legacy August save can use future September")
	check(receipt(Harvest.restore_state(null, target_year, 9), target_year).legacy_settled, "legacy September save receives no retroactive bonus")
	check(receipt(Harvest.restore_state(null, target_year, 10), target_year).legacy_settled, "legacy October save does not reopen September")
	check(Harvest.roll_bp(SCENARIO, target_year, CITY) == Harvest.roll_bp(SCENARIO, target_year, CITY), "roll does not consume random state")
	# Real chance failure followed by improved stats must still remain settled.
	foreign[CITY].agriculture = 0
	foreign[CITY].public_order = 0
	state = {}
	check(Harvest.apply_september(state, SCENARIO, 660, 9, foreign, "신라", {CITY: 200}).is_empty(), "fixed losing roll produces no reward")
	foreign[CITY].agriculture = 100
	foreign[CITY].public_order = 100
	check(Harvest.apply_september(state, SCENARIO, 660, 9, foreign, "신라", {CITY: 200}).is_empty(), "failed roll is not retried after stat changes")


func _run() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	_unit_cases()
	var c: Node = Campaign.instantiate()
	root.add_child(c)
	current_scene = c
	await process_frame
	await process_frame
	# Isolated fixture: normal month processing, but no AI attacks/resources
	# supplied to a user's campaign. Production/economy code is not replaced.
	c.ai_attack_ratio = 1000000.0
	c.ai_recruitment_amount = 0
	c.year = qualifying_year([CITY])
	c.month = 8
	c._sync_season_from_month()
	for id: String in c.Korea35Data.PROVINCE_IDS:
		if c.provinces[id].faction == c.player_faction:
			c.provinces[id].agriculture = 0
	var province: Dictionary = c.provinces[CITY]
	province.population = 100000
	province.agriculture = 80
	province.public_order = 98
	province.food_stock = 0
	province.troops = 0
	province.granary_capacity = 1000000
	var base: int = roundi(float(c.calculate_collected_harvest(province)) * 0.70)
	var bonus: int = roundi(base * 0.25)
	var expected: Dictionary = province.duplicate(true)
	expected.food_stock = base + bonus
	expected.public_order = 100
	var final_stock: int = base + bonus - c.calculate_monthly_storage_loss(expected)
	var path: String = OS.get_temp_dir().path_join("samhan-harvest-%d.json" % OS.get_process_id())
	c._on_save_button_pressed(path)
	var august: String = FileAccess.get_file_as_string(path)
	c._on_end_turn_button_pressed()
	var p: Node = c.event_presentation
	var record: Dictionary = receipt(c.harvest_events, c.year).duplicate(true)
	check(c.month == 9 and p.active and p.current.id == "domestic_bountiful_harvest", "actual September end turn triggers harvest cutscene")
	check(record.september_harvest == base and record.grain_delta == bonus, "original 45 percent collection and 70 percent September base retained")
	check(province.food_stock == final_stock, "normal turn adds base plus bonus then existing storage loss")
	check(province.public_order == 100 and record.public_order_delta == 2, "September turn caps order and records actual plus two")
	check(p.current.steps[0].text.contains(province.name), "scene receives actual province name")
	p.next()
	p.next()
	check(p.view.body_label.text.contains("+%d" % bonus) and p.view.body_label.text.contains("+2"), "scene displays confirmed applied quantities")
	p.skip()
	p.skip()
	check(province.food_stock == final_stock and province.public_order == 100, "skip and repeated skip do not apply rewards")
	check(not p.play("domestic_bountiful_harvest", record, record.occurrence_id), "occurrence ID blocks duplicate presentation")
	c._on_save_button_pressed(path)
	c._on_load_button_pressed(path)
	check(not p.active and c.provinces[CITY].food_stock == final_stock and receipt(c.harvest_events, c.year).grain_delta == bonus, "September save restores receipt and resources without replay")
	check(Harvest.apply_september(c.harvest_events, c.scenario_id, c.year, 9, c.provinces, c.player_faction, {CITY: base}).is_empty(), "loaded September cannot receive the reward again")
	for level: String in ["all", "minimal", "major"]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(august)
		file.close()
		c._on_load_button_pressed(path)
		p.display_level = level
		c._on_end_turn_button_pressed()
		check(receipt(c.harvest_events, c.year) == record and c.provinces[CITY].food_stock == final_stock, "same August save gives same roll/winner/bonus with policy " + level)
		if level == "all":
			p.set_auto(true)
			p._process(10.0)
			p._process(10.0)
		check(not p.active and c.provinces[CITY].food_stock == final_stock, "automatic/minimal/major policy never changes committed reward: " + level)
	var old_stock: int = c.provinces[CITY].food_stock
	var october_base: int = roundi(float(c.calculate_collected_harvest(c.provinces[CITY])) * 0.30)
	c.month = 10
	c.process_seasonal_harvest()
	check(c.provinces[CITY].food_stock == old_stock + october_base and receipt(c.harvest_events, c.year) == record, "October remains 30 percent only with no second event")
	var legacy: Dictionary = JSON.parse_string(august)
	legacy.erase("harvest_events")
	legacy.month = 9
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	c._on_load_button_pressed(path)
	check(c.provinces[CITY].food_stock == 0 and not p.active and receipt(c.harvest_events, c.year).legacy_settled, "real legacy load grants neither retroactive harvest nor presentation")
	legacy.month = 8
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	c._on_load_button_pressed(path)
	c._on_end_turn_button_pressed()
	check(receipt(c.harvest_events, c.year) == record and c.provinces[CITY].food_stock == final_stock, "legacy August load can receive exactly the future September event")
	p.skip()
	# Zero-delta display uses the actual production reward path, not preview data.
	legacy.month = 8
	legacy.provinces[CITY].public_order = 100
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	c._on_load_button_pressed(path)
	c._on_end_turn_button_pressed()
	var max_record: Dictionary = receipt(c.harvest_events, c.year).duplicate(true)
	var max_stock: int = c.provinces[CITY].food_stock
	p.next()
	p.next()
	check(max_record.public_order_delta == 0 and p.view.body_label.text.contains("치안 100 · 최대치") and not p.view.body_label.text.contains("+0"), "real capped harvest uses maximum caption instead of plus zero")
	p.skip()
	check(c.provinces[CITY].public_order == 100 and c.provinces[CITY].food_stock == max_stock and receipt(c.harvest_events, c.year) == max_record, "maximum caption leaves actual order stock and receipt unchanged")
	DirAccess.remove_absolute(path)
	c.queue_free()
	await process_frame
	await process_frame
	print("BOUNTIFUL HARVEST TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
