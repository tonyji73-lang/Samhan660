extends SceneTree

# Separate process and temporary saves; never modifies a running game or user save.
const Korea = preload("res://korea_35_data.gd")
const Scenarios = preload("res://scenario_data.gd")
const World = preload("res://world_map_data.gd")
const Production = preload("res://production_system.gd")
const Supply = preload("res://iron_supply_data.gd")
const CampaignScene = preload("res://campaign_main.tscn")
const CITY: String = "geumgwan"
const SILLA: String = "신라"
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS: " + description)
	else:
		failures += 1
		push_error("FAIL: " + description)


func same_saved_values(actual: Dictionary, expected: Dictionary) -> bool:
	# Restore both through JSON to compare int/float values on equal terms.
	return JSON.parse_string(JSON.stringify(actual)) == JSON.parse_string(JSON.stringify(expected))


func old_factions(year: int) -> Dictionary:
	# Original source data/fallback, retained to detect unintended scope expansion.
	var result: Dictionary = Korea.DEFAULT_FACTIONS.duplicate(true)
	var applied: int = Korea.SCENARIO_YEARS[0]
	for candidate: int in Korea.SCENARIO_YEARS:
		if year >= candidate:
			applied = candidate
	result.merge(Korea.YEAR_FACTION_OVERRIDES.get(applied, {}), true)
	return result


func source_cases() -> void:
	for year: int in Korea.SCENARIO_YEARS:
		var expected: Dictionary = old_factions(year)
		expected[CITY] = SILLA
		check(Korea.get_factions_for_year(year) == expected, "%d source: only geumgwan corrected (670 unchanged)" % year)
		var template: Dictionary = Korea.get_province_templates()[CITY]
		template.faction = SILLA
		check(Korea.get_province_templates_for_year(year)[CITY] == template, "%d dated template retains all non-owner fields" % year)
	var unchanged: bool = true
	for year: int in range(500, 701):
		if year not in Korea.SCENARIO_YEARS:
			unchanged = unchanged and Korea.get_factions_for_year(year) == old_factions(year)
	check(unchanged, "non-target years retain original nearest-year fallback")
	check(Korea.get_province_templates()[CITY].faction == "가야", "undated editor template remains untouched")
	check(Supply.SCENARIOS.size() == 2 and Supply.SCENARIOS.has("silla_equilibrium_632") and Supply.SCENARIOS.has("goguryeo_coup_642"), "only two pilot start scenarios have iron supply permissions")


func save_cases(campaign: Node) -> void:
	var path: String = OS.get_temp_dir().path_join("samhan_ownership_test_%d.json" % OS.get_process_id())
	# Emulate existing saves with original ownership AND a later captured owner.
	for saved_owner: String in ["가야", "백제"]:
		campaign.provinces[CITY].faction = saved_owner
		campaign.strategy_state.city_inventory[CITY].iron = 17
		campaign.strategy_state.city_inventory[CITY].sword = 9
		campaign.strategy_state.province_buildings[CITY].forge = 1
		campaign.strategy_state.province_buildings[CITY].smelter = 1
		for recipe: String in ["iron_supply", "iron_sword"]:
			var order: Dictionary = campaign.strategy_state.city_production[CITY][recipe]
			order.enabled = true
			order.owner = saved_owner
		campaign.strategy_state.production_last_month = campaign.year * 12 + campaign.month
		campaign.gold = 123
		var province: Dictionary = campaign.provinces[CITY].duplicate(true)
		var inventory: Dictionary = campaign.strategy_state.city_inventory.duplicate(true)
		var orders: Dictionary = campaign.strategy_state.city_production.duplicate(true)
		var facilities: Dictionary = campaign.strategy_state.province_buildings.duplicate(true)
		var research: Dictionary = campaign.strategy_state.faction_research.duplicate(true)
		var stamp: int = campaign.strategy_state.production_last_month
		campaign._on_save_button_pressed(path)
		campaign.provinces[CITY].faction = SILLA
		campaign.strategy_state.city_inventory[CITY].iron = 999
		campaign._on_load_button_pressed(path)
		check(same_saved_values(campaign.provinces[CITY], province), "save %s: city owner, troops, grain and all city values restored" % saved_owner)
		check(same_saved_values(campaign.strategy_state.city_inventory, inventory) and same_saved_values(campaign.strategy_state.province_buildings, facilities), "save %s: inventories and facilities unchanged by load" % saved_owner)
		check(same_saved_values(campaign.strategy_state.city_production, orders) and same_saved_values(campaign.strategy_state.faction_research, research), "save %s: order owners, reservations and national research preserved" % saved_owner)
		check(campaign.gold == 123 and campaign.strategy_state.production_last_month == stamp, "save %s: no load production or catch-up settlement" % saved_owner)
		campaign.select_province(CITY)
		check(campaign.faction_label.text.contains(saved_owner) and campaign.map_area.floating_city_card.faction_label.text.contains(saved_owner) and not campaign.is_selected_province_player_owned(), "save %s: UI/permissions follow saved owner, not initial scenario" % saved_owner)
		var result: Dictionary = Production.process_month(campaign.strategy_state, campaign.provinces, campaign.player_faction, campaign.gold, stamp, campaign.scenario_id, campaign.iron_supply_rules)
		check(result.gold == 123 and campaign.strategy_state.city_inventory == inventory, "save %s: restored month stamp still blocks repeated production" % saved_owner)
	DirAccess.remove_absolute(path)


func campaign_case(scenario: Dictionary, player_id: String) -> void:
	var label: String = "%d / %s" % [scenario.year, player_id]
	var playable: bool = Scenarios.is_faction_playable_by_default(scenario.id, player_id)
	var setup_player: String = player_id if playable else "silla"
	# Same metadata contract as new_game_setup._on_start_pressed(), then real _ready().
	root.set_meta("new_game_settings", {
		"faction": setup_player, "play_style": "historical", "difficulty": "normal",
		"scenario_id": scenario.id, "scenario_year": scenario.year,
		"scenario_season": scenario.season,
	})
	var campaign = CampaignScene.instantiate()
	root.add_child(campaign)
	current_scene = campaign
	await process_frame
	await process_frame
	check(campaign.year == scenario.year and campaign.player_faction_id == setup_player and not root.has_meta("new_game_settings"), label + ": actual new-game settings consumed")
	check(campaign.provinces[CITY].faction == SILLA, label + ": actual campaign owner is Silla")
	if not playable:
		# 670 only offers Silla in normal setup. Exercise foreign authority through
		# an isolated fixture, without unlocking a faction in main-game data.
		label += " (test-only player fixture)"
		campaign.player_faction_id = player_id
		campaign.player_faction = Scenarios.get_faction_name(scenario.id, player_id)
		campaign._refresh_faction_controllers()
	var owned: bool = player_id == "silla"
	var expected_controller: String = campaign.CONTROLLER_PLAYER if owned else campaign.CONTROLLER_AI
	check(campaign._get_province_controller(campaign.provinces[CITY]) == expected_controller, label + ": player/AI controller follows new owner")
	var groups: Dictionary = campaign.strategy._group_provinces_by_faction(campaign.provinces)
	check(CITY in groups.get(SILLA, []) and CITY not in groups.get("가야", []), label + ": faction city grouping includes geumgwan under Silla")
	var template: Dictionary = Korea.get_province_templates()[CITY]
	var fields_unchanged: bool = true
	for key: String in template:
		if key != "faction":
			fields_unchanged = fields_unchanged and campaign.provinces[CITY].get(key) == template[key]
	check(fields_unchanged, label + ": city name, troops, stats, grain and governor retained")
	check(campaign.provinces[CITY].governor == "금관가야 수장" and campaign.officers_by_province.get(CITY, []).is_empty(), label + ": existing generic governor retained; no historical officer assigned")
	campaign.select_province(CITY)
	await process_frame
	await process_frame
	var card: Control = campaign.map_area.floating_city_card
	check(campaign.is_selected_province_player_owned() == owned and card.production_button.disabled == not owned and card.domestic_button.disabled == not owned and campaign.recruit_button.disabled == not owned, label + ": city selection and command buttons obey owner")
	card.detail_button.pressed.emit()
	check(campaign.province_panel.visible and campaign.faction_label.text == "세력: 신라" and card.faction_label.text.contains(SILLA), label + ": card/detail ownership labels agree")
	campaign.map_area._refresh_marker_data()
	check(campaign.map_area.territory_palette_signature.contains("geumgwan:신라"), label + ": territory palette uses Silla ownership")
	check(campaign.map_area.city_buttons[CITY].tooltip_text.contains("· 신라"), label + ": map marker ownership matches card/detail")
	var buildings: Dictionary = campaign.strategy_state.province_buildings[CITY]
	var pilot: bool = int(scenario.year) in [632, 642]
	check(int(buildings.get("smelter", 0)) == 0 and campaign.strategy_state.city_inventory[CITY].iron == 0 and int(campaign.strategy_state.faction_research[SILLA].get("basic_smelting", 0)) == (1 if pilot else 0), label + ": no iron/smelter granted; starting technology follows pilot policy")
	var gold_before: int = campaign.gold
	for action: String in ["start", "build"]:
		var result: Dictionary = campaign.request_production_command(CITY, "iron_supply", action)
		if pilot and owned:
			check(result.ok and campaign.gold == gold_before - (240 if action == "build" else 0), label + ": pilot supply " + action + " uses ordinary cost")
		else:
			check(not result.ok and (not owned or str(result.reason).contains("지역 철 공급 미허용")) and campaign.gold == gold_before, label + ": supply " + action + " remains blocked without charge")
	var start: Dictionary = campaign.request_production_command(CITY, "iron_sword", "start")
	check(bool(start.ok) == owned and campaign.strategy_state.city_production[CITY].iron_sword.enabled == owned, label + ": sword command accepts Silla and rejects foreign player")
	if owned:
		card.production_button.pressed.emit()
		check(campaign.production_overlay.visible and campaign.production_overlay.details.text.contains("지역 제철 공급 시범 배치" if pilot else "본게임 생산지 배치 미적용"), label + ": production button opens screen and explains regional placement")
		if scenario.year == 660:
			save_cases(campaign)
	else:
		campaign._on_city_card_production_requested(CITY)
		check(not campaign.production_overlay.visible, label + ": foreign production screen entry blocked")
	campaign.queue_free()
	await process_frame
	await process_frame


func _run() -> void:
	create_timer(60.0).timeout.connect(func():
		push_error("OWNERSHIP TESTS timed out")
		quit(2)
	)
	source_cases()
	for scenario: Dictionary in Scenarios.SCENARIOS:
		if int(scenario.year) not in Korea.SCENARIO_YEARS:
			continue
		var world_provinces: Dictionary = World.get_scenario_provinces(scenario.year, scenario.get("province_overrides", {}))
		check(not world_provinces.has(CITY), "%d setup map has no competing world owner override for geumgwan" % scenario.year)
		await campaign_case(scenario, "silla")
		var foreign_id: String = ""
		for id: String in Scenarios.get_active_faction_ids(scenario.id):
			if id != "silla" and Scenarios.is_faction_playable_by_default(scenario.id, id):
				foreign_id = id
				break
		if foreign_id.is_empty():
			foreign_id = "tang"
			check(scenario.year == 670 and not Scenarios.is_faction_playable_by_default(scenario.id, foreign_id), "670 retains Silla-only new-game availability; foreign commands tested with fixture")
		await campaign_case(scenario, foreign_id)
	print("OWNERSHIP TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
