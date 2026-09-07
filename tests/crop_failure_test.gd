extends SceneTree

const Crop = preload("res://crop_failure.gd")
const Bounty = preload("res://bountiful_harvest.gd")
const Campaign = preload("res://campaign_main.tscn")
const SCENARIO: String = "baekje_fall_660"
const CITY: String = "geumseong"
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + label)
	else:
		failures += 1
		push_error("FAIL: " + label)


func winning_year(ids: Array) -> int:
	for year: int in range(632, 10000):
		var match_all: bool = true
		for id: String in ids:
			match_all = match_all and Crop.roll_bp(SCENARIO, year, id) < 400 and Bounty.roll_bp(SCENARIO, year, id) >= 1200
		if match_all:
			return year
	return -1


func fixture(food: int = 1000, order: int = 50) -> Dictionary:
	return {CITY: {"name": "금성", "faction": "신라", "agriculture": 80, "public_order": order, "food_stock": food}}


func pending_state() -> Dictionary:
	return {"version": 1, "years": {}, "resolved": {}, "pending": {
		"event_id": Crop.EVENT_ID, "occurrence_id": "isolated-choice", "province_id": CITY,
		"payload": {"province_name": "금성", "harvest_loss": 300}}}


func write_save(path: String, data: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(data)
	file.close()


func _units() -> void:
	check(Crop.chance_bp({}) == 1200, "base chance 12 percent")
	check(Crop.chance_bp({"agriculture": 50, "public_order": 50}) == 800, "each stat point subtracts 0.04 percentage points")
	check(Crop.chance_bp({"agriculture": 100, "public_order": 100}) == 400, "minimum chance 4 percent")
	check(Crop.chance_bp({"agriculture": -9, "public_order": -9}) == 1200 and Crop.chance_bp({"agriculture": 999, "public_order": 999}) == 400, "chance clamps invalid stats")
	check(Crop.roll_bp(SCENARIO, 660, CITY) == 4272, "independent SHA256 golden vector")
	var year: int = winning_year([CITY])
	var provinces: Dictionary = fixture()
	var state: Dictionary = {}
	for month: int in [1, 8, 10, 12]:
		check(Crop.apply_september(state, SCENARIO, year, month, provinces, "신라", {CITY: 1000}, "").is_empty() and state.is_empty(), "no evaluation outside September: %d" % month)
	var pending: Dictionary = Crop.apply_september(state, SCENARIO, year, 9, provinces, "신라", {CITY: 1000}, "")
	check(pending.payload.harvest_loss == 300 and provinces[CITY].food_stock == 700, "September loss is 30 percent and committed before choice")
	check(Crop.apply_september(state, SCENARIO, year, 9, provinces, "신라", {CITY: 1000}, "").is_empty() and provinces[CITY].food_stock == 700, "duplicate September does not deduct again")
	check(Crop.apply_september({}, SCENARIO, year, 9, fixture(), "신라", {CITY: 1000}, CITY).is_empty(), "bountiful winner excluded")
	check(Crop.apply_september({}, SCENARIO, year, 9, fixture(), "백제", {CITY: 1000}, "").is_empty(), "foreign province excluded")
	check(Crop.apply_september({}, SCENARIO, year, 9, fixture(), "신라", {CITY: 0}, "").is_empty(), "zero harvest excluded")
	var pair_year: int = winning_year([CITY, "sabi"])
	provinces = fixture()
	provinces.sabi = provinces[CITY].duplicate(true)
	state = {}
	pending = Crop.apply_september(state, SCENARIO, pair_year, 9, provinces, "신라", {CITY: 1000, "sabi": 1000}, "")
	check(pending.province_id == "sabi" and provinces[CITY].food_stock == 1000, "first winner follows PROVINCE_IDS, not alphabetic/dictionary order")
	Crop.resolve(state, provinces, "신라", pending.occurrence_id, "maintain_tax")
	check(Crop.apply_september(state, SCENARIO, pair_year, 9, provinces, "신라", {CITY: 1000}, "").is_empty(), "resolved choice cannot enable second winner that year")
	state = {}
	Crop.apply_september(state, SCENARIO, 660, 9, fixture(), "신라", {CITY: 1000}, "")
	check(state.years.has("660") and state.get("pending", {}).is_empty(), "failed roll is recorded as settled")
	check(Crop.restore_state(null, 660, 8).pending.is_empty() and Crop.restore_state(null, 660, 8).years.is_empty(), "old August save has empty pending and future evaluation")
	check(Crop.restore_state(null, 660, 9).years["660"].legacy_settled, "old September save never retroactively applies damage")
	for choice: String in Crop.EFFECTS:
		for order: int in [0, 50, 99, 100]:
			provinces = fixture(800, order)
			state = pending_state()
			var result: Dictionary = Crop.resolve(state, provinces, "신라", "isolated-choice", choice)
			check(provinces[CITY].food_stock == 800 + int(Crop.EFFECTS[choice].grain) and provinces[CITY].public_order == clampi(order + int(Crop.EFFECTS[choice].order), 0, 100), "%s actual resource effects from order %d" % [choice, order])
			check(result.public_order_delta == provinces[CITY].public_order - order and result.public_order_result_text == "%+d" % int(result.public_order_delta), "result uses clamped delta: %s/%d" % [choice, order])
			check(Crop.resolve(state, provinces, "신라", "isolated-choice", choice).is_empty() and state.pending.is_empty(), "duplicate command rejected: %s/%d" % [choice, order])
	state = pending_state()
	provinces = fixture(799)
	check(Crop.choice_reason(state, provinces, "신라", "isolated-choice", "relieve_people") == "군량 800 필요", "799 stock explains unavailable relief")
	check(Crop.resolve(state, provinces, "신라", "isolated-choice", "relieve_people").is_empty() and provinces[CITY].food_stock == 799 and not state.pending.is_empty(), "unaffordable relief has no partial effect")
	check(Crop.resolve(state, provinces, "신라", "wrong-occurrence", "maintain_tax").is_empty(), "wrong occurrence rejected")
	check(Crop.resolve(state, provinces, "신라", "isolated-choice", "unknown").is_empty(), "unknown choice rejected")
	check(Crop.resolve(state, provinces, "백제", "isolated-choice", "maintain_tax").is_empty(), "foreign command rejected")
	check(not Crop.cancel_if_unowned(state, provinces, "신라") and not state.pending.is_empty(), "owned pending decision is retained")
	check(Crop.cancel_if_unowned(state, provinces, "백제") and state.pending.is_empty() and state.resolved["isolated-choice"].cancelled and provinces[CITY].food_stock == 799, "capture cancels unavailable policy without modifying new owner's resources")


func _run() -> void:
	create_timer(60.0).timeout.connect(func(): quit(2))
	_units()
	var c: Node = Campaign.instantiate()
	root.add_child(c)
	current_scene = c
	await process_frame
	await process_frame
	# Isolated test resources, never applied to a real campaign or its saves.
	c.ai_attack_ratio = 1000000.0
	c.ai_recruitment_amount = 0
	c.year = winning_year([CITY])
	c.month = 8
	c._sync_season_from_month()
	for id: String in c.Korea35Data.PROVINCE_IDS:
		if c.provinces[id].faction == c.player_faction:
			c.provinces[id].agriculture = 0
	var city: Dictionary = c.provinces[CITY]
	city.population = 100000
	city.agriculture = 80
	city.public_order = 100
	city.food_stock = 0
	city.troops = 0
	city.granary_capacity = 1000000
	var base: int = roundi(c.calculate_collected_harvest(city) * 0.70)
	var loss: int = roundi(base * 0.30)
	var expected: Dictionary = city.duplicate(true)
	expected.food_stock = base - loss
	var stock: int = base - loss - c.calculate_monthly_storage_loss(expected)
	var path: String = OS.get_temp_dir().path_join("samhan-crop-%d.json" % OS.get_process_id())
	c._on_save_button_pressed(path)
	var august: String = FileAccess.get_file_as_string(path)
	c._on_end_turn_button_pressed()
	var p: Node = c.event_presentation
	check(c.month == 9 and p.active and p.current.id == Crop.EVENT_ID, "actual September turn dispatches crop failure")
	check(city.food_stock == stock and c.crop_failure_events.pending.payload.harvest_loss == loss, "45 percent collection / 70 percent harvest minus 30 percent damage then original storage loss")
	check(p.view.body_label.text.contains(str(loss)) and p.view.body_label.text.contains(city.name), "illustrated screen receives committed loss and real city")
	check(p.view.background.texture != null, "installed WebP loads")
	p.skip()
	p.set_auto(true)
	p._process(30.0)
	check(p.active and p.step_index == 0 and not p.auto_play, "unresolved intro cannot auto/skip past decision")
	p.next()
	p.next()
	check(p.current.steps[p.step_index].mode == "choice" and p.view.choice_buttons.size() == 3, "Next opens common three-button choice mode")
	var choice_index: int = p.step_index
	p.next()
	p.skip()
	c._on_end_turn_button_pressed()
	check(p.step_index == choice_index and c.month == 9 and c.end_turn_button.disabled, "Next/skip/turn cannot bypass required choice")
	p.open_menu()
	check(p.menu_open(), "Esc menu accessible during required choice")
	c.navigation_menu.get_popup().hide()
	c._on_save_button_pressed(path)
	var unresolved: String = FileAccess.get_file_as_string(path)
	c._on_load_button_pressed(path)
	check(p.active and p.current.steps[p.step_index].mode == "choice" and c.provinces[CITY].food_stock == stock, "pending save restores only choice without damage or month replay")
	check(not p.play_choice(c.crop_failure_events.pending, true), "duplicate pending presentation rejected")
	check(p.view.body_label.text.contains(str(loss)) and p.view.body_label.text.contains(c.provinces[CITY].name), "resumed choice retains province and committed damage context")
	check(not p.view.body_label.text.contains("%d.0" % loss), "loaded harvest loss remains an integer caption")
	for level: String in ["all", "major", "minimal"]:
		write_save(path, unresolved)
		c._on_load_button_pressed(path)
		p.display_level = level
		c._on_save_button_pressed(path)
		c._on_load_button_pressed(path)
		check(p.active and p.current.steps[p.step_index].mode == "choice", "pending decision survives display setting " + level)
	# Re-check affordability at commit even if UI was previously enabled.
	c.provinces[CITY].food_stock = 799
	p._choose("relieve_people")
	check(p.view.choice_buttons.relieve_people.disabled and p.view.choice_buttons.relieve_people.text.contains("군량 800 필요") and c.provinces[CITY].food_stock == 799, "stale affordable UI cannot overspend; disabled reason refreshes")
	c.provinces[CITY].food_stock = 800
	c.provinces[CITY].public_order = 99
	p._show_step()
	p.view.choice_buttons.relieve_people.pressed.emit()
	p._choose("force_requisition")
	check(c.provinces[CITY].food_stock == 0 and c.provinces[CITY].public_order == 100 and c.crop_failure_events.pending.is_empty(), "UI relief at exact stock boundary commits once despite second signal")
	check(p.view.body_label.text.contains("-800") and p.view.body_label.text.contains("+1") and not p.view.body_label.text.contains("+8"), "result displays actual relief deltas")
	c._on_save_button_pressed(path)
	c._on_load_button_pressed(path)
	check(not p.active and c.provinces[CITY].food_stock == 0 and c.crop_failure_events.resolved.size() == 1, "save during result restores resolved receipt with no repeated choice")
	for choice: String in ["maintain_tax", "force_requisition"]:
		write_save(path, unresolved)
		c._on_load_button_pressed(path)
		var before_order: int = c.provinces[CITY].public_order
		p.view.choice_buttons[choice].pressed.emit()
		p.set_auto(true)
		p._process(30.0)
		p.skip()
		check(not p.active and c.provinces[CITY].food_stock == stock + int(Crop.EFFECTS[choice].grain) and c.provinces[CITY].public_order == clampi(before_order + int(Crop.EFFECTS[choice].order), 0, 100), "choice result auto/skip never reapplies " + choice)
	write_save(path, august)
	c._on_load_button_pressed(path)
	p.display_level = "minimal"
	c._on_end_turn_button_pressed()
	check(c.provinces[CITY].food_stock == stock and p.current.steps[p.step_index].mode == "choice", "same August save has same loss and mandatory minimal choice")
	p._choose("maintain_tax")
	p.skip()
	var before: int = c.provinces[CITY].food_stock
	c.month = 10
	var october: int = roundi(c.calculate_collected_harvest(c.provinces[CITY]) * 0.30)
	c.process_seasonal_harvest()
	check(c.provinces[CITY].food_stock == before + october and c.crop_failure_events.pending.is_empty(), "October 30 percent harvest has no crop failure")
	var legacy: Dictionary = JSON.parse_string(august)
	legacy.erase("crop_failure_events")
	legacy.month = 9
	write_save(path, JSON.stringify(legacy))
	c._on_load_button_pressed(path)
	check(not p.active and c.provinces[CITY].food_stock == 0 and c.crop_failure_events.pending.is_empty() and c.crop_failure_events.years[str(c.year)].legacy_settled, "real legacy September load preserves resources and adds no decision")
	# A save may happen before the pending choice reaches the front of the queue.
	write_save(path, august)
	c._on_load_button_pressed(path)
	p.display_level = "all"
	p.play("domestic_bountiful_harvest", {"province_name": "표시 전용", "grain_delta": 1, "public_order_delta": 0}, "queued-fixture")
	c.crop_failure_events = pending_state()
	c._present_pending_choice()
	check(p.current.id == "domestic_bountiful_harvest" and p.queue.size() == 1, "mandatory choice queues behind existing presentation without replacing it")
	c._on_save_button_pressed(path)
	c._on_load_button_pressed(path)
	check(p.current.id == Crop.EVENT_ID and p.current.steps[p.step_index].mode == "choice" and p.queue.is_empty(), "save behind another event restores mandatory choice alone")
	check(p.view.choice_buttons.relieve_people.disabled and not p.view.choice_buttons.maintain_tax.disabled and not p.view.choice_buttons.force_requisition.disabled, "zero food blocks only relief; other choices remain available")
	p._choose("force_requisition")
	p.skip()
	check(c.provinces[CITY].food_stock == 500 and not c.end_turn_button.disabled, "zero-stock choice leaves nonnegative food and restores turn input")
	DirAccess.remove_absolute(path)
	c.queue_free()
	await process_frame
	await process_frame
	print("CROP FAILURE TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
