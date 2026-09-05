extends RefCounted

# Separate headless process only. Synthetic dates/owners/resources below are NOT
# the actual-play verification, which uses UI commands and ordinary monthly turns.
const CampaignScene = preload("res://campaign_main.tscn")
const Scenarios = preload("res://scenario_data.gd")
const Production = preload("res://production_system.gd")
const Supply = preload("res://iron_supply_data.gd")
const CITY: String = "geumgwan"
var runner: SceneTree


func check(ok: bool, label: String) -> void:
	runner.check(ok, "iron pilot: " + label)


func run(host: SceneTree) -> void:
	runner = host
	for scenario: Dictionary in Scenarios.SCENARIOS:
		runner.root.set_meta("new_game_settings", {
			"scenario_id": scenario.id, "scenario_year": scenario.year,
			"scenario_season": scenario.season, "faction": "silla",
			"play_style": "historical", "difficulty": "normal",
		})
		var c = CampaignScene.instantiate()
		runner.root.add_child(c)
		runner.current_scene = c
		await runner.process_frame
		await runner.process_frame
		var pilot: bool = int(scenario.year) in [632, 642]
		check(c.provinces[CITY].faction == "신라", str(scenario.year) + " real new-game owner remains Silla")
		var tech_ok: bool = true
		for faction: String in c.strategy_state.faction_research:
			tech_ok = tech_ok and int(c.strategy_state.faction_research[faction].get("basic_smelting", 0)) == (1 if pilot and faction == "신라" else 0)
		check(tech_ok, str(scenario.year) + " only pilot Silla receives basic smelting")
		check(c.gold == 1000 and c.strategy_state.city_inventory[CITY].iron == 0 and c.strategy_state.city_inventory[CITY].sword == 0 and int(c.strategy_state.province_buildings[CITY].get("smelter", 0)) == 0 and c.strategy_state.province_buildings[CITY].forge == 0 and c.strategy_state.faction_research["신라"].swordsmithing == 0, str(scenario.year) + " no extra money, stocks, facilities or sword technology")
		check(Supply.blocked_reason(c.scenario_id, CITY).is_empty() == pilot, str(scenario.year) + " regional permission matches start identity")
		if pilot:
			await save_and_capture_cases(c)
		c.queue_free()
		await runner.process_frame
		await runner.process_frame


func save_and_capture_cases(c: Node) -> void:
	var identity: String = c.scenario_id
	# Synthetic far-future date verifies that a start-632/642 campaign does not
	# change permissions when its calendar crosses a different scenario year.
	c.year = 670
	c.month = 1
	check(c.scenario_id == identity and c.get_production_view_model(CITY, "iron_supply").can_build, identity + " keeps regional permission in year 670")
	var path: String = OS.get_temp_dir().path_join("samhan_pilot_%d.json" % OS.get_process_id())
	# Simulate a previous save with explicit start identity but no starting tech.
	c.strategy_state.faction_research["신라"].basic_smelting = 0
	c.strategy_state.city_inventory[CITY].iron = 17
	c.strategy_state.city_inventory[CITY].sword = 9
	c.strategy_state.production_last_month = 670 * 12 + 1
	Production.set_enabled(c.strategy_state, c.provinces, CITY, "iron_sword", "신라", true, c.scenario_id)
	c._on_save_button_pressed(path)
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	c._on_load_button_pressed(path)
	check(c.scenario_id == identity and c.strategy_state.faction_research["신라"].basic_smelting == 0 and c.strategy_state.city_inventory[CITY].iron == 17 and c.strategy_state.city_inventory[CITY].sword == 9 and c.strategy_state.city_production[CITY].iron_sword.enabled and c.gold == 1000, identity + " old save retains identity/stocks/order and receives no technology or money")
	var result: Dictionary = Production.process_month(c.strategy_state, c.provinces, "신라", c.gold, 670 * 12 + 1, c.scenario_id)
	check(result.gold == 1000 and c.strategy_state.city_inventory[CITY].iron == 17 and c.strategy_state.city_inventory[CITY].sword == 9, identity + " saved month blocks duplicate production")
	# Legacy v3/no strategy also goes through _init_strategy_state: no new-game grant.
	var legacy: Dictionary = saved.duplicate(true)
	legacy.erase("strategy_state")
	legacy.save_version = 3
	_write_save(path, legacy)
	c._on_load_button_pressed(path)
	check(c.scenario_id == identity and c.strategy_state.faction_research["신라"].basic_smelting == 0 and c.strategy_state.city_inventory[CITY].iron == 0, identity + " legacy strategy initialization grants no pilot technology")
	# Missing or unknown identity cannot activate supply from a matching current year.
	for missing_id: String in ["", "unknown_start"]:
		legacy = saved.duplicate(true)
		legacy.year = 632
		if missing_id.is_empty():
			legacy.erase("scenario_id")
		else:
			legacy.scenario_id = missing_id
		_write_save(path, legacy)
		c._on_load_button_pressed(path)
		check(not c.get_production_view_model(CITY, "iron_supply").can_start and not c.request_production_command(CITY, "iron_supply", "build").ok and c.strategy_state.faction_research["신라"].basic_smelting == 0, identity + " missing/unknown saved start cannot infer permission from year 632")
	_write_save(path, saved)
	c._on_load_button_pressed(path)
	# Separate capture fixture: permission stays regional, country technology does not move.
	c.strategy_state.province_buildings[CITY].smelter = 1
	c.strategy_state.faction_research["신라"].basic_smelting = 1
	Production.set_enabled(c.strategy_state, c.provinces, CITY, "iron_supply", "신라", true, c.scenario_id)
	c.provinces[CITY].faction = "백제"
	Production.stop_on_capture(c.strategy_state, CITY)
	check(not c.strategy_state.city_production[CITY].iron_supply.enabled and not c.strategy_state.city_production[CITY].iron_sword.enabled and c.strategy_state.city_inventory[CITY].iron == 17 and c.strategy_state.province_buildings[CITY].smelter == 1, identity + " capture stops orders and preserves stocks/facility")
	var batch: Dictionary = Production.validate_batch(c.strategy_state, c.provinces, CITY, "iron_supply", "백제", 100, c.scenario_id)
	check(Supply.blocked_reason(c.scenario_id, CITY).is_empty() and not batch.ok and str(batch.reason).contains("basic_smelting") and not c.request_production_command(CITY, "iron_supply", "start").ok, identity + " captured city keeps region but requires new owner's technology and authority")
	c.strategy_state.faction_research["백제"].basic_smelting = 1
	check(Production.validate_batch(c.strategy_state, c.provinces, CITY, "iron_supply", "백제", 100, c.scenario_id).ok, identity + " qualified new owner can use the same regional facility")
	DirAccess.remove_absolute(path)


func _write_save(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()
