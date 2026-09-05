extends RefCounted

# Injected permissions exist ONLY in this separate test process, not in saves.
const Production = preload("res://production_system.gd")
const Data = preload("res://production_data.gd")
const Supply = preload("res://iron_supply_data.gd")
const Strategy = preload("res://samhan_strategy_systems.gd")
const CampaignScene = preload("res://campaign_main.tscn")
const Korea = preload("res://korea_35_data.gd")
const Scenarios = preload("res://scenario_data.gd")
const CITY: String = "geumseong"
const FACTION: String = "신라"
const SCENARIO: String = "test_only"
const MONTH: int = 7922
var runner: SceneTree


func check(ok: bool, label: String) -> void:
	runner.check(ok, "iron supply: " + label)


func fixture() -> Dictionary:
	var provinces: Dictionary = {CITY: {"name": "Test city", "faction": FACTION}}
	var state: Dictionary = {
		"city_inventory": {CITY: {"iron": 0, "sword": 0}},
		"faction_research": {FACTION: {"basic_smelting": 1, "swordsmithing": 1}},
		"province_buildings": {CITY: {"smelter": 1, "forge": 1}},
		"construction_queues": {}, "research_queues": {},
	}
	var rules: Dictionary = {SCENARIO: {CITY: {"allowed": true, "placement_confirmed": true}}}
	Production.normalize_state(state, provinces)
	for recipe: String in Data.RECIPE_ORDER:
		Production.set_enabled(state, provinces, CITY, recipe, FACTION, true, SCENARIO, rules)
	return {"state": state, "provinces": provinces, "rules": rules}


func tick(f: Dictionary, gold: int, month_key: int = MONTH) -> Dictionary:
	return Production.process_month(f.state, f.provinces, FACTION, gold, month_key, SCENARIO, f.rules)


func units() -> void:
	for amounts: Array in [[100, 84, 0, 1], [15, 9, 2, 0], [5, 5, 0, 0]]:
		var f: Dictionary = fixture()
		var result: Dictionary = tick(f, amounts[0])
		check(result.gold == amounts[1] and f.state.city_inventory[CITY].iron == amounts[2] and f.state.city_inventory[CITY].sword == amounts[3], "gold %d -> %d, iron %d, sword %d" % amounts)
		if amounts[0] < 16:
			check(f.state.city_production[CITY].iron_sword.status == "보류", "manufacture explains shortage")
		if amounts[0] == 5:
			check(f.state.city_production[CITY].iron_supply.status == "보류", "supply explains insufficient funds")
		var inventory: String = JSON.stringify(f.state.city_inventory)
		for recipe: String in Data.RECIPE_ORDER:
			Production.set_enabled(f.state, f.provinces, CITY, recipe, FACTION, false, SCENARIO, f.rules)
			Production.set_enabled(f.state, f.provinces, CITY, recipe, FACTION, true, SCENARIO, f.rules)
		result = tick(f, 100)
		check(result.gold == 100 and JSON.stringify(f.state.city_inventory) == inventory, "same-month stop/start and added funds cannot retry successful OR suspended orders")
		f.state = JSON.parse_string(JSON.stringify(f.state))
		Production.normalize_state(f.state, f.provinces)
		result = tick(f, 100)
		check(result.gold == 100 and JSON.stringify(f.state.city_inventory) == inventory, "JSON load cannot retry same month")
		result = tick(f, 100, MONTH + 1)
		check(result.gold == 84 and f.state.city_inventory[CITY].sword == amounts[3] + 1, "next month permits exactly one batch per process")

	for missing: String in ["region", "confirmation", "scenario", "technology", "facility", "ownership"]:
		var f: Dictionary = fixture()
		match missing:
			"region": f.rules[SCENARIO][CITY].allowed = false
			"confirmation": f.rules[SCENARIO][CITY].placement_confirmed = false
			"scenario": f.rules = {"another_scenario": f.rules[SCENARIO]}
			"technology": f.state.faction_research[FACTION].basic_smelting = 0
			"facility": f.state.province_buildings[CITY].smelter = 0
			"ownership": f.provinces[CITY].faction = "백제"
		var result: Dictionary = tick(f, 100)
		check(result.gold == 100 and f.state.city_inventory[CITY].iron == 0 and f.state.city_inventory[CITY].sword == 0, missing + " blocks supply with no resource changes")
		check(f.state.city_production[CITY].iron_supply.reason != "", missing + " has a visible reason")

	for stopped: String in Data.RECIPE_ORDER:
		var f: Dictionary = fixture()
		Production.set_enabled(f.state, f.provinces, CITY, stopped, FACTION, false, SCENARIO, f.rules)
		if stopped == "iron_supply":
			f.state.city_inventory[CITY].iron = 2
		var result: Dictionary = tick(f, 100)
		check(result.gold == (90 if stopped == "iron_supply" else 94) and f.state.city_inventory[CITY].sword == (1 if stopped == "iron_supply" else 0) and f.state.city_inventory[CITY].iron == (0 if stopped == "iron_supply" else 2), stopped + " stops independently")

	var f: Dictionary = fixture()
	var old_order: Dictionary = f.state.city_production[CITY].iron_sword.duplicate(true)
	f.state.city_production[CITY].erase("iron_supply")
	f.state.city_inventory[CITY] = {"iron": 17, "sword": 9}
	f.state.production_last_month = MONTH
	Production.normalize_state(f.state, f.provinces)
	check(f.state.city_production[CITY].iron_sword == old_order and not f.state.city_production[CITY].iron_supply.enabled and f.state.city_inventory[CITY].iron == 17 and f.state.city_inventory[CITY].sword == 9 and f.state.production_last_month == MONTH, "old single-process save preserves order owner, stocks and stamp; new supply is stopped")

	f = fixture()
	var research: String = JSON.stringify(f.state.faction_research)
	var buildings: String = JSON.stringify(f.state.province_buildings)
	f.state.city_inventory[CITY].iron = 8
	f.provinces[CITY].faction = "백제"
	Production.stop_on_capture(f.state, CITY)
	f.provinces[CITY].faction = FACTION
	check(not f.state.city_production[CITY].iron_supply.enabled and not f.state.city_production[CITY].iron_sword.enabled and JSON.stringify(f.state.faction_research) == research and JSON.stringify(f.state.province_buildings) == buildings and f.state.city_inventory[CITY].iron == 8, "capture and recapture stop both orders without moving research or destroying stocks/facilities")
	check(not Production.set_enabled(f.state, f.provinces, CITY, "iron_supply", "백제", true, SCENARIO, f.rules).ok, "old owner cannot restart")
	f.provinces[CITY].faction = "백제"
	Production.set_enabled(f.state, f.provinces, CITY, "iron_supply", "백제", true, SCENARIO, f.rules)
	var captured_result: Dictionary = Production.process_month(f.state, f.provinces, "백제", 100, MONTH, SCENARIO, f.rules)
	check(captured_result.gold == 100 and f.state.city_inventory[CITY].iron == 8 and f.state.city_production[CITY].iron_supply.reason.contains("basic_smelting"), "new owner cannot reuse previous owner's national technology")
	f.state.faction_research["백제"] = {"basic_smelting": 1}
	captured_result = Production.process_month(f.state, f.provinces, "백제", 100, MONTH + 1, SCENARIO, f.rules)
	check(captured_result.gold == 94 and f.state.city_inventory[CITY].iron == 10 and f.state.faction_research[FACTION].basic_smelting == 1, "new owner restarts with own technology and supplied national funds")
	f = fixture()
	captured_result = tick(f, 100, MONTH + 12)
	check(captured_result.gold == 84 and f.state.city_inventory[CITY].sword == 1, "skipped months never generate catch-up batches")
	f = fixture()
	f.rules[SCENARIO][CITY].allowed = false
	tick(f, 100)
	f.rules[SCENARIO][CITY].allowed = true
	captured_result = tick(f, 100)
	check(captured_result.gold == 100 and f.state.city_inventory[CITY].iron == 0, "late regional unlock cannot retry a suspended month")

	# Deliberately insert the earlier ID last: order must not depend on insertion.
	f = fixture()
	f.provinces["aaa"] = {"faction": FACTION}
	f.rules[SCENARIO]["aaa"] = {"allowed": true, "placement_confirmed": true}
	f.state.province_buildings["aaa"] = {"smelter": 1, "forge": 1}
	Production.normalize_state(f.state, f.provinces)
	for recipe: String in Data.RECIPE_ORDER:
		Production.set_enabled(f.state, f.provinces, "aaa", recipe, FACTION, true, SCENARIO, f.rules)
	var result: Dictionary = tick(f, 16)
	check(result.gold == 0 and f.state.city_inventory.aaa.sword == 1 and f.state.city_inventory[CITY].iron == 0 and f.state.city_inventory[CITY].sword == 0, "shared funds: ascending city ID, supply then manufacture WITHIN each city")

	var backend := Strategy.new()
	f = fixture()
	f.state.province_buildings[CITY].smelter = 0
	check(not backend.start_building(f.state, CITY, "smelter").ok and f.state.construction_queues.is_empty(), "generic construction backend cannot bypass regional permission")
	result = backend.start_building(f.state, CITY, "smelter", "", -1, SCENARIO, f.rules)
	check(result.ok and result.gold_cost == 240 and result.turns == 2, "smelter uses existing queue with gold 240 and two seasonal ticks")
	check(not backend.start_building(f.state, CITY, "smelter", "", -1, SCENARIO, f.rules).ok, "duplicate construction rejected")
	backend._process_construction(f.state)
	check(f.state.province_buildings[CITY].smelter == 0, "unfinished smelter stays inactive")
	backend._process_construction(f.state)
	check(f.state.province_buildings[CITY].smelter == 1 and not backend.get_building_quote(f.state, CITY, "smelter", SCENARIO, f.rules).ok, "smelter completes, max level one enforced")
	check(not backend.start_research(f.state, FACTION, "basic_smelting").ok and f.state.research_queues.is_empty(), "basic technology cannot be acquired through research")
	check(Supply.CANDIDATES.ugye_ri.placement_confirmed == false and Supply.CANDIDATES.ugye_ri.mining_confirmed == false and not Supply.CANDIDATES.ugye_ri.source_url.is_empty(), "Ugye-ri is evidence only, not a confirmed mine or placement")
	for scenario: Dictionary in Scenarios.SCENARIOS:
		var scenario_id: String = str(scenario["id"])
		var permissions_match: bool = true
		for city_id: String in Korea.PROVINCE_IDS:
			var expected: bool = city_id == "geumgwan" and int(scenario.year) in [632, 642]
			permissions_match = permissions_match and Supply.blocked_reason(scenario_id, city_id).is_empty() == expected
		check(permissions_match, scenario_id + ": only 632/642 geumgwan pilot permitted")


func run(host: SceneTree) -> void:
	runner = host
	units()
	var campaign = CampaignScene.instantiate()
	runner.root.add_child(campaign)
	runner.current_scene = campaign
	await runner.process_frame
	await runner.process_frame
	check(campaign.strategy_state.faction_research[FACTION].basic_smelting == 0, "new campaign does not grant basic smelting")
	campaign.strategy_state.research_queues[FACTION] = {"research_id": "swordsmithing", "remaining_turns": 1, "target_level": 1}
	var basic_view: Dictionary = campaign.get_production_view_model(CITY, "iron_supply")
	check(not basic_view.research_status.contains("진행 중인 명령"), "unrelated research queue is not displayed as basic smelting research")
	campaign.strategy_state.research_queues.clear()
	campaign._on_city_card_production_requested(CITY)
	var overlay = campaign.production_overlay
	overlay.recipe_selector.select(0)
	overlay.recipe_selector.item_selected.emit(0)
	check(overlay.selected_recipe_id == "iron_supply" and overlay.start_button.disabled and overlay.building_button.disabled and overlay.research_button.disabled and overlay.details.text.contains("본게임 생산지 배치 미적용"), "real supply UI blocks start/build/research and explains unplaced status")
	var gold_before: int = campaign.gold
	check(not campaign.request_production_command(CITY, "iron_supply", "start").ok and not campaign.request_production_command(CITY, "iron_supply", "build").ok and campaign.gold == gold_before, "main-game command API cannot bypass region lock")
	# Even a save carrying forged levels/orders cannot turn on an unplaced source.
	campaign.strategy_state.faction_research[FACTION].basic_smelting = 1
	campaign.strategy_state.province_buildings[CITY].smelter = 1
	check(not campaign.request_production_command(CITY, "iron_supply", "start").ok, "technology and facility cannot unlock unplaced region")
	campaign.strategy_state.city_production[CITY].iron_supply = {"enabled": true, "owner": FACTION}
	var result: Dictionary = Production.process_month(campaign.strategy_state, campaign.provinces, FACTION, 100, MONTH, campaign.scenario_id)
	check(result.gold == 100 and campaign.strategy_state.city_inventory[CITY].iron == 0, "injected enabled order still cannot produce in main game")

	# Isolated campaign dependency and resources; never persisted as world placement.
	campaign.iron_supply_rules = {campaign.scenario_id: {CITY: {"allowed": true, "placement_confirmed": true}}}
	campaign.strategy_state.province_buildings[CITY].smelter = 0
	campaign.gold = 239
	check(not campaign.request_production_command(CITY, "iron_supply", "build").ok and campaign.gold == 239 and campaign.strategy_state.construction_queues.is_empty(), "construction gold shortage charges nothing")
	campaign.gold = 1000
	result = campaign.request_production_command(CITY, "iron_supply", "build")
	check(result.ok and campaign.gold == 760 and campaign.strategy_state.construction_queues[CITY].remaining_turns == 2, "campaign construction charges existing quote exactly once")
	check(not campaign.request_production_command(CITY, "iron_supply", "build").ok and campaign.gold == 760, "repeated build does not charge again")
	campaign.strategy._process_construction(campaign.strategy_state)
	campaign.strategy._process_construction(campaign.strategy_state)
	campaign.strategy_state.faction_research[FACTION].swordsmithing = 1
	campaign.strategy_state.province_buildings[CITY].forge = 1
	for recipe: String in Data.RECIPE_ORDER:
		campaign.request_production_command(CITY, recipe, "start")
	for index: int in [1, 0, 1, 0]:
		overlay.recipe_selector.select(index)
		overlay.recipe_selector.item_selected.emit(index)
	check(campaign.strategy_state.city_production[CITY].iron_supply.enabled and campaign.strategy_state.city_production[CITY].iron_sword.enabled and overlay.details.text.contains("철 공급: 예약") and overlay.details.text.contains("철로 칼 제작: 예약"), "switching displayed process preserves both reservations")
	overlay.stop_button.pressed.emit()
	check(not campaign.strategy_state.city_production[CITY].iron_supply.enabled and campaign.strategy_state.city_production[CITY].iron_sword.enabled, "supply stop button does not cancel sword")
	overlay.start_button.pressed.emit()
	overlay.recipe_selector.select(1)
	overlay.recipe_selector.item_selected.emit(1)
	overlay.stop_button.pressed.emit()
	check(campaign.strategy_state.city_production[CITY].iron_supply.enabled and not campaign.strategy_state.city_production[CITY].iron_sword.enabled, "sword stop button does not cancel supply")
	overlay.start_button.pressed.emit()

	# Multiple requirements are fed into the same view/renderer used by recipes.
	overlay.recipe_selector.select(0)
	overlay.recipe_selector.item_selected.emit(0)
	var tech_options: Array[Dictionary] = campaign._production_requirement_options(CITY, FACTION, {"basic_smelting": 1, "swordsmithing": 2}, true, true)
	var facility_options: Array[Dictionary] = campaign._production_requirement_options(CITY, FACTION, {"smelter": 1, "forge": 2}, false, true)
	overlay._render_requirements(overlay.research_button, overlay.extra_research_buttons, tech_options, "research")
	overlay._render_requirements(overlay.building_button, overlay.extra_building_buttons, facility_options, "build")
	check(tech_options.size() == 2 and facility_options.size() == 2 and tech_options[1].status.contains("도검 제작") and facility_options[1].status.contains("군기감") and overlay.extra_building_buttons.get_child_count() == 1 and overlay.extra_research_buttons.get_child_count() == 1, "UI renders every required technology and facility")
	gold_before = campaign.gold
	overlay.extra_building_buttons.get_child(0).pressed.emit()
	check(campaign.strategy_state.construction_queues.is_empty() and campaign.gold == gold_before and overlay.result_label.text.contains("필요 조건이 아니거나"), "explicit requirement routing rejects forged requirement outside the selected recipe")
	overlay.refresh()

	# Actual persistence including old v4 shape and saved month guard.
	campaign.year = 660
	campaign.month = 3
	campaign.gold = 100
	campaign.strategy_state.production_last_month = MONTH
	result = Production.process_month(campaign.strategy_state, campaign.provinces, FACTION, campaign.gold, MONTH + 1, campaign.scenario_id, campaign.iron_supply_rules)
	campaign.gold = result.gold
	var path: String = OS.get_temp_dir().path_join("samhan_supply_test_%d.json" % OS.get_process_id())
	campaign._on_save_button_pressed(path)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(not saved.has("iron_supply_rules") and not saved.strategy_state.has("iron_supply_rules"), "save cannot embed regional permission table")
	var inventory: String = JSON.stringify(campaign.strategy_state.city_inventory)
	var orders: String = JSON.stringify(campaign.strategy_state.city_production)
	campaign.strategy_state.city_inventory[CITY].iron = 999
	campaign.strategy_state.city_production[CITY].iron_supply.enabled = false
	campaign._on_load_button_pressed(path)
	check(campaign.gold == 84 and JSON.stringify(campaign.strategy_state.city_inventory) == inventory and JSON.stringify(campaign.strategy_state.city_production) == orders and campaign.strategy_state.production_last_month == MONTH + 1, "real save/load restores both reservations, owner, gold, inventory and stamp without producing")
	result = Production.process_month(campaign.strategy_state, campaign.provinces, FACTION, 84, MONTH + 1, campaign.scenario_id, campaign.iron_supply_rules)
	check(result.gold == 84 and JSON.stringify(campaign.strategy_state.city_inventory) == inventory, "real reload cannot repeat completed month")
	for city_id: String in saved.strategy_state.city_production:
		saved.strategy_state.city_production[city_id].erase("iron_supply")
	var old_sword: Dictionary = saved.strategy_state.city_production[CITY].iron_sword.duplicate(true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(saved))
	file.close()
	campaign._on_load_button_pressed(path)
	check(campaign.strategy_state.city_production[CITY].iron_sword == old_sword and not campaign.strategy_state.city_production[CITY].iron_supply.enabled and campaign.strategy_state.production_last_month == MONTH + 1 and campaign.gold == 84 and JSON.stringify(campaign.strategy_state.city_inventory) == inventory, "real previous v4 load adds stopped supply only")
	DirAccess.remove_absolute(path)

	# Actual combat entry points: both player and AI stop orders at capture time.
	for ai: bool in [false, true]:
		var source: String = "sabeol"
		campaign.provinces[source].faction = FACTION
		campaign.provinces[source].troops = 1000000
		campaign.provinces[CITY].faction = "백제"
		campaign.provinces[CITY].troops = 1
		for recipe: String in Data.RECIPE_ORDER:
			campaign.strategy_state.city_production[CITY][recipe] = {"enabled": true, "owner": "백제"}
		var before_research: String = JSON.stringify(campaign.strategy_state.faction_research)
		var before_buildings: String = JSON.stringify(campaign.strategy_state.province_buildings)
		if ai:
			campaign.resolve_ai_attack(source, CITY)
		else:
			campaign.resolve_attack(source, CITY)
		check(campaign.provinces[CITY].faction == FACTION and not campaign.strategy_state.city_production[CITY].iron_supply.enabled and not campaign.strategy_state.city_production[CITY].iron_sword.enabled, "actual %s combat capture stops both processes" % ("AI" if ai else "player"))
		check(JSON.stringify(campaign.strategy_state.faction_research) == before_research and JSON.stringify(campaign.strategy_state.province_buildings) == before_buildings and JSON.stringify(campaign.strategy_state.city_inventory) == inventory, "combat capture preserves research ownership, facilities and item stocks")
	campaign.queue_free()
	await runner.process_frame
	await runner.process_frame
