extends Control

const ScenarioData = preload("res://scenario_data.gd")

const SAVE_PATH: String = "user://campaign_save_9_regions.json"
const SEASONS: Array[String] = ["봄", "여름", "가을", "겨울"]
const ATTACK_FOOD_COST: int = 500
const FACTION_ID_TO_NAME: Dictionary = {
	"silla": "신라",
	"baekje": "백제",
	"goguryeo": "고구려",
	"baekje_revival": "백제부흥군",
	"tang": "당",
	"goguryeo_revival": "고구려부흥군",
}
const PLAY_STYLE_NAMES: Dictionary = {
	"historical": "역사적 게임플레이",
	"fictional": "가상 게임플레이",
}
const DIFFICULTY_NAMES: Dictionary = {
	"easy": "쉬움",
	"normal": "보통",
	"hard": "어려움",
}
const SEASON_ID_TO_INDEX: Dictionary = {
	"spring": 0,
	"summer": 1,
	"autumn": 2,
	"winter": 3,
}
const REQUIRED_PROVINCE_IDS: Array[String] = [
	"ansi", "gungnae", "pyongyang",
	"ungjin", "sabi", "gosa",
	"gukwon", "sabeol", "geumseong",
]
const REQUIRED_PROVINCE_FIELDS: Array[String] = [
	"name", "faction", "governor", "population",
	"agriculture", "commerce", "public_order",
	"troops", "fortress",
]
const ADDITIONAL_OFFICER_ASSIGNMENTS: Dictionary = {
	"연남생": {"home": "pyongyang", "faction": "고구려"},
	"흥수": {"home": "ungjin", "faction": "백제"},
	"계백": {"home": "gosa", "faction": "백제"},
	"김흠순": {"home": "gukwon", "faction": "신라"},
	"관창": {"home": "sabeol", "faction": "신라"},
	"김유신": {"home": "geumseong", "faction": "신라"},
	"김인문": {"home": "geumseong", "faction": "신라"},
}

var year: int = 660
var season_index: int = 0
var gold: int = 1000
var food: int = 3000

var player_faction: String = "신라"
var player_faction_id: String = "silla"
var play_style: String = "historical"
var difficulty: String = "normal"
var scenario_id: String = "baekje_fall_660"
var ai_recruitment_amount: int = 500
var ai_attack_ratio: float = 3.5

var selected_province_id: String = ""
var attack_source_id: String = ""
var selected_officer_name: String = ""
var attack_commander_name: String = ""

# ==========================================
# 1. 게임 핵심 데이터 (9영지 및 장수)
# ==========================================

var provinces: Dictionary = {
	"ansi": {
		"name": "안시성", "faction": "고구려", "governor": "양만춘",
		"population": 150000, "agriculture": 60, "commerce": 55,
		"public_order": 85, "troops": 40000, "fortress": 95,
	},
	"gungnae": {
		"name": "국내성", "faction": "고구려", "governor": "고연무",
		"population": 130000, "agriculture": 65, "commerce": 60,
		"public_order": 80, "troops": 25000, "fortress": 85,
	},
	"pyongyang": {
		"name": "평양성", "faction": "고구려", "governor": "연개소문",
		"population": 180000, "agriculture": 72, "commerce": 65,
		"public_order": 70, "troops": 35000, "fortress": 85,
	},
	"ungjin": {
		"name": "웅진성", "faction": "백제", "governor": "흑치상지",
		"population": 110000, "agriculture": 68, "commerce": 62,
		"public_order": 65, "troops": 20000, "fortress": 80,
	},
	"sabi": {
		"name": "사비성", "faction": "백제", "governor": "의자왕",
		"population": 140000, "agriculture": 68, "commerce": 75,
		"public_order": 48, "troops": 22000, "fortress": 72,
	},
	"gosa": {
		"name": "고사성", "faction": "백제", "governor": "부여태",
		"population": 90000, "agriculture": 55, "commerce": 50,
		"public_order": 60, "troops": 15000, "fortress": 65,
	},
	"gukwon": {
		"name": "국원소경", "faction": "신라", "governor": "김법민",
		"population": 100000, "agriculture": 65, "commerce": 70,
		"public_order": 80, "troops": 18000, "fortress": 70,
	},
	"sabeol": {
		"name": "사벌주", "faction": "신라", "governor": "품일",
		"population": 115000, "agriculture": 70, "commerce": 60,
		"public_order": 75, "troops": 20000, "fortress": 68,
	},
	"geumseong": {
		"name": "금성", "faction": "신라", "governor": "김춘추",
		"population": 120000, "agriculture": 74, "commerce": 61,
		"public_order": 78, "troops": 28000, "fortress": 76,
	},
}

var province_connections: Dictionary = {
	"ansi": ["gungnae"],
	"gungnae": ["ansi", "pyongyang"],
	"pyongyang": ["gungnae", "ungjin", "gukwon"],
	"ungjin": ["pyongyang", "sabi", "gukwon"],
	"sabi": ["ungjin", "gosa", "geumseong"],
	"gosa": ["sabi", "geumseong"],
	"gukwon": ["pyongyang", "ungjin", "sabeol"],
	"sabeol": ["gukwon", "geumseong"],
	"geumseong": ["sabi", "gosa", "sabeol"],
}

var officers: Dictionary = {
	"양만춘": {"name": "양만춘", "leadership": 94, "war": 89, "intelligence": 85, "politics": 70, "authority": 88},
	"고연무": {"name": "고연무", "leadership": 82, "war": 85, "intelligence": 72, "politics": 60, "authority": 75},
	"연개소문": {"name": "연개소문", "leadership": 96, "war": 95, "intelligence": 88, "politics": 82, "authority": 98},
	"연남생": {"name": "연남생", "leadership": 86, "war": 84, "intelligence": 76, "politics": 68, "authority": 82},
	"흑치상지": {"name": "흑치상지", "leadership": 92, "war": 90, "intelligence": 81, "politics": 65, "authority": 85},
	"흥수": {"name": "흥수", "leadership": 78, "war": 65, "intelligence": 93, "politics": 90, "authority": 82},
	"계백": {"name": "계백", "leadership": 94, "war": 95, "intelligence": 76, "politics": 62, "authority": 88},
	"김법민": {"name": "김법민", "leadership": 88, "war": 80, "intelligence": 90, "politics": 92, "authority": 95},
	"의자왕": {"name": "의자왕", "leadership": 70, "war": 65, "intelligence": 75, "politics": 80, "authority": 90},
	"품일": {"name": "품일", "leadership": 85, "war": 88, "intelligence": 75, "politics": 68, "authority": 80},
	"부여태": {"name": "부여태", "leadership": 75, "war": 78, "intelligence": 60, "politics": 55, "authority": 70},
	"김춘추": {"name": "김춘추", "leadership": 75, "war": 60, "intelligence": 95, "politics": 98, "authority": 95},
	"김유신": {"name": "김유신", "leadership": 95, "war": 93, "intelligence": 84, "politics": 73, "authority": 91},
	"김흠순": {"name": "김흠순", "leadership": 86, "war": 84, "intelligence": 78, "politics": 72, "authority": 83},
	"김인문": {"name": "김인문", "leadership": 82, "war": 76, "intelligence": 88, "politics": 90, "authority": 85},
	"관창": {"name": "관창", "leadership": 72, "war": 90, "intelligence": 55, "politics": 45, "authority": 74},
}

var officers_by_province: Dictionary = {
	"ansi": ["양만춘"],
	"gungnae": ["고연무"],
	"pyongyang": ["연개소문", "연남생"],
	"ungjin": ["흑치상지", "흥수"],
	"sabi": ["의자왕"],
	"gosa": ["부여태", "계백"],
	"gukwon": ["김법민", "김흠순"],
	"sabeol": ["품일", "관창"],
	"geumseong": ["김춘추", "김유신", "김인문"],
}

# ==========================================
# 2. UI 노드 레퍼런스
# ==========================================

@onready var map_area: Control = $MainVBox/Content/MapPanel/MapArea

@onready var date_label: Label = $MainVBox/TopBar/DateLabel
@onready var gold_label: Label = $MainVBox/TopBar/GoldLabel
@onready var food_label: Label = $MainVBox/TopBar/FoodLabel
@onready var end_turn_button: Button = $MainVBox/TopBar/EndTurnButton
@onready var save_button: Button = (
	$MainVBox/TopBar.get_node_or_null("SaveButton") as Button
)
@onready var load_button: Button = (
	$MainVBox/TopBar.get_node_or_null("LoadButton") as Button
)

@onready var province_name_label: Label = $MainVBox/Content/ProvincePanel/ProvinceVBox/ProvinceNameLabel
@onready var faction_label: Label = $MainVBox/Content/ProvincePanel/ProvinceVBox/FactionLabel
@onready var governor_label: Label = $MainVBox/Content/ProvincePanel/ProvinceVBox/GovernorLabel
@onready var population_label: Label = $MainVBox/Content/ProvincePanel/ProvinceVBox/PopulationLabel
@onready var agriculture_label: Label = $MainVBox/Content/ProvincePanel/ProvinceVBox/AgricultureLabel
@onready var commerce_label: Label = $MainVBox/Content/ProvincePanel/ProvinceVBox/CommerceLabel
@onready var public_order_label: Label = $MainVBox/Content/ProvincePanel/ProvinceVBox/PublicOrderLabel
@onready var troops_label: Label = $MainVBox/Content/ProvincePanel/ProvinceVBox/TroopsLabel
@onready var fortress_label: Label = $MainVBox/Content/ProvincePanel/ProvinceVBox/FortressLabel
@onready var log_label: Label = $MainVBox/Content/ProvincePanel/ProvinceVBox/LogLabel

@onready var develop_button: Button = $MainVBox/Content/ProvincePanel/ProvinceVBox/DevelopButton
@onready var commerce_button: Button = $MainVBox/Content/ProvincePanel/ProvinceVBox/CommerceButton
@onready var recruit_button: Button = $MainVBox/Content/ProvincePanel/ProvinceVBox/RecruitButton
@onready var attack_button: Button = $MainVBox/Content/ProvincePanel/ProvinceVBox/AttackButton

@onready var officer_list: ItemList = %OfficerList
@onready var officer_detail_label: Label = %OfficerDetailLabel


func _ready() -> void:
	_apply_new_game_settings()

	_bind_city_buttons()
	_connect_button_once(
		officer_list.item_selected,
		_on_officer_list_item_selected
	)
	_connect_button_once(develop_button.pressed, _on_develop_button_pressed)
	_connect_button_once(commerce_button.pressed, _on_commerce_button_pressed)
	_connect_button_once(recruit_button.pressed, _on_recruit_button_pressed)
	_connect_button_once(attack_button.pressed, _on_attack_button_pressed)
	_connect_button_once(end_turn_button.pressed, _on_end_turn_button_pressed)

	if save_button != null:
		_connect_button_once(save_button.pressed, _on_save_button_pressed)

	if load_button != null:
		_connect_button_once(load_button.pressed, _on_load_button_pressed)

	update_top_bar()
	select_province(_get_starting_province_id())
	log_label.text = (
		"%s · %s 난이도로 시작합니다."
		% [
			PLAY_STYLE_NAMES.get(play_style, "역사적 게임플레이"),
			DIFFICULTY_NAMES.get(difficulty, "보통"),
		]
	)


func _connect_button_once(signal_value: Signal, callable: Callable) -> void:
	if not signal_value.is_connected(callable):
		signal_value.connect(callable)


func _bind_city_buttons() -> void:
	var city_button_names: Dictionary = {
		"ansi": "AnsiButton",
		"gungnae": "GungnaeButton",
		"pyongyang": "PyongyangButton",
		"ungjin": "UngjinButton",
		"gukwon": "GukwonButton",
		"sabi": "SabiButton",
		"sabeol": "SabeolButton",
		"gosa": "GosaButton",
		"geumseong": "GeumseongButton",
	}

	for city_id_value in city_button_names.keys():
		var city_id: String = str(city_id_value)
		var button_name: String = str(city_button_names[city_id])
		var button_node: Node = map_area.get_node_or_null(button_name)

		if button_node is Button:
			var button: Button = button_node as Button
			var select_callable: Callable = select_province.bind(city_id)

			if not button.pressed.is_connected(select_callable):
				button.pressed.connect(select_callable)
		else:
			push_warning(
				"CampaignMain: MapArea에서 %s 버튼을 찾을 수 없습니다."
				% button_name
			)


func _apply_new_game_settings() -> void:
	var root: Window = get_tree().root
	var settings: Dictionary = {}
	if root.has_meta("new_game_settings"):
		var settings_value: Variant = root.get_meta("new_game_settings")
		root.remove_meta("new_game_settings")
		if typeof(settings_value) == TYPE_DICTIONARY:
			settings = settings_value

	var faction_id: String = str(settings.get("faction", "silla"))
	var requested_play_style: String = str(
		settings.get("play_style", "historical")
	)
	var requested_difficulty: String = str(
		settings.get("difficulty", "normal")
	)

	if PLAY_STYLE_NAMES.has(requested_play_style):
		play_style = requested_play_style

	if DIFFICULTY_NAMES.has(requested_difficulty):
		difficulty = requested_difficulty

	scenario_id = str(
		settings.get("scenario_id", ScenarioData.DEFAULT_SCENARIO_ID)
	)
	var scenario: Dictionary = ScenarioData.get_scenario(scenario_id)
	year = int(settings.get("scenario_year", scenario.get("year", 660)))
	var season_id: String = str(
		settings.get("scenario_season", scenario.get("season", "spring"))
	)
	season_index = int(SEASON_ID_TO_INDEX.get(season_id, 0))

	_apply_scenario_state(scenario_id)
	var faction_data: Dictionary = ScenarioData.get_faction(
		scenario_id,
		faction_id
	)
	if faction_data.is_empty():
		faction_id = "silla"
	player_faction_id = faction_id
	player_faction = ScenarioData.get_faction_name(
		scenario_id,
		player_faction_id
	)

	_apply_difficulty_settings()


func _apply_scenario_state(requested_scenario_id: String) -> void:
	var scenario: Dictionary = ScenarioData.get_scenario(requested_scenario_id)
	officers = ScenarioData.get_officer_database()

	var overrides: Dictionary = scenario.get("province_overrides", {})
	for province_id_value: Variant in overrides.keys():
		var province_id: String = str(province_id_value)
		if not provinces.has(province_id):
			continue
		var province_override: Dictionary = overrides[province_id]
		for field_value: Variant in province_override.keys():
			var field_name: String = str(field_value)
			provinces[province_id][field_name] = province_override[field_name]

	var assignments_value: Variant = scenario.get(
		"officers_by_province",
		{}
	)
	if typeof(assignments_value) == TYPE_DICTIONARY:
		var assignments: Dictionary = assignments_value
		officers_by_province = assignments.duplicate(true)


func _apply_difficulty_settings(
	apply_starting_resources: bool = true
) -> void:
	match difficulty:
		"easy":
			if apply_starting_resources:
				gold = 1500
				food = 4500
			ai_recruitment_amount = 300
			ai_attack_ratio = 4.0
		"hard":
			if apply_starting_resources:
				gold = 800
				food = 2500
			ai_recruitment_amount = 800
			ai_attack_ratio = 3.0
		_:
			if apply_starting_resources:
				gold = 1000
				food = 3000
			ai_recruitment_amount = 500
			ai_attack_ratio = 3.5


func _get_starting_province_id() -> String:
	return ScenarioData.get_starting_province(
		scenario_id,
		player_faction_id
	)


func select_province(province_id: String) -> void:
	if not provinces.has(province_id):
		return

	selected_province_id = province_id
	var province: Dictionary = provinces[province_id]

	province_name_label.text = province["name"]
	faction_label.text = "세력: %s" % province["faction"]
	governor_label.text = "태수: %s" % province["governor"]
	population_label.text = "인구: %d" % province["population"]
	agriculture_label.text = "농업: %d" % province["agriculture"]
	commerce_label.text = "상업: %d" % province["commerce"]
	public_order_label.text = "치안: %d" % province["public_order"]
	troops_label.text = "병력: %d" % province["troops"]
	fortress_label.text = "성벽: %d" % province["fortress"]

	update_officer_list(province_id)

	var player_owned: bool = province["faction"] == player_faction
	develop_button.disabled = not player_owned
	commerce_button.disabled = not player_owned
	recruit_button.disabled = not player_owned

	update_attack_button(province_id)
	update_province_log(province_id)


func update_province_log(province_id: String) -> void:
	var province: Dictionary = provinces[province_id]
	var player_owned: bool = province["faction"] == player_faction

	if attack_source_id == "":
		if player_owned:
			if selected_officer_name == "":
				log_label.text = "장수를 선택하면 출전 지휘관으로 지정됩니다."
			else:
				log_label.text = "%s을 출전 지휘관으로 선택했습니다." % selected_officer_name
		else:
			log_label.text = "다른 세력의 영지에는 명령을 내릴 수 없습니다."
		return

	if province_id == attack_source_id:
		log_label.text = (
			"%s이 %s에서 출전을 준비합니다.\n인접한 적 영지를 선택하세요."
			% [attack_commander_name, provinces[attack_source_id]["name"]]
		)
		return

	if are_provinces_connected(attack_source_id, province_id) and not player_owned:
		log_label.text = (
			"%s이 이끄는 %s군으로 %s을 공격할 수 있습니다."
			% [
				attack_commander_name,
				provinces[attack_source_id]["name"],
				province["name"],
			]
		)
		return

	log_label.text = "공격할 수 없는 영지입니다."


func update_officer_list(province_id: String) -> void:
	officer_list.clear()
	selected_officer_name = ""

	if provinces[province_id]["faction"] == player_faction:
		officer_detail_label.text = "출전시킬 장수를 선택하세요."
	else:
		officer_detail_label.text = "장수를 선택하면 능력치를 확인합니다."

	var province_officers: Array = officers_by_province.get(province_id, [])

	for officer_name_value in province_officers:
		var officer_name: String = str(officer_name_value)

		if officers.has(officer_name):
			officer_list.add_item(officer_name)


func _on_officer_list_item_selected(index: int) -> void:
	if selected_province_id == "":
		return

	if index < 0 or index >= officer_list.item_count:
		return

	var officer_name: String = officer_list.get_item_text(index)

	if not officers.has(officer_name):
		return

	var officer: Dictionary = officers[officer_name]
	var is_player_officer: bool = (
		provinces[selected_province_id]["faction"] == player_faction
	)
	var selection_text: String = ""

	if is_player_officer and attack_source_id == "":
		selected_officer_name = officer_name
		selection_text = "\n출전 지휘관으로 선택됨"

	officer_detail_label.text = (
		"[%s] · %s%s\n통솔: %d\n무력: %d\n지략: %d\n정치: %d\n권위: %d"
		% [
			officer["name"],
			ScenarioData.get_age_text(officer_name, year),
			selection_text,
			officer["leadership"],
			officer["war"],
			officer["intelligence"],
			officer["politics"],
			officer["authority"],
		]
	)

	if is_player_officer and attack_source_id == "":
		update_attack_button(selected_province_id)
		log_label.text = "%s을 출전 지휘관으로 선택했습니다." % officer_name


func update_attack_button(province_id: String) -> void:
	if not provinces.has(province_id):
		attack_button.disabled = true
		return

	var province: Dictionary = provinces[province_id]
	var player_owned: bool = province["faction"] == player_faction

	if attack_source_id == "":
		if not player_owned:
			attack_button.text = "공격 준비"
			attack_button.disabled = true
		elif not has_enemy_neighbor(province_id):
			attack_button.text = "인접한 적 영지 없음"
			attack_button.disabled = true
		elif selected_officer_name == "":
			attack_button.text = "장수 선택 후 공격"
			attack_button.disabled = true
		else:
			attack_button.text = "%s 출전" % selected_officer_name
			attack_button.disabled = false
		return

	if province_id == attack_source_id:
		attack_button.text = "공격 취소"
		attack_button.disabled = false
		return

	if are_provinces_connected(attack_source_id, province_id) and not player_owned:
		attack_button.text = "%s 공격" % province["name"]
		attack_button.disabled = false
		return

	attack_button.text = "인접한 적 영지 선택"
	attack_button.disabled = true


func has_enemy_neighbor(province_id: String) -> bool:
	var neighbors: Array = province_connections.get(province_id, [])

	for neighbor_value in neighbors:
		var neighbor_id: String = str(neighbor_value)

		if not provinces.has(neighbor_id):
			continue

		if provinces[neighbor_id]["faction"] != player_faction:
			return true

	return false


func are_provinces_connected(source_id: String, target_id: String) -> bool:
	var neighbors: Array = province_connections.get(source_id, [])
	return neighbors.has(target_id)


func _on_attack_button_pressed() -> void:
	if selected_province_id == "":
		return

	var selected_province: Dictionary = provinces[selected_province_id]

	if attack_source_id == "":
		if selected_province["faction"] != player_faction:
			log_label.text = (
				"%s 영지에서만 공격을 시작할 수 있습니다."
				% player_faction
			)
			return

		if not has_enemy_neighbor(selected_province_id):
			log_label.text = "인접한 적 영지가 없습니다."
			return

		if not _is_officer_in_province(
			selected_officer_name,
			selected_province_id
		):
			log_label.text = "출전할 장수를 먼저 선택하세요."
			return

		if int(selected_province["troops"]) < 3000:
			log_label.text = "공격하려면 최소 3,000명의 병력이 필요합니다."
			return

		attack_source_id = selected_province_id
		attack_commander_name = selected_officer_name
		update_attack_button(selected_province_id)
		log_label.text = (
			"%s이 %s에서 출전을 준비합니다.\n인접한 적 영지를 선택하세요."
			% [attack_commander_name, selected_province["name"]]
		)
		return

	if selected_province_id == attack_source_id:
		attack_source_id = ""
		attack_commander_name = ""
		select_province(selected_province_id)
		log_label.text = "공격 준비를 취소했습니다."
		return

	if not are_provinces_connected(attack_source_id, selected_province_id):
		log_label.text = "두 영지는 서로 연결되어 있지 않습니다."
		return

	if selected_province["faction"] == player_faction:
		log_label.text = "아군 영지는 공격할 수 없습니다."
		return

	if food < ATTACK_FOOD_COST:
		log_label.text = "공격에 필요한 군량 %d이 부족합니다." % ATTACK_FOOD_COST
		return

	resolve_attack(attack_source_id, selected_province_id)


func _is_officer_in_province(
	officer_name: String,
	province_id: String
) -> bool:
	if officer_name == "" or not officers.has(officer_name):
		return false

	var province_officers: Array = officers_by_province.get(province_id, [])
	return province_officers.has(officer_name)


func is_selected_province_player_owned() -> bool:
	if selected_province_id == "":
		return false

	if not provinces.has(selected_province_id):
		return false

	return provinces[selected_province_id]["faction"] == player_faction


func get_best_commander(province_id: String) -> Dictionary:
	var province_officers: Array = officers_by_province.get(province_id, [])
	var best_commander: Dictionary = {
		"name": provinces[province_id]["governor"],
		"leadership": 50,
		"war": 50,
	}

	for officer_name_value in province_officers:
		var officer_name: String = str(officer_name_value)

		if not officers.has(officer_name):
			continue

		var officer: Dictionary = officers[officer_name]

		if int(officer["leadership"]) > int(best_commander["leadership"]):
			best_commander = officer

	return best_commander


func get_player_attack_commander(source_id: String) -> Dictionary:
	if _is_officer_in_province(attack_commander_name, source_id):
		return officers[attack_commander_name]

	# 저장 데이터나 장수 배치가 바뀐 예외 상황에서만 자동 선택합니다.
	return get_best_commander(source_id)


func resolve_attack(source_id: String, target_id: String) -> void:
	var attacker: Dictionary = provinces[source_id]
	var defender: Dictionary = provinces[target_id]
	var attacker_commander: Dictionary = get_player_attack_commander(source_id)
	var defender_commander: Dictionary = get_best_commander(target_id)

	var attacker_troops: int = int(attacker["troops"])
	var defender_troops: int = int(defender["troops"])
	var attacker_leadership: int = int(attacker_commander["leadership"])
	var defender_leadership: int = int(defender_commander["leadership"])
	var fortress: int = int(defender["fortress"])

	var attacker_power: int = int(
		float(attacker_troops) * (1.0 + float(attacker_leadership) / 100.0)
	)

	var defender_power: int = int(
		float(defender_troops)
		* (1.0 + float(defender_leadership) / 100.0 + float(fortress) / 200.0)
	)

	food -= ATTACK_FOOD_COST
	var result_message: String = ""

	if attacker_power > defender_power:
		var attacker_losses: int = mini(
			attacker_troops - 1000,
			maxi(1000, int(float(defender_troops) * 0.55))
		)
		var surviving_attackers: int = attacker_troops - attacker_losses
		var source_garrison: int = maxi(500, int(float(surviving_attackers) * 0.35))
		var occupation_force: int = maxi(500, surviving_attackers - source_garrison)

		attacker["troops"] = source_garrison
		defender["troops"] = occupation_force
		defender["faction"] = player_faction
		defender["governor"] = attacker_commander["name"]
		defender["public_order"] = 35
		_move_commander_to_province(
			str(attacker_commander["name"]),
			source_id,
			target_id
		)

		result_message = (
			"%s이 지휘한 %s군이 %s을 점령했습니다.\n"
			+ "공격군 손실: %d명 | 점령지 치안: 35"
		) % [
			attacker_commander["name"],
			player_faction,
			defender["name"],
			attacker_losses,
		]
	else:
		var attacker_losses: int = maxi(1000, int(float(attacker_troops) * 0.45))
		var defender_losses: int = maxi(500, int(float(attacker_troops) * 0.20))

		attacker["troops"] = maxi(1000, attacker_troops - attacker_losses)
		defender["troops"] = maxi(1000, defender_troops - defender_losses)

		result_message = (
			"%s 공략에 실패했습니다.\n공격군 손실: %d명 | 수비군 손실: %d명"
			% [defender["name"], attacker_losses, defender_losses]
		)

	attack_source_id = ""
	attack_commander_name = ""
	selected_officer_name = ""
	select_province(target_id)
	update_top_bar()
	log_label.text = result_message

	if player_controls_all_provinces():
		log_label.text += (
			"\n%s가 모든 영지를 통일했습니다!"
			% player_faction
		)


func player_controls_all_provinces() -> bool:
	for province_value in provinces.values():
		var province: Dictionary = province_value

		if province["faction"] != player_faction:
			return false

	return true


func _on_develop_button_pressed() -> void:
	if not is_selected_province_player_owned():
		log_label.text = "플레이어 소유 영지에서만 농업을 개발할 수 있습니다."
		return

	if gold < 100:
		log_label.text = "금이 부족합니다."
		return

	gold -= 100
	var current_value: int = int(provinces[selected_province_id]["agriculture"])
	provinces[selected_province_id]["agriculture"] = current_value + 3

	select_province(selected_province_id)
	log_label.text = "농업이 3 상승했습니다."
	update_top_bar()


func _on_commerce_button_pressed() -> void:
	if not is_selected_province_player_owned():
		log_label.text = "플레이어 소유 영지에서만 상업을 개발할 수 있습니다."
		return

	if gold < 100:
		log_label.text = "금이 부족합니다."
		return

	gold -= 100
	var current_value: int = int(provinces[selected_province_id]["commerce"])
	provinces[selected_province_id]["commerce"] = current_value + 3

	select_province(selected_province_id)
	log_label.text = "상업이 3 상승했습니다."
	update_top_bar()


func _on_recruit_button_pressed() -> void:
	if not is_selected_province_player_owned():
		log_label.text = "플레이어 소유 영지에서만 징병할 수 있습니다."
		return

	if gold < 150 or food < 200:
		log_label.text = "금 또는 군량이 부족합니다."
		return

	gold -= 150
	food -= 200
	var current_troops: int = int(provinces[selected_province_id]["troops"])
	provinces[selected_province_id]["troops"] = current_troops + 1000

	select_province(selected_province_id)
	log_label.text = "병력 1,000명을 징병했습니다."
	update_top_bar()


func _on_end_turn_button_pressed() -> void:
	attack_source_id = ""
	attack_commander_name = ""
	selected_officer_name = ""
	season_index += 1

	if season_index >= SEASONS.size():
		season_index = 0
		year += 1

	var public_order_message: String = process_public_order()

	for province_value in provinces.values():
		var province: Dictionary = province_value

		if province["faction"] != player_faction:
			continue

		var income_rate: float = get_public_order_income_rate(int(province["public_order"]))
		var gold_income: int = int(float(int(province["commerce"]) * 2) * income_rate)
		var food_income: int = int(float(int(province["agriculture"]) * 3) * income_rate)

		gold += gold_income
		food += food_income

	var ai_message: String = run_enemy_ai_turns()

	update_top_bar()

	if selected_province_id != "":
		select_province(selected_province_id)

	log_label.text = "계절이 지나 세금과 군량을 확보했습니다."

	if public_order_message != "":
		log_label.text += "\n" + public_order_message

	if ai_message != "":
		log_label.text += "\n" + ai_message


func process_public_order() -> String:
	var messages: Array[String] = []

	for province_id_value in provinces.keys():
		var province_id: String = str(province_id_value)
		var province: Dictionary = provinces[province_id]
		var previous_order: int = int(province["public_order"])

		if previous_order >= 100:
			continue

		var recovered_order: int = mini(100, previous_order + 5)
		province["public_order"] = recovered_order

		if province["faction"] == player_faction:
			messages.append(
				"%s 치안: %d → %d"
				% [province["name"], previous_order, recovered_order]
			)

	return combine_messages(messages)


func get_public_order_income_rate(public_order: int) -> float:
	if public_order >= 80:
		return 1.0

	if public_order >= 60:
		return 0.75

	if public_order >= 40:
		return 0.50

	return 0.25


func run_enemy_ai_turns() -> String:
	var ai_province_ids: Array[String] = []

	for province_id_value in provinces.keys():
		var province_id: String = str(province_id_value)
		var province: Dictionary = provinces[province_id]

		if province["faction"] != player_faction:
			ai_province_ids.append(province_id)

	var messages: Array[String] = []

	for source_id in ai_province_ids:
		if not provinces.has(source_id):
			continue

		var source: Dictionary = provinces[source_id]

		if source["faction"] == player_faction:
			continue

		source["troops"] = (
			int(source["troops"]) + ai_recruitment_amount
		)
		var target_id: String = find_ai_target(source_id)

		if target_id != "":
			var target: Dictionary = provinces[target_id]
			var required_troops: int = int(
				float(target["troops"]) * ai_attack_ratio
			)

			if int(source["troops"]) >= required_troops:
				messages.append(resolve_ai_attack(source_id, target_id))
				continue

		messages.append(
			"%s의 %s군이 병력 %d명을 충원했습니다."
			% [
				source["name"],
				source["faction"],
				ai_recruitment_amount,
			]
		)

	return combine_messages(messages)


func find_ai_target(source_id: String) -> String:
	var neighbors: Array = province_connections.get(source_id, [])
	var weakest_target_id: String = ""
	var weakest_troops: int = 2147483647
	var source_faction: String = str(provinces[source_id]["faction"])

	for neighbor_value in neighbors:
		var neighbor_id: String = str(neighbor_value)

		if not provinces.has(neighbor_id):
			continue

		var neighbor: Dictionary = provinces[neighbor_id]

		if play_style == "fictional":
			if neighbor["faction"] == source_faction:
				continue
		else:
			if neighbor["faction"] != player_faction:
				continue

		var neighbor_troops: int = int(neighbor["troops"])

		if neighbor_troops < weakest_troops:
			weakest_troops = neighbor_troops
			weakest_target_id = neighbor_id

	return weakest_target_id


func resolve_ai_attack(source_id: String, target_id: String) -> String:
	var attacker: Dictionary = provinces[source_id]
	var defender: Dictionary = provinces[target_id]
	var attacker_commander: Dictionary = get_best_commander(source_id)
	var defender_commander: Dictionary = get_best_commander(target_id)
	var attacker_troops: int = int(attacker["troops"])
	var defender_troops: int = int(defender["troops"])

	var attacker_power: int = int(
		float(attacker_troops)
		* (1.0 + float(attacker_commander["leadership"]) / 100.0)
	)

	var defender_power: int = int(
		float(defender_troops)
		* (
			1.0
			+ float(defender_commander["leadership"]) / 100.0
			+ float(defender["fortress"]) / 200.0
		)
	)

	if attacker_power > defender_power:
		var attacker_losses: int = mini(
			attacker_troops - 1000,
			maxi(1000, int(float(defender_troops) * 0.50))
		)
		var surviving_attackers: int = attacker_troops - attacker_losses
		var source_garrison: int = maxi(500, int(float(surviving_attackers) * 0.35))
		var occupation_force: int = maxi(500, surviving_attackers - source_garrison)

		attacker["troops"] = source_garrison
		defender["troops"] = occupation_force
		defender["faction"] = attacker["faction"]
		defender["governor"] = attacker_commander["name"]
		defender["public_order"] = 30
		_move_commander_to_province(
			str(attacker_commander["name"]),
			source_id,
			target_id
		)

		return (
			"%s군의 %s이 %s을 점령했습니다."
			% [attacker["faction"], attacker_commander["name"], defender["name"]]
		)

	var attacker_losses: int = maxi(1000, int(float(attacker_troops) * 0.35))
	var defender_losses: int = maxi(500, int(float(attacker_troops) * 0.20))

	attacker["troops"] = maxi(1000, attacker_troops - attacker_losses)
	defender["troops"] = maxi(1000, defender_troops - defender_losses)

	return (
		"%s군의 %s 공격을 방어했습니다."
		% [attacker["faction"], defender["name"]]
	)


func _move_commander_to_province(
	commander_name: String,
	source_id: String,
	target_id: String
) -> void:
	if not officers.has(commander_name):
		return

	var source_officers: Array = officers_by_province.get(source_id, [])
	var target_officers: Array = officers_by_province.get(target_id, [])

	# 마지막 장수 한 명만 남았다면 지휘관은 원래 영지로 복귀하고,
	# 점령지의 기존 장수가 귀순하여 현지 행정을 담당합니다.
	if source_officers.size() <= 1:
		provinces[source_id]["governor"] = commander_name

		if not target_officers.is_empty():
			provinces[target_id]["governor"] = str(target_officers[0])
			return

		# 양쪽 모두 장수가 없는 예외 상황에서만 지휘관을 겸임합니다.
		officers_by_province[target_id] = [commander_name]
		provinces[target_id]["governor"] = commander_name
		return

	source_officers.erase(commander_name)
	officers_by_province[source_id] = source_officers
	provinces[source_id]["governor"] = str(source_officers[0])

	# 현재 프로토타입에서는 점령지의 기존 장수를 포로로 처리합니다.
	officers_by_province[target_id] = [commander_name]
	provinces[target_id]["governor"] = commander_name


func _ensure_additional_officer_assignments() -> void:
	var assigned_officers: Dictionary = {}

	for assignment_value in officers_by_province.values():
		if typeof(assignment_value) != TYPE_ARRAY:
			continue

		var province_officers: Array = assignment_value

		for officer_name_value in province_officers:
			assigned_officers[str(officer_name_value)] = true

	for officer_name_value in ADDITIONAL_OFFICER_ASSIGNMENTS.keys():
		var officer_name: String = str(officer_name_value)

		if assigned_officers.has(officer_name):
			continue

		var assignment: Dictionary = (
			ADDITIONAL_OFFICER_ASSIGNMENTS[officer_name]
		)
		var home_id: String = str(assignment["home"])
		var faction_name: String = str(assignment["faction"])
		var destination_id: String = _find_officer_destination(
			home_id,
			faction_name
		)

		if destination_id == "":
			continue

		var destination_officers: Array = officers_by_province.get(
			destination_id,
			[]
		)
		destination_officers.append(officer_name)
		officers_by_province[destination_id] = destination_officers
		assigned_officers[officer_name] = true

		if provinces[destination_id]["governor"] == "수비대장":
			provinces[destination_id]["governor"] = officer_name


func _find_officer_destination(
	home_id: String,
	faction_name: String
) -> String:
	if (
		provinces.has(home_id)
		and provinces[home_id]["faction"] == faction_name
	):
		return home_id

	for province_id in REQUIRED_PROVINCE_IDS:
		if provinces[province_id]["faction"] == faction_name:
			return province_id

	return ""


func _on_save_button_pressed() -> void:
	var save_data: Dictionary = {
		"save_version": 5,
		"year": year,
		"season_index": season_index,
		"gold": gold,
		"food": food,
		"player_faction": player_faction,
		"player_faction_id": player_faction_id,
		"play_style": play_style,
		"difficulty": difficulty,
		"scenario_id": scenario_id,
		"selected_province_id": selected_province_id,
		"provinces": provinces,
		"officers_by_province": officers_by_province,
	}
	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if save_file == null:
		log_label.text = "저장 파일을 만들 수 없습니다."
		push_error(
			"CampaignMain: save failed (%s)"
			% error_string(FileAccess.get_open_error())
		)
		return

	save_file.store_string(JSON.stringify(save_data, "\t"))
	log_label.text = "%d년 %s 진행 상황을 저장했습니다." % [
		year,
		SEASONS[season_index],
	]


func _on_load_button_pressed() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		log_label.text = "불러올 저장 파일이 없습니다."
		return

	var save_file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if save_file == null:
		log_label.text = "저장 파일을 열 수 없습니다."
		return

	var parsed_value: Variant = JSON.parse_string(save_file.get_as_text())

	if typeof(parsed_value) != TYPE_DICTIONARY:
		log_label.text = "저장 파일 형식이 올바르지 않습니다."
		return

	var save_data: Dictionary = parsed_value

	if not _is_valid_save_data(save_data):
		log_label.text = "9영지 저장 데이터가 손상되었거나 호환되지 않습니다."
		return

	year = int(save_data.get("year", 660))
	season_index = clampi(int(save_data.get("season_index", 0)), 0, 3)
	gold = maxi(0, int(save_data.get("gold", 1000)))
	food = maxi(0, int(save_data.get("food", 3000)))
	player_faction = str(save_data.get("player_faction", "신라"))
	player_faction_id = str(save_data.get("player_faction_id", ""))
	play_style = str(save_data.get("play_style", "historical"))
	difficulty = str(save_data.get("difficulty", "normal"))
	scenario_id = str(save_data.get("scenario_id", "baekje_fall_660"))

	if not ScenarioData.is_known_faction_name(player_faction):
		player_faction = "신라"

	if player_faction_id == "":
		player_faction_id = ScenarioData.get_faction_id_by_name(
			scenario_id,
			player_faction
		)

	var loaded_faction: Dictionary = ScenarioData.get_faction(
		scenario_id,
		player_faction_id
	)
	if loaded_faction.is_empty():
		player_faction_id = "silla"
		player_faction = ScenarioData.get_faction_name(
			scenario_id,
			player_faction_id
		)

	if not PLAY_STYLE_NAMES.has(play_style):
		play_style = "historical"

	if not DIFFICULTY_NAMES.has(difficulty):
		difficulty = "normal"

	var saved_provinces: Dictionary = save_data["provinces"]
	provinces = saved_provinces.duplicate(true)
	officers = ScenarioData.get_officer_database()

	if typeof(save_data.get("officers_by_province", null)) == TYPE_DICTIONARY:
		var saved_assignments: Dictionary = save_data["officers_by_province"]
		officers_by_province = saved_assignments.duplicate(true)

	var save_version: int = int(save_data.get("save_version", 1))
	if save_version < 5 and scenario_id == ScenarioData.DEFAULT_SCENARIO_ID:
		_ensure_additional_officer_assignments()

	attack_source_id = ""
	attack_commander_name = ""
	selected_officer_name = ""
	_apply_difficulty_settings(false)

	var requested_selection: String = str(
		save_data.get("selected_province_id", _get_starting_province_id())
	)

	if not provinces.has(requested_selection):
		requested_selection = _get_starting_province_id()

	update_top_bar()
	select_province(requested_selection)
	_refresh_map_markers()
	log_label.text = "%d년 %s 저장 기록을 불러왔습니다." % [
		year,
		SEASONS[season_index],
	]


func _is_valid_save_data(save_data: Dictionary) -> bool:
	if typeof(save_data.get("provinces", null)) != TYPE_DICTIONARY:
		return false

	var saved_provinces: Dictionary = save_data["provinces"]

	for province_id in REQUIRED_PROVINCE_IDS:
		if not saved_provinces.has(province_id):
			return false

		if typeof(saved_provinces[province_id]) != TYPE_DICTIONARY:
			return false

		var province: Dictionary = saved_provinces[province_id]

		for field_name in REQUIRED_PROVINCE_FIELDS:
			if not province.has(field_name):
				return false

	return true


func _refresh_map_markers() -> void:
	if map_area != null and map_area.has_method("_refresh_marker_data"):
		map_area.call_deferred("_refresh_marker_data")


func combine_messages(messages: Array[String]) -> String:
	var combined_message: String = ""

	for message in messages:
		if combined_message != "":
			combined_message += "\n"

		combined_message += message

	return combined_message


func update_top_bar() -> void:
	var mode_label: String = (
		"가상" if play_style == "fictional" else "역사"
	)
	date_label.text = (
		"%d년 %s · %s · %s"
		% [
			year,
			SEASONS[season_index],
			mode_label,
			DIFFICULTY_NAMES.get(difficulty, "보통"),
		]
	)
	gold_label.text = "금: %d" % gold
	food_label.text = "군량: %d" % food
