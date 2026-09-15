extends SceneTree

const Setup = preload("res://new_game_setup.tscn")
const Scenarios = preload("res://scenario_data.gd")
const Army = preload("res://army_readiness.gd")
const Recruit = preload("res://recruitment_system.gd")
const Mob = preload("res://mobilization.gd")
const Industry = preload("res://industry_assignment.gd")
const Production = preload("res://production_system.gd")
const IndustryOverlay = preload("res://industry_assignment_overlay.gd")
const SupplyOverlay = preload("res://supply_transport_overlay.gd")

var failures: int = 0
var checks: int = 0
var evidence: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _run() -> void:
	create_timer(90.0).timeout.connect(func(): quit(2))
	check(change_scene_to_packed(Setup) == OK, "open actual setup scene")
	await create_timer(1.0).timeout
	var setup: Node = current_scene
	var scenario_index: int = -1
	for index: int in range(Scenarios.SCENARIOS.size()):
		if int(Scenarios.SCENARIOS[index].year) == 663:
			scenario_index = index
	check(scenario_index >= 0, "663 scenario exists")
	if scenario_index < 0:
		quit(1)
		return
	setup.scenario_buttons[scenario_index].pressed.emit()
	setup.faction_buttons["goguryeo"].button_pressed = true
	await process_frame
	check(setup.selected_faction_id == "goguryeo" and not setup.start_button.disabled, "663 Goguryeo selectable")
	setup.start_button.pressed.emit()
	await create_timer(2.0).timeout
	var campaign: Node = current_scene
	check(campaign.scene_file_path == "res://campaign_main.tscn", "actual start button enters campaign")
	if campaign.scene_file_path != "res://campaign_main.tscn":
		quit(1)
		return
	check(campaign.year == 663 and campaign.month == 7 and campaign.player_faction_id == "goguryeo", "663 scenario starting season and Goguryeo identity")
	for step: int in range(30):
		if not campaign.event_presentation.active:
			break
		campaign.event_presentation.view.skip_button.pressed.emit()
		await process_frame
	check(not campaign.map_area.cutscene_input_locked and not campaign.end_turn_button.disabled, "opening completes and campaign input unlocks")
	check(not root.has_meta("new_game_settings"), "campaign consumes setup metadata")
	evidence["entry"] = {"year":campaign.year,"month":campaign.month,"faction":campaign.player_faction_id,"gold":campaign.gold}
	_calculations(campaign)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png("res://.godot/warnings-campaign-663.png") == OK, "capture rendered campaign")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var label: String = args[0] if not args.is_empty() else "after"
	var baseline_path: String = "res://.godot/warnings-calculations-before.json"
	if label != "before" and FileAccess.file_exists(baseline_path):
		var baseline: Variant = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
		check(JSON.parse_string(JSON.stringify(evidence)) == baseline, "all calculation samples match unmodified baseline")
	var output := FileAccess.open("res://.godot/warnings-calculations-" + label + ".json", FileAccess.WRITE)
	output.store_string(JSON.stringify(evidence, "\t"))
	output.close()
	print("WARNING REGRESSION: %d checks, %d failures; 663 Goguryeo actual setup transition" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _calculations(campaign: Node) -> void:
	var state: Dictionary = campaign.strategy_state.duplicate(true)
	var provinces: Dictionary = campaign.provinces.duplicate(true)
	var city: String = "pyongyang"
	var faction: String = "goguryeo"
	var stamp: int = 663 * 12 + 1
	check(provinces.has(city), "Goguryeo capital exists")
	var recruitment: Array = []
	# Values immediately around payment and 100-person boundaries.
	for gold: int in [0, 14, 15, 29, 30, 149, 150, 151, 1000]:
		state.faction_economy.accounts[faction].balance = gold
		for food: int in [0, 19, 20, 39, 40, 199, 200, 201, 10000]:
			provinces[city].food_stock = food
			for target: int in [-101, -1, 0, 99, 100, 101, 199, 200, 1001]:
				var amount: int = Recruit.affordable(state, provinces, faction, city, target)
				check(amount >= 0 and amount % 100 == 0 and amount <= maxi(0, target), "whole affordable recruitment batches")
				var quote: Dictionary = Recruit.quote(state, provinces, faction, faction, city, amount)
				check(int(quote.gold_cost) <= gold and int(quote.food_cost) <= food, "quote stays within gold and food")
				recruitment.append([gold, food, target, amount, quote.gold_cost, quote.food_cost])
	evidence["recruitment"] = recruitment
	var manpower: Array = []
	for population: int in [0, 1, 999, 1000, 1999, 2000, 99999, 100000]:
		provinces[city].population = population
		manpower.append([population, Mob.view(state, provinces, city)])
	evidence["mobilization"] = manpower
	var split_samples: Array = []
	for total: int in [3, 101, 1001, 99999]:
		for amount: int in [1, 2, total - 1]:
			var army_state: Dictionary = {"army":{"next_id":1},"unit_rosters":{}}
			var original: Dictionary = Army.create(army_state, faction, city, total, "infantry", 53, total + 49)
			var split_id: String = Army.divide(army_state, original.id, amount)
			var part: Dictionary = Army.units(army_state)[split_id]
			check(typeof(part.equipment) == TYPE_INT and typeof(part.training_points) == TYPE_INT, "split keeps integer resources")
			check(int(original.troops) + int(part.troops) == total and int(original.equipment) + int(part.equipment) == total + 49 and int(original.training_points) + int(part.training_points) == total * 53, "split conserves troops equipment training")
			split_samples.append([total, amount, part.equipment, part.training_points, part.origins])
	evidence["splits"] = split_samples
	var construction: Array = []
	for level: int in [0, 1, 2]:
		var building_state: Dictionary = {"province_buildings":{city:{"market":level}},"construction_queues":{}}
		var quote: Dictionary = campaign.strategy.get_building_quote(building_state, city, "market")
		construction.append(quote)
		check(quote.ok and quote.turns == int(campaign.strategy.BUILDING_DEFS.market.base_turns) + (1 if level == 2 else 0), "building duration increases after two levels")
	evidence["construction"] = construction
	var production: Array = []
	state = campaign.strategy_state.duplicate(true)
	provinces = campaign.provinces.duplicate(true)
	for remainder: int in [0, 1, 49, 50, 99]:
		state["facility_progress"] = {city:{"forge":{"owner":provinces[city].faction,"remainder":remainder}}}
		var quote: Dictionary = Production.facility_quote(state, provinces, city, "forge", stamp, campaign.scenario_id)
		check(quote.possible_batches == 1, "incomplete production batch stays in remainder")
		production.append([remainder, quote.work, quote.possible_batches, quote.remainder])
	evidence["production"] = production
	var dates: Array = []
	var industry_view := IndustryOverlay.new()
	var supply_view := SupplyOverlay.new()
	for month_stamp: int in [663 * 12 + 1, 663 * 12 + 12, 664 * 12 + 1]:
		dates.append([industry_view.date(month_stamp), supply_view.date(month_stamp)])
	check(dates == [["663년 1월","663년 1월"],["663년 12월","663년 12월"],["664년 1월","664년 1월"]], "December to January date rollover")
	industry_view.free()
	supply_view.free()
	evidence["dates"] = dates
