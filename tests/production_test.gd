extends SceneTree

# Separate headless test process. Fixtures never change a real campaign save/start resources.
# godot --headless --path . --script res://tests/production_test.gd
const Production = preload("res://production_system.gd")
const Catalog = preload("res://production_data.gd")
const Strategy = preload("res://samhan_strategy_systems.gd")
const CampaignScene = preload("res://campaign_main.tscn")
const RECIPE: String = "iron_sword"
const CITY: String = "geumseong"
const FACTION: String = "신라"

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + description)
	else:
		print("PASS: " + description)


func fixture() -> Dictionary:
	var provinces: Dictionary = {CITY: {"faction": FACTION, "name": "금성"}}
	var state: Dictionary = {
		"faction_research": {FACTION: {"swordsmithing": 1}},
		"province_buildings": {CITY: {"forge": 1}},
	}
	Production.normalize_state(state, provinces)
	state["city_inventory"][CITY]["iron"] = 10
	Production.set_enabled(state, provinces, CITY, RECIPE, FACTION, true)
	return {"state": state, "provinces": provinces}


func _unit_cases() -> void:
	var f: Dictionary = fixture()
	var result: Dictionary = Production.process_month(f.state, f.provinces, FACTION, 100, 7922)
	check(result.gold == 90 and f.state.city_inventory[CITY].iron == 8 and f.state.city_inventory[CITY].sword == 1, "normal batch: gold 100 -> 90, iron 10 -> 8, sword 0 -> 1")
	var snapshot: String = JSON.stringify(f.state)
	result = Production.process_month(f.state, f.provinces, FACTION, 90, 7922)
	check(result.gold == 90 and JSON.stringify(f.state) == snapshot, "same month does not produce twice")
	Production.set_enabled(f.state, f.provinces, CITY, RECIPE, FACTION, false)
	Production.set_enabled(f.state, f.provinces, CITY, RECIPE, FACTION, true)
	result = Production.process_month(f.state, f.provinces, FACTION, 90, 7922)
	check(result.gold == 90 and f.state.city_inventory[CITY].sword == 1, "stop/start cannot bypass month guard")
	result = Production.process_month(f.state, f.provinces, FACTION, 90, 7923)
	check(result.gold == 80 and f.state.city_inventory[CITY].sword == 2, "following month produces one batch")

	for condition: String in ["material", "gold", "technology", "facility", "stopped", "ownership", "order_owner"]:
		f = fixture()
		var starting_gold: int = 100
		match condition:
			"material": f.state.city_inventory[CITY].iron = 1
			"gold": starting_gold = 9
			"technology": f.state.faction_research[FACTION].swordsmithing = 0
			"facility": f.state.province_buildings[CITY].forge = 0
			"stopped": Production.set_enabled(f.state, f.provinces, CITY, RECIPE, FACTION, false)
			"ownership": f.provinces[CITY].faction = "백제"
			"order_owner": f.state.city_production[CITY][RECIPE].owner = "백제"
		var before: String = JSON.stringify(f.state.city_inventory)
		result = Production.process_month(f.state, f.provinces, FACTION, starting_gold, 7922)
		check(result.gold == starting_gold and JSON.stringify(f.state.city_inventory) == before, condition + ": no partial deduction")
		if condition != "stopped":
			var expected_status: String = "중지" if condition in ["ownership", "order_owner"] else "보류"
			check(f.state.city_production[CITY][RECIPE].status == expected_status and f.state.city_production[CITY][RECIPE].reason != "", condition + ": explains suspension or ownership stop")

	f = fixture()
	f.state.city_inventory[CITY].iron = 2
	result = Production.process_month(f.state, f.provinces, FACTION, 10, 7922)
	check(result.gold == 0 and f.state.city_inventory[CITY].iron == 0 and f.state.city_inventory[CITY].sword == 1, "exact material and gold boundary")
	check(not Production.set_enabled(f.state, f.provinces, CITY, RECIPE, "백제", true).ok, "foreign production command rejected")
	check(not Production.set_enabled(f.state, f.provinces, CITY, "unknown", FACTION, true).ok, "unknown recipe rejected")
	check(not Production.set_enabled(f.state, f.provinces, "missing", RECIPE, FACTION, true).ok, "missing city rejected")
	var loaded: Dictionary = JSON.parse_string(JSON.stringify(f.state))
	Production.normalize_state(loaded, f.provinces)
	result = Production.process_month(loaded, f.provinces, FACTION, 0, 7922)
	check(result.gold == 0 and loaded.city_inventory[CITY].sword == 1 and loaded.city_production[CITY][RECIPE].enabled, "JSON round trip preserves stocks, settings and month guard")
	var old: Dictionary = {}
	Production.normalize_state(old, f.provinces)
	check(old.city_inventory[CITY].iron == 0 and old.city_inventory[CITY].sword == 0 and not old.city_production[CITY][RECIPE].enabled, "legacy defaults grant no resources")

	# Shared national funds are allocated in stable city ID order, never overdrawn.
	f = fixture()
	f.provinces["second"] = {"faction": FACTION, "name": "Test second city"}
	Production.normalize_state(f.state, f.provinces)
	f.state.city_inventory.second.iron = 10
	f.state.province_buildings["second"] = {"forge": 1}
	Production.set_enabled(f.state, f.provinces, "second", RECIPE, FACTION, true)
	result = Production.process_month(f.state, f.provinces, FACTION, 10, 7922)
	check(result.gold == 0 and f.state.city_inventory[CITY].sword + f.state.city_inventory.second.sword == 1, "two cities cannot spend the same national gold")


func _catalog_cases() -> void:
	var basic_count: int = 0
	var expansion_count: int = 0
	var metadata_valid: bool = true
	var expansions_inactive: bool = true
	for item_id: String in Catalog.ITEMS:
		var item: Dictionary = Catalog.ITEMS[item_id]
		basic_count += 1 if item.tier == "core" else 0
		expansion_count += 1 if item.tier == "expansion" else 0
		metadata_valid = metadata_valid and item.id == item_id and Catalog.ITEM_CATEGORIES.has(item.category)
		metadata_valid = metadata_valid and Catalog.PRODUCTION_METHODS.has(item.production_method)
		metadata_valid = metadata_valid and item.economic_use != "" and item.military_use != "" and not item.regional_placement_confirmed
		metadata_valid = metadata_valid and item.has("existence_evidence") and item.has("regional_evidence")
		for source_id: String in item.source_ids:
			metadata_valid = metadata_valid and Catalog.SOURCES.has(source_id)
		for source_id: String in item.existence_evidence.source_ids:
			metadata_valid = metadata_valid and Catalog.SOURCES.has(source_id)
		for evidence: Dictionary in item.regional_evidence:
			for source_id: String in evidence.source_ids:
				metadata_valid = metadata_valid and Catalog.SOURCES.has(source_id)
		if item.tier == "expansion":
			expansions_inactive = expansions_inactive and not item.enabled and item.recipe_ids.is_empty()
	check(basic_count == 14 and expansion_count == 4, "catalog has exactly 14 core and 4 expansion items")
	check(metadata_valid, "catalog IDs, categories, evidence sources and unconfirmed placements are consistent")
	check(expansions_inactive, "all four expansion candidates remain inactive without recipes")
	check(Catalog.canonical_item_id("weapons") == "sword" and not Catalog.ITEMS.has("weapons"), "weapons is an alias of sword, not an additional item")
	check(Catalog.RECIPES.size() == 2 and Catalog.RECIPES[RECIPE].inputs == {"iron": 2} and Catalog.RECIPES[RECIPE].outputs == {"sword": 1} and Catalog.RECIPES[RECIPE].operating_gold == 10, "added supply does not replace existing iron 2 / gold 10 / sword 1 balance")
	var provinces: Dictionary = {CITY: {"faction": FACTION, "food_stock": 2345}}
	# Exact previous implementation's saved inventory shape, before catalog defaults existed.
	var state: Dictionary = {"city_inventory": {CITY: {"iron": 17, "sword": 9}}}
	Production.normalize_state(state, provinces)
	check(state.city_inventory[CITY].iron == 17 and state.city_inventory[CITY].sword == 9, "previous iron/sword-only save keeps both quantities")
	check(Production.get_stock(state, provinces, CITY, "weapons") == 9 and not state.city_inventory[CITY].has("weapons"), "alias lookup reads the single sword ledger")
	check(Production.get_stock(state, provinces, CITY, "grain") == 2345 and not state.city_inventory[CITY].has("grain"), "grain reads food_stock without creating inventory grain")
	provinces[CITY].food_stock = 1234
	check(Production.get_stock(state, provinces, CITY, "grain") == 1234, "grain lookup immediately reflects existing food economy changes")
	var view: Dictionary = Production.get_inventory_view(state, provinces, CITY)
	check(view.size() == 14 and view.grain == 1234 and view.sword == 9 and not view.has("weapons"), "inventory view includes 14 core items with one weapons count")
	view.grain = 999
	view.sword = 999
	check(provinces[CITY].food_stock == 1234 and state.city_inventory[CITY].sword == 9, "UI snapshot cannot write back into either ledger")
	state.city_inventory[CITY].grain = 999
	state.city_inventory[CITY].weapons = 9
	Production.normalize_state(state, provinces)
	check(not state.city_inventory[CITY].has("grain") and not state.city_inventory[CITY].has("weapons") and provinces[CITY].food_stock == 1234 and state.city_inventory[CITY].sword == 9, "duplicate aliases are removed without summing or granting grain/weapons")
	state.city_inventory[CITY].erase("sword")
	state.city_inventory[CITY].weapons = 7
	Production.normalize_state(state, provinces)
	check(state.city_inventory[CITY].sword == 7 and not state.city_inventory[CITY].has("weapons"), "alias-only input is canonicalized once without duplication")
	var before: String = JSON.stringify(state)
	Production.normalize_state(state, provinces)
	check(before == JSON.stringify(state), "catalog normalization is idempotent")
	var all_blocked: bool = true
	for item_id: String in Catalog.ITEMS:
		all_blocked = all_blocked and not Production.set_enabled(state, provinces, CITY, item_id, FACTION, true).ok
		if not Catalog.ITEMS[item_id].enabled:
			all_blocked = all_blocked and not state.city_inventory[CITY].has(item_id)
	check(all_blocked, "item definitions are not executable recipes and inactive defaults create no stocks")
	state.city_production[CITY]["armor"] = {"enabled": true, "owner": FACTION}
	var inventory_before: String = JSON.stringify(state.city_inventory)
	var result: Dictionary = Production.process_month(state, provinces, FACTION, 100, 7922)
	check(result.gold == 100 and JSON.stringify(state.city_inventory) == inventory_before, "injected order for an unimplemented product cannot execute")


func _run() -> void:
	# Script errors must not leave a headless fixture process running indefinitely.
	create_timer(45.0).timeout.connect(func() -> void: quit(2))
	_unit_cases()
	_catalog_cases()
	var campaign = CampaignScene.instantiate()
	root.add_child(campaign)
	current_scene = campaign
	await process_frame
	await process_frame
	check(campaign.strategy_state.city_inventory[CITY].iron == 0, "real new campaign receives no test iron")
	check(campaign.strategy_state.faction_research[FACTION].swordsmithing == 0, "new campaign does not claim historical production technology")
	campaign.gold = 1000
	var result: Dictionary = campaign.request_production_command(CITY, RECIPE, "research")
	check(result.ok and campaign.gold == 800 and campaign.strategy_state.research_queues[FACTION].remaining_turns == 1, "research UI command queues existing national research and charges 200")
	result = campaign.request_production_command(CITY, RECIPE, "research")
	check(not result.ok and campaign.gold == 800, "repeated research command does not charge again")
	result = campaign.request_production_command(CITY, RECIPE, "build")
	check(result.ok and campaign.gold == 480 and campaign.strategy_state.construction_queues[CITY].remaining_turns == 2, "construction UI command reuses forge: cost 320, two seasonal ticks")
	result = campaign.request_production_command(CITY, RECIPE, "build")
	check(not result.ok and campaign.gold == 480, "repeated construction command does not charge again")
	campaign.strategy._process_research(campaign.strategy_state)
	campaign.strategy._process_construction(campaign.strategy_state)
	check(campaign.strategy_state.faction_research[FACTION].swordsmithing == 1 and campaign.strategy_state.province_buildings[CITY].forge == 0, "research complete but unfinished forge cannot qualify")
	campaign.strategy._process_construction(campaign.strategy_state)
	check(campaign.strategy_state.province_buildings[CITY].forge == 1, "forge completes through original construction backend")

	campaign.select_province(CITY)
	await process_frame
	await process_frame
	var card: Control = campaign.map_area.floating_city_card
	var grid: GridContainer = card.get_node("Margin/Content/Actions")
	check(grid.columns == 3 and grid.get_child_count() == 6, "city card has six actions in two rows")
	var map_rect := Rect2(Vector2.ZERO, campaign.map_area.size)
	check(map_rect.encloses(Rect2(card.position, card.size)), "city card fits inside map")
	card.get_node("Margin/Content/Actions/ProductionButton").pressed.emit()
	check(campaign.production_overlay.visible, "production button -> card signal -> map signal -> campaign -> overlay")
	var production_panel: Control = campaign.production_overlay.get_child(1)
	await process_frame
	check(production_panel.position.x > 0 and production_panel.size.x < campaign.production_overlay.size.x, "production panel retains viewport margins")
	check(campaign.production_overlay.details.text.contains("도시 재고") and campaign.production_overlay.details.text.contains("철 부족"), "production screen shows inventory and blocked material")
	check(campaign.production_overlay.details.text.contains("곡물·군량") and campaign.production_overlay.details.text.contains("무기 (칼)") and not campaign.production_overlay.details.text.contains("구리 ("), "default inventory prioritizes held goods and current recipe inputs/outputs")
	check(campaign.production_overlay.details.text.contains("본게임 생산지 배치 미적용"), "unplaced main-game iron supply is explicitly explained")
	campaign.production_overlay.all_items_toggle.button_pressed = true
	var all_shown: bool = true
	for item: Dictionary in Catalog.ITEMS.values():
		all_shown = all_shown and campaign.production_overlay.catalog_label.text.contains(item.name)
	check(campaign.production_overlay.catalog_label.visible and all_shown and campaign.production_overlay.catalog_label.text.contains("경제 역할:") and campaign.production_overlay.catalog_label.text.contains("군사 역할:"), "all items toggle displays core roles and inactive expansion candidates")
	check(not campaign.production_overlay.start_button.visible and campaign.production_overlay.catalog_label.text.contains("비활성 · 생산 불가") and campaign.production_overlay.catalog_label.text.contains("정의만 등록 · 생산법 미구현"), "catalog offers no manufacturing controls for definitions alone")
	campaign.production_overlay.all_items_toggle.button_pressed = false
	check(campaign.production_overlay.start_button.visible and campaign.production_overlay.details.visible, "return from catalog preserves original production controls")
	check(not campaign.request_production_command(CITY, "armor", "start").ok and campaign.get_production_view_model(CITY, "tea").is_empty(), "campaign UI API rejects products without implemented recipes")
	campaign.production_overlay.start_button.pressed.emit()
	check(campaign.strategy_state.city_production[CITY][RECIPE].enabled, "screen start action persists production setting")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	campaign._input(escape)
	check(not campaign.production_overlay.visible, "Esc returns to map")
	campaign._on_city_card_production_requested(CITY)
	production_panel.get_child(0).get_child(0).get_child(1).pressed.emit()
	check(not campaign.production_overlay.visible, "close button returns to map")
	var saved_faction: String = campaign.provinces[CITY].faction
	campaign.provinces[CITY].faction = "백제"
	var foreign_model: Dictionary = campaign.get_production_view_model(CITY, RECIPE)
	check(not foreign_model.owned and not foreign_model.can_build and not foreign_model.can_research, "foreign production view disables commands")
	result = campaign.request_production_command(CITY, RECIPE, "start")
	check(not result.ok, "campaign rejects stale UI command after ownership change")
	campaign.provinces[CITY].faction = saved_faction

	# Controlled test fixture only: monthly integration and unchanged grain formula.
	campaign.ai_attack_ratio = 1000000.0
	campaign.ai_recruitment_amount = 0
	campaign.year = 660
	campaign.month = 1
	campaign._sync_season_from_month()
	campaign.strategy_state.city_inventory[CITY].iron = 10
	campaign.gold = 100
	var expected_income: int = 0
	for city_id: String in campaign.Korea35Data.PROVINCE_IDS:
		if campaign._get_province_controller(campaign.provinces[city_id]) == campaign.CONTROLLER_PLAYER:
			expected_income += campaign.calculate_monthly_commerce_income(campaign.provinces[city_id])
	var province_copy: Dictionary = campaign.provinces[CITY].duplicate(true)
	province_copy.food_stock = maxi(0, int(province_copy.food_stock) - campaign.calculate_monthly_troop_food(province_copy))
	var expected_food: int = int(province_copy.food_stock) - campaign.calculate_monthly_storage_loss(province_copy)
	campaign._on_end_turn_button_pressed()
	check(campaign.month == 2 and campaign.gold == 100 + expected_income - 10, "one turn = one month, monthly commerce then one production charge")
	check(campaign.strategy_state.city_inventory[CITY].iron == 8 and campaign.strategy_state.city_inventory[CITY].sword == 1, "actual end turn produces one batch")
	check(campaign.provinces[CITY].food_stock == expected_food, "production preserves monthly troop upkeep and storage loss")

	var grain: Dictionary = {"population": 100000, "agriculture": 80, "commerce": 60, "public_order": 100, "troops": 10000, "food_stock": 12000, "granary_capacity": 10000}
	check(campaign.calculate_annual_harvest(grain) == 8000 and campaign.calculate_collected_harvest(grain) == 3600, "harvest collection remains 45 percent")
	check(campaign.calculate_monthly_commerce_income(grain) == 120 and campaign.calculate_monthly_troop_food(grain) == 100, "commerce and troop food formula unchanged")
	check(campaign.calculate_monthly_storage_loss(grain) == 200, "normal stock loss 0.5 percent and excess loss 7.5 percent")
	campaign.month = 10
	campaign._sync_season_from_month()
	check(campaign.calculate_monthly_storage_loss(grain) == 250, "winter stock loss remains 1 percent")
	check(is_equal_approx(campaign.get_public_order_efficiency(0), 0.5) and is_equal_approx(campaign.get_public_order_efficiency(100), 1.0), "public order efficiency preserved")
	var saved_province: Dictionary = campaign.provinces[CITY]
	grain["faction"] = FACTION
	grain["name"] = "Test harvest"
	grain.food_stock = 0
	campaign.provinces[CITY] = grain
	campaign.month = 9
	campaign.process_seasonal_harvest()
	check(grain.food_stock == 2520, "September receives 70 percent of collected harvest")
	campaign.month = 10
	campaign.process_seasonal_harvest()
	check(grain.food_stock == 3600, "October receives remaining 30 percent")
	campaign.provinces[CITY] = saved_province
	campaign.month = 2
	campaign._sync_season_from_month()

	# Real save/load handlers, redirected to an isolated OS temporary file.
	var save_path: String = OS.get_temp_dir().path_join("samhan_production_test_%d.json" % OS.get_process_id())
	var before_gold: int = campaign.gold
	var before_inventory: String = JSON.stringify(campaign.strategy_state.city_inventory)
	var before_orders: String = JSON.stringify(campaign.strategy_state.city_production)
	campaign._on_save_button_pressed(save_path)
	check(FileAccess.file_exists(save_path), "test save written to isolated temporary path")
	campaign.strategy_state.city_inventory[CITY].iron = 999
	campaign.strategy_state.city_production[CITY][RECIPE].enabled = false
	campaign.gold = 999
	campaign._on_load_button_pressed(save_path)
	check(campaign.gold == before_gold and JSON.stringify(campaign.strategy_state.city_inventory) == before_inventory and JSON.stringify(campaign.strategy_state.city_production) == before_orders, "actual save/load restores gold, city stocks and production settings without granting resources")
	result = Production.process_month(campaign.strategy_state, campaign.provinces, FACTION, campaign.gold, 660 * 12 + 2)
	check(result.gold == before_gold and JSON.stringify(campaign.strategy_state.city_inventory) == before_inventory, "actual reload cannot repeat same month production")
	var v4_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	for city_id: String in v4_save.strategy_state.city_inventory:
		var saved_inventory: Dictionary = v4_save.strategy_state.city_inventory[city_id]
		v4_save.strategy_state.city_inventory[city_id] = {"iron": int(saved_inventory.iron), "sword": int(saved_inventory.sword)}
	var v4_file := FileAccess.open(save_path, FileAccess.WRITE)
	v4_file.store_string(JSON.stringify(v4_save))
	v4_file.close()
	campaign._on_load_button_pressed(save_path)
	check(campaign.strategy_state.city_inventory[CITY].iron == 8 and campaign.strategy_state.city_inventory[CITY].sword == 1 and campaign.gold == before_gold, "actual previous v4 iron/sword-only save preserves stocks and gold")
	check(not campaign.strategy_state.city_inventory[CITY].has("grain") and not campaign.strategy_state.city_inventory[CITY].has("weapons"), "actual load creates neither duplicate grain nor duplicate weapons ledger")
	# Original seasonal queues must not advance on ordinary monthly turns.
	campaign.strategy_state.province_buildings[CITY].forge = 0
	campaign.strategy_state.faction_research[FACTION].swordsmithing = 0
	campaign.strategy_state.construction_queues[CITY] = {"building_id": "forge", "target_level": 1, "remaining_turns": 1}
	campaign.strategy_state.research_queues[FACTION] = {"research_id": "swordsmithing", "target_level": 1, "remaining_turns": 1}
	campaign._on_end_turn_button_pressed()
	check(campaign.month == 3 and campaign.strategy_state.construction_queues[CITY].remaining_turns == 1 and campaign.strategy_state.research_queues[FACTION].remaining_turns == 1, "ordinary month does not advance seasonal construction/research")
	campaign._on_end_turn_button_pressed()
	check(campaign.month == 4 and campaign.strategy_state.province_buildings[CITY].forge == 1 and campaign.strategy_state.faction_research[FACTION].swordsmithing == 1, "April transition completes original seasonal queues")
	check(campaign.strategy_state.city_inventory[CITY].sword == 1, "production waits during the month requirements finish")
	campaign._on_end_turn_button_pressed()
	check(campaign.month == 5 and campaign.strategy_state.city_inventory[CITY].sword == 2, "completed technology/facility apply on following month")
	var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	old_save.save_version = 3
	for key: String in ["city_inventory", "city_production", "production_last_month"]:
		old_save.strategy_state.erase(key)
	var test_file := FileAccess.open(save_path, FileAccess.WRITE)
	test_file.store_string(JSON.stringify(old_save))
	test_file.close()
	campaign._on_load_button_pressed(save_path)
	check(campaign.gold == before_gold and campaign.strategy_state.city_inventory[CITY].iron == 0 and campaign.strategy_state.city_inventory[CITY].sword == 0 and not campaign.strategy_state.city_production[CITY][RECIPE].enabled, "actual v3 load defaults to zero stocks and stopped production")
	DirAccess.remove_absolute(save_path)

	campaign.queue_free()
	await process_frame
	await process_frame
	await preload("res://tests/iron_supply_test.gd").new().run(self)
	await preload("res://tests/iron_pilot_test.gd").new().run(self)
	print("PRODUCTION TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
