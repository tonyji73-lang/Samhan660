extends Control

const Korea35Data = preload("res://korea_35_data.gd")
const WorldMapData = preload("res://world_map_data.gd")
const ScenarioData = preload("res://scenario_data.gd")
const SamhanStrategySystems = preload("res://samhan_strategy_systems.gd")

const SAVE_PATH: String = "user://campaign_save_35_regions_v1.json"
const SEASONS: Array[String] = ["봄", "여름", "가을", "겨울"]
const ATTACK_FOOD_COST: int = 500
const CONTROLLER_PLAYER: String = "PLAYER"
const CONTROLLER_AI: String = "AI"
const CONTROLLER_INACTIVE: String = "INACTIVE"

@export_group("Project Paths")
@export_file("*.tscn") var setup_scene_path: String = "res://new_game_setup.tscn"
@export_file("*.tscn") var title_scene_path: String = "res://title_screen.tscn"
const FACTION_ID_TO_NAME: Dictionary = {
	"silla": "신라",
	"baekje": "백제",
	"goguryeo": "고구려",
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
const REQUIRED_PROVINCE_IDS: Array[String] = Korea35Data.PROVINCE_IDS
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
var faction_controllers: Dictionary = {}
var play_style: String = "historical"
var difficulty: String = "normal"
var scenario_id: String = "baekje_fall_660"
var ai_recruitment_amount: int = 500
var ai_attack_ratio: float = 3.5

var selected_province_id: String = ""
var attack_source_id: String = ""

# ==========================================
# 1. 게임 핵심 데이터 (9영지 및 장수)
# ==========================================

var legacy_provinces: Dictionary = {
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

var legacy_province_connections: Dictionary = {
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

var provinces: Dictionary = Korea35Data.get_province_templates()
var province_connections: Dictionary = Korea35Data.get_connections()

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

# 장기 전략 백엔드. 혼인·출산·교육·인재 보충·외교 관계를 담당합니다.
# samhan_strategy_systems.gd에 구현되어 있었으나 여태 아무 데서도
# 호출되지 않아 죽어 있었습니다.
var strategy: SamhanStrategySystems = SamhanStrategySystems.new()
var strategy_state: Dictionary = {}

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
@onready var province_panel: PanelContainer = $MainVBox/Content/ProvincePanel
@onready var navigation_menu: MenuButton = $MainVBox/TopBar/CampaignNavigationMenu

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
@onready var log_label: Label = $MainVBox/Content/ProvincePanel/ProvinceVBox/LogScroll/LogLabel

@onready var develop_button: Button = $MainVBox/Content/ProvincePanel/ProvinceVBox/DevelopButton
@onready var commerce_button: Button = $MainVBox/Content/ProvincePanel/ProvinceVBox/CommerceButton
@onready var recruit_button: Button = $MainVBox/Content/ProvincePanel/ProvinceVBox/RecruitButton
@onready var attack_button: Button = $MainVBox/Content/ProvincePanel/ProvinceVBox/AttackButton
@onready var transfer_button: Button = $MainVBox/Content/ProvincePanel/ProvinceVBox/TransferButton
@onready var close_detail_button: Button = (
	$MainVBox/Content/ProvincePanel/ProvinceVBox/CloseDetailButton
)

@onready var officer_list: ItemList = %OfficerList
@onready var officer_detail_label: Label = %OfficerDetailLabel
@onready var transfer_panel: Control = $ProvinceTransferPanel
@onready var governor_transfer_confirmation: ConfirmationDialog = $GovernorTransferConfirmation

var pending_governor_transfer: Dictionary = {}


func _ready() -> void:
	_apply_legacy_core_province_values()
	_apply_new_game_settings()
	_refresh_faction_controllers()
	_ensure_additional_officer_assignments()

	_bind_city_buttons()
	_connect_map_city_card()
	_connect_navigation_menu()
	_connect_button_once(
		officer_list.item_selected,
		_on_officer_list_item_selected
	)
	_connect_button_once(develop_button.pressed, _on_develop_button_pressed)
	_connect_button_once(commerce_button.pressed, _on_commerce_button_pressed)
	_connect_button_once(recruit_button.pressed, _on_recruit_button_pressed)
	_connect_button_once(attack_button.pressed, _on_attack_button_pressed)
	_connect_button_once(transfer_button.pressed, _on_transfer_button_pressed)
	_connect_button_once(close_detail_button.pressed, _hide_province_detail)
	_connect_button_once(
		transfer_panel.transfer_requested,
		request_province_transfer
	)
	_connect_button_once(
		governor_transfer_confirmation.confirmed,
		_on_governor_transfer_confirmed
	)
	_connect_button_once(
		governor_transfer_confirmation.canceled,
		_on_governor_transfer_canceled
	)
	_connect_button_once(end_turn_button.pressed, _on_end_turn_button_pressed)

	if save_button != null:
		_connect_button_once(save_button.pressed, _on_save_button_pressed)

	if load_button != null:
		_connect_button_once(load_button.pressed, _on_load_button_pressed)

	province_panel.visible = false

	update_top_bar()
	var starting_province_id: String = _get_starting_province_id()
	select_province(starting_province_id, false)
	map_area.call_deferred("focus_on_province", starting_province_id, 2.15)
	log_label.text = (
		"%s · %s 난이도로 시작합니다."
		% [
			PLAY_STYLE_NAMES.get(play_style, "역사적 게임플레이"),
			DIFFICULTY_NAMES.get(difficulty, "보통"),
		]
	)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if governor_transfer_confirmation.visible:
		return
	if transfer_panel.visible:
		transfer_panel.close_panel()
		get_viewport().set_input_as_handled()
		return
	if navigation_menu.get_popup().visible:
		return
	var confirmation_dialog: Window = navigation_menu.get_node_or_null(
		"ConfirmationDialog"
	) as Window
	if confirmation_dialog != null and confirmation_dialog.visible:
		return
	if province_panel.visible:
		_hide_province_detail()
		get_viewport().set_input_as_handled()


func _apply_legacy_core_province_values() -> void:
	# 기존 9개 핵심 도시의 경제·병력·장수 수치를 그대로 승계합니다.
	for province_id_value: Variant in legacy_provinces.keys():
		var province_id: String = str(province_id_value)
		if not provinces.has(province_id):
			continue
		provinces[province_id] = legacy_provinces[province_id].duplicate(true)


func _ensure_steppe_provinces(scenario_year: int) -> void:
	# 유목 9개 부족은 world_map_data.gd의 PROVINCE_TEMPLATES에 병력·목초지·
	# 복속도가 이미 정의되어 있는데 캠페인이 읽지 않고 있었습니다. 여기서
	# provinces에 편입해 실제 데이터로 쓰이게 합니다.
	var diplomacy: Dictionary = WorldMapData.get_steppe_diplomacy(scenario_year)

	for province_id: String in WorldMapData.STEPPE_PROVINCE_IDS:
		if not WorldMapData.PROVINCE_TEMPLATES.has(province_id):
			continue

		var template: Dictionary = (
			WorldMapData.PROVINCE_TEMPLATES[province_id].duplicate(true)
		)
		# 연도별 복속 상황을 덮어씁니다. 646년 이전엔 설연타 연맹권,
		# 647년부터 당 기미부주, 661~662년 철륵 반란으로 복속도가 급락합니다.
		if diplomacy.has(province_id):
			var entry: Dictionary = diplomacy[province_id]
			template["overlord"] = str(entry.get("overlord", ""))
			template["submission"] = int(entry.get("submission", 60))
			template["status"] = str(entry.get("status", ""))

		provinces[province_id] = template


func _apply_year_factions(scenario_year: int) -> void:
	_ensure_steppe_provinces(scenario_year)

	# 인구·장수 등 다른 값은 건드리지 않고 소속·병력·성벽만 갱신합니다.
	# provinces 전체를 대입하면 _apply_legacy_core_province_values()가
	# 먼저 승계해둔 9개 핵심 도시의 수치가 지워집니다.
	var year_factions: Dictionary = Korea35Data.get_factions_for_year(
		scenario_year
	)
	for province_id_value: Variant in year_factions.keys():
		var province_id: String = str(province_id_value)
		if not provinces.has(province_id):
			continue
		provinces[province_id]["faction"] = str(year_factions[province_id])


func _connect_button_once(signal_value: Signal, callable: Callable) -> void:
	if not signal_value.is_connected(callable):
		signal_value.connect(callable)


func _bind_city_buttons() -> void:
	var city_button_names: Dictionary = Korea35Data.get_city_button_names()

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


func _connect_map_city_card() -> void:
	_connect_button_once(
		map_area.city_card_domestic_requested,
		_on_city_card_domestic_requested
	)
	_connect_button_once(
		map_area.city_card_recruit_requested,
		_on_city_card_recruit_requested
	)
	_connect_button_once(
		map_area.city_card_sortie_requested,
		_on_city_card_sortie_requested
	)
	_connect_button_once(
		map_area.city_card_detail_requested,
		_on_city_card_detail_requested
	)


func _connect_navigation_menu() -> void:
	navigation_menu.connect("navigation_requested", _on_navigation_requested)
	navigation_menu.connect("quit_requested", _on_navigation_quit_requested)


func _on_navigation_requested(destination: String) -> void:
	attack_source_id = ""
	map_area.hide_city_card()
	province_panel.visible = false

	var root: Window = get_tree().root
	if root.has_meta("new_game_settings"):
		root.remove_meta("new_game_settings")

	var target_path: String = title_scene_path
	if destination == "setup":
		target_path = setup_scene_path

	var change_error: Error = get_tree().change_scene_to_file(target_path)
	if change_error != OK:
		log_label.text = "화면을 열 수 없습니다: %s" % target_path


func _on_navigation_quit_requested() -> void:
	get_tree().quit()


func _apply_new_game_settings() -> void:
	var root: Window = get_tree().root
	if not root.has_meta("new_game_settings"):
		return

	var settings_value: Variant = root.get_meta("new_game_settings")
	root.remove_meta("new_game_settings")

	if typeof(settings_value) != TYPE_DICTIONARY:
		return

	var settings: Dictionary = settings_value
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
		settings.get("scenario_id", "baekje_fall_660")
	)
	if ScenarioData.is_faction_playable_by_default(scenario_id, faction_id):
		player_faction_id = faction_id
		player_faction = ScenarioData.get_faction_name(scenario_id, faction_id)
	year = int(settings.get("scenario_year", 660))
	var season_id: String = str(settings.get("scenario_season", "spring"))
	season_index = int(SEASON_ID_TO_INDEX.get(season_id, 0))

	# 선택한 연도에 맞춰 소속 세력만 다시 배치합니다.
	# provinces 전체를 대입하면 _apply_legacy_core_province_values()가
	# 먼저 승계해둔 9개 핵심 도시의 인구·병력·장수 수치가 지워집니다.
	_apply_year_factions(year)
	_apply_scenario_rulers()

	_apply_difficulty_settings()

	# 전략 상태는 provinces·officers·season_index가 모두 확정된 뒤에
	# 만들어야 합니다.
	_init_strategy_state()


func _init_strategy_state() -> void:
	# provinces와 officers가 확정된 뒤에 만들어야 합니다. 세력 목록과
	# 수도를 이 자료에서 뽑아 쓰기 때문입니다.
	strategy_state = strategy.create_initial_state(
		year,
		provinces,
		officers,
		officers_by_province,
		_get_scenario_by_id(scenario_id),
		season_index
	)


func _apply_scenario_rulers() -> void:
	# legacy_provinces의 태수는 660년 기준으로 하드코딩되어 있어서, 632년을
	# 골라도 금성 태수가 김춘추로 나왔습니다. 시나리오마다 군주와 수도가
	# 정의되어 있으므로 그 값으로 수도의 태수를 덮어씁니다.
	var scenario: Dictionary = _get_scenario_by_id(scenario_id)
	if scenario.is_empty():
		return

	# 시나리오의 수도 이름(예: "금성")을 지역 id로 되찾기 위한 표입니다.
	var name_to_id: Dictionary = {}
	for province_id: String in Korea35Data.PROVINCE_IDS:
		if provinces.has(province_id):
			name_to_id[str(provinces[province_id].get("name", ""))] = province_id

	for faction_value: Variant in scenario.get("factions", []):
		if typeof(faction_value) != TYPE_DICTIONARY:
			continue
		var faction_data: Dictionary = faction_value
		var ruler: String = str(faction_data.get("ruler", ""))
		var capital: String = str(faction_data.get("capital", ""))
		if ruler == "" or capital == "":
			continue

		var capital_id: String = str(name_to_id.get(capital, ""))
		# "금성"과 "금성·월성"처럼 표기가 다를 수 있어 부분 일치도 봅니다.
		if capital_id == "":
			for province_name: String in name_to_id.keys():
				if province_name.begins_with(capital):
					capital_id = str(name_to_id[province_name])
					break
		if capital_id == "" or not provinces.has(capital_id):
			continue

		provinces[capital_id]["governor"] = ruler
		var province_generals: Array = provinces[capital_id].get("generals", [])
		if province_generals is Array and not province_generals.has(ruler):
			province_generals.insert(0, ruler)
			provinces[capital_id]["generals"] = province_generals


func _get_scenario_by_id(target_id: String) -> Dictionary:
	for scenario_value: Variant in ScenarioData.SCENARIOS:
		if typeof(scenario_value) != TYPE_DICTIONARY:
			continue
		var scenario: Dictionary = scenario_value
		if str(scenario.get("id", "")) == target_id:
			return scenario
	return {}


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
	var starting_province: String = ScenarioData.get_starting_province(
		scenario_id, player_faction_id
	)
	return starting_province if starting_province != "" else "geumseong"


func _refresh_faction_controllers() -> void:
	faction_controllers.clear()
	for faction_id: String in ScenarioData.get_active_faction_ids(scenario_id):
		var controller: String = CONTROLLER_INACTIVE
		if faction_id == player_faction_id:
			controller = CONTROLLER_PLAYER
		elif ScenarioData.is_faction_ai_enabled(scenario_id, faction_id):
			controller = CONTROLLER_AI
		faction_controllers[faction_id] = controller


func get_faction_controller(faction_id: String) -> String:
	return str(faction_controllers.get(faction_id, CONTROLLER_INACTIVE))


func select_province(province_id: String, show_floating_card: bool = true) -> void:
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
	transfer_button.disabled = not player_owned

	update_attack_button(province_id)
	update_province_log(province_id)
	if show_floating_card:
		map_area.show_city_card(
			province_id,
			province,
			{
				"domestic": player_owned,
				"recruit": player_owned,
				"sortie": not attack_button.disabled,
				"detail": true,
			}
		)


func _on_city_card_domestic_requested(province_id: String) -> void:
	if province_id != selected_province_id:
		select_province(province_id)
	_on_develop_button_pressed()


func _on_city_card_recruit_requested(province_id: String) -> void:
	if province_id != selected_province_id:
		select_province(province_id)
	_on_recruit_button_pressed()


func _on_city_card_sortie_requested(province_id: String) -> void:
	if province_id != selected_province_id:
		select_province(province_id)
	_on_attack_button_pressed()


func _on_city_card_detail_requested(province_id: String) -> void:
	var detail_was_visible: bool = province_panel.visible
	if province_id != selected_province_id:
		select_province(province_id)
	province_panel.visible = not detail_was_visible


func _hide_province_detail() -> void:
	province_panel.visible = false


func update_province_log(province_id: String) -> void:
	var province: Dictionary = provinces[province_id]
	var player_owned: bool = province["faction"] == player_faction

	if attack_source_id == "":
		if player_owned:
			log_label.text = (
				"명령을 내릴 수 있는 %s 영지입니다."
				% player_faction
			)
		else:
			log_label.text = "다른 세력의 영지에는 명령을 내릴 수 없습니다."
		return

	if province_id == attack_source_id:
		log_label.text = (
			"%s에서 공격을 준비하고 있습니다.\n인접한 적 영지를 선택하세요."
			% provinces[attack_source_id]["name"]
		)
		return

	if are_provinces_connected(attack_source_id, province_id) and not player_owned:
		log_label.text = (
			"%s에서 %s을 공격할 수 있습니다."
			% [provinces[attack_source_id]["name"], province["name"]]
		)
		return

	log_label.text = "공격할 수 없는 영지입니다."


func update_officer_list(province_id: String) -> void:
	officer_list.clear()
	officer_detail_label.text = "장수를 선택하세요."

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

	officer_detail_label.text = (
		"[%s]\n통솔: %d\n무력: %d\n지략: %d\n정치: %d\n권위: %d"
		% [
			officer["name"],
			officer["leadership"],
			officer["war"],
			officer["intelligence"],
			officer["politics"],
			officer["authority"],
		]
	)


func update_attack_button(province_id: String) -> void:
	if not provinces.has(province_id):
		attack_button.disabled = true
		return

	var province: Dictionary = provinces[province_id]
	var player_owned: bool = province["faction"] == player_faction

	if attack_source_id == "":
		attack_button.text = "공격 준비"
		attack_button.disabled = not player_owned or not has_enemy_neighbor(province_id)
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

		if int(selected_province["troops"]) < 3000:
			log_label.text = "공격하려면 최소 3,000명의 병력이 필요합니다."
			return

		attack_source_id = selected_province_id
		update_attack_button(selected_province_id)
		log_label.text = (
			"%s에서 공격을 준비합니다.\n인접한 적 영지를 선택하세요."
			% selected_province["name"]
		)
		return

	if selected_province_id == attack_source_id:
		attack_source_id = ""
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


func is_selected_province_player_owned() -> bool:
	if selected_province_id == "":
		return false

	if not provinces.has(selected_province_id):
		return false

	return provinces[selected_province_id]["faction"] == player_faction


func _on_transfer_button_pressed() -> void:
	if not is_selected_province_player_owned():
		log_label.text = "플레이어 소유 영지에서만 지원할 수 있습니다."
		return
	var source: Dictionary = provinces[selected_province_id]
	var destinations: Array[Dictionary] = []
	for neighbor_value: Variant in province_connections.get(selected_province_id, []):
		var neighbor_id: String = str(neighbor_value)
		if not provinces.has(neighbor_id):
			continue
		var neighbor: Dictionary = provinces[neighbor_id]
		if str(neighbor.get("faction", "")) != str(source.get("faction", "")):
			continue
		destinations.append(
			{"id": neighbor_id, "name": str(neighbor.get("name", neighbor_id))}
		)
	destinations.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return str(a.get("name", "")) < str(b.get("name", ""))
	)
	var available_officers: Array[String] = []
	for officer_value: Variant in officers_by_province.get(selected_province_id, []):
		available_officers.append(str(officer_value))
	transfer_panel.open_for_transfer(
		selected_province_id,
		str(source.get("name", selected_province_id)),
		destinations,
		int(source.get("troops", 0)),
		available_officers,
		str(source.get("governor", "")),
		false,
		false
	)


func validate_province_transfer(request: Dictionary) -> Dictionary:
	var source_id: String = str(request.get("source_id", ""))
	var target_id: String = str(request.get("target_id", ""))
	var troop_count: int = int(request.get("troops", 0))
	var food_count: int = int(request.get("food", 0))
	var gold_count: int = int(request.get("gold", 0))
	var requested_officers: Array[String] = []
	var seen_officers: Dictionary = {}
	var officer_values: Variant = request.get("officers", [])
	if typeof(officer_values) != TYPE_ARRAY:
		return {"ok": false, "reason": "장수 이동 요청 형식이 올바르지 않습니다."}
	for officer_value: Variant in officer_values:
		var officer_name: String = str(officer_value)
		if officer_name == "" or seen_officers.has(officer_name):
			return {"ok": false, "reason": "장수 이동 목록이 올바르지 않습니다."}
		seen_officers[officer_name] = true
		requested_officers.append(officer_name)

	if source_id == "" or target_id == "" or source_id == target_id:
		return {"ok": false, "reason": "출발 성과 목적지를 확인하세요."}
	if not provinces.has(source_id) or not provinces.has(target_id):
		return {"ok": false, "reason": "존재하지 않는 영지입니다."}
	var source: Dictionary = provinces[source_id]
	var target: Dictionary = provinces[target_id]
	if str(source.get("faction", "")) != player_faction:
		return {"ok": false, "reason": "플레이어 소유 영지에서만 지원할 수 있습니다."}
	if str(target.get("faction", "")) != str(source.get("faction", "")):
		return {"ok": false, "reason": "같은 세력의 영지로만 지원할 수 있습니다."}
	if not are_provinces_connected(source_id, target_id):
		return {"ok": false, "reason": "직접 연결된 영지로만 지원할 수 있습니다."}
	if troop_count < 0 or food_count < 0 or gold_count < 0:
		return {"ok": false, "reason": "이동 수량은 음수일 수 없습니다."}
	if food_count > 0 or gold_count > 0:
		return {"ok": false, "reason": "금과 군량은 현재 세력 공용 자원이므로 이동할 수 없습니다."}
	if troop_count > int(source.get("troops", 0)):
		return {"ok": false, "reason": "출발 영지의 보유 병력보다 많이 이동할 수 없습니다."}
	if troop_count == 0 and requested_officers.is_empty():
		return {"ok": false, "reason": "병력 또는 이동할 장수를 선택하세요."}

	var source_officers: Array = officers_by_province.get(source_id, [])
	for officer_name: String in requested_officers:
		if not source_officers.has(officer_name):
			return {"ok": false, "reason": "%s은(는) 출발 영지에 배치되어 있지 않습니다." % officer_name}

	var governor_name: String = str(source.get("governor", ""))
	return {
		"ok": true,
		"requires_governor_confirmation": (
			governor_name != ""
			and governor_name != "태수 없음"
			and requested_officers.has(governor_name)
		),
		"governor_name": governor_name,
	}


func request_province_transfer(request: Dictionary) -> void:
	var validation: Dictionary = validate_province_transfer(request)
	if not bool(validation.get("ok", false)):
		transfer_panel.show_error(str(validation.get("reason", "이동할 수 없습니다.")))
		return
	if bool(validation.get("requires_governor_confirmation", false)):
		pending_governor_transfer = request.duplicate(true)
		var source_id: String = str(request.get("source_id", ""))
		governor_transfer_confirmation.dialog_text = (
			"%s은(는) 현재 %s의 태수입니다. 이동하면 태수 자리가 공석이 됩니다. 이동하시겠습니까?"
			% [
				str(validation.get("governor_name", "")),
				str(provinces[source_id].get("name", source_id)),
			]
		)
		governor_transfer_confirmation.popup_centered(Vector2i(480, 170))
		return
	apply_province_transfer(request, false)


func apply_province_transfer(
	request: Dictionary, governor_transfer_confirmed: bool = false
) -> Dictionary:
	var validation: Dictionary = validate_province_transfer(request)
	if not bool(validation.get("ok", false)):
		return validation
	if (
		bool(validation.get("requires_governor_confirmation", false))
		and not governor_transfer_confirmed
	):
		return {"ok": false, "reason": "태수 이동 확인이 필요합니다."}

	var source_id: String = str(request.get("source_id", ""))
	var target_id: String = str(request.get("target_id", ""))
	var troop_count: int = int(request.get("troops", 0))
	var requested_officers: Array = request.get("officers", [])
	provinces[source_id]["troops"] = int(provinces[source_id]["troops"]) - troop_count
	provinces[target_id]["troops"] = int(provinces[target_id]["troops"]) + troop_count

	var source_officers: Array = officers_by_province.get(source_id, []).duplicate()
	var target_officers: Array = officers_by_province.get(target_id, []).duplicate()
	for officer_value: Variant in requested_officers:
		var officer_name: String = str(officer_value)
		source_officers.erase(officer_name)
		if not target_officers.has(officer_name):
			target_officers.append(officer_name)
	officers_by_province[source_id] = source_officers
	officers_by_province[target_id] = target_officers
	if bool(validation.get("requires_governor_confirmation", false)):
		provinces[source_id]["governor"] = "태수 없음"

	var parts: Array[String] = []
	if troop_count > 0:
		parts.append("병력 %d명" % troop_count)
	for officer_value: Variant in requested_officers:
		parts.append(str(officer_value))
	var message: String = "%s에서 %s로 %s을(를) 이동시켰습니다." % [
		str(provinces[source_id].get("name", source_id)),
		str(provinces[target_id].get("name", target_id)),
		", ".join(parts),
	]
	transfer_panel.close_panel()
	select_province(selected_province_id)
	log_label.text = message
	return {"ok": true, "message": message}


func _on_governor_transfer_confirmed() -> void:
	var request: Dictionary = pending_governor_transfer
	pending_governor_transfer = {}
	var result: Dictionary = apply_province_transfer(request, true)
	if not bool(result.get("ok", false)):
		transfer_panel.show_error(str(result.get("reason", "이동할 수 없습니다.")))


func _on_governor_transfer_canceled() -> void:
	pending_governor_transfer = {}


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


func resolve_attack(source_id: String, target_id: String) -> void:
	var attacker: Dictionary = provinces[source_id]
	var defender: Dictionary = provinces[target_id]
	var attacker_commander: Dictionary = get_best_commander(source_id)
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
	select_province(target_id)
	update_top_bar()
	log_label.text = result_message

	if player_controls_all_provinces():
		log_label.text += (
			"\n%s가 모든 영지를 통일했습니다!"
			% player_faction
		)


func player_controls_all_provinces() -> bool:
	# 통일 판정은 한반도 35개 지역만 봅니다. 유목 부족은 데이터로만
	# 편입되어 있고 정복 대상이 아니므로 제외합니다.
	for province_id: String in Korea35Data.PROVINCE_IDS:
		if not provinces.has(province_id):
			continue
		if str(provinces[province_id].get("faction", "")) != player_faction:
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

	# 건설·연구·교역과, 봄에는 인재 보충·혼인·출산·자녀 성장을 처리합니다.
	var strategy_message: String = _process_strategy_season()

	update_top_bar()

	if selected_province_id != "":
		select_province(selected_province_id)

	log_label.text = "계절이 지나 세금과 군량을 확보했습니다."

	if public_order_message != "":
		log_label.text += "\n" + public_order_message

	if ai_message != "":
		log_label.text += "\n" + ai_message

	if strategy_message != "":
		log_label.text += "\n" + strategy_message


func _process_strategy_season() -> String:
	if strategy_state.is_empty():
		return ""

	var result: Dictionary = strategy.process_season(
		strategy_state,
		year,
		season_index,
		provinces,
		officers_by_province,
		_get_scenario_by_id(scenario_id)
	)

	# 교역 수익은 플레이어 세력 몫만 반영합니다.
	var gold_delta: Dictionary = result.get("faction_gold_delta", {})
	if gold_delta.has(player_faction):
		gold = maxi(0, gold + int(gold_delta[player_faction]))

	var messages: Array = result.get("messages", [])
	if messages.is_empty():
		return ""
	return combine_messages(messages)


func process_public_order() -> String:
	var recovered_names: Array[String] = []

	# 치안 회복도 한반도 지역만 처리합니다.
	for province_id: String in Korea35Data.PROVINCE_IDS:
		if not provinces.has(province_id):
			continue
		var province: Dictionary = provinces[province_id]
		var previous_order: int = int(province["public_order"])

		if previous_order >= 100:
			continue

		var recovered_order: int = mini(100, previous_order + 5)
		province["public_order"] = recovered_order

		if province["faction"] == player_faction:
			recovered_names.append(str(province["name"]))

	# 지역이 35개로 늘어난 뒤로는 지역마다 한 줄씩 찍으면 로그가 넘칩니다.
	# 전투 같은 중요한 소식이 묻히므로 한 줄로 요약합니다.
	if recovered_names.is_empty():
		return ""
	if recovered_names.size() <= 3:
		return "치안 회복: %s" % ", ".join(recovered_names)
	return "치안 회복: %s 외 %d곳" % [
		", ".join(recovered_names.slice(0, 3)),
		recovered_names.size() - 3,
	]


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

	# 유목 부족은 여기서 제외합니다. 초원과 요동을 잇는 길은
	# STRATEGIC_ROUTES라서 여러 턴에 걸쳐 이동해야 하는데, 이 로직은
	# 한 턴에 인접지를 치는 방식이라 그대로 두면 순간이동이 됩니다.
	for province_id: String in Korea35Data.PROVINCE_IDS:
		if not provinces.has(province_id):
			continue
		if _get_province_controller(provinces[province_id]) == CONTROLLER_AI:
			ai_province_ids.append(province_id)

	var messages: Array[String] = []
	var recruit_counts: Dictionary = {}

	for source_id in ai_province_ids:
		if not provinces.has(source_id):
			continue

		var source: Dictionary = provinces[source_id]

		if _get_province_controller(source) != CONTROLLER_AI:
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

		# 충원은 지역마다 찍지 않고 세력별로 합산합니다.
		var faction_name: String = str(source["faction"])
		recruit_counts[faction_name] = (
			int(recruit_counts.get(faction_name, 0)) + 1
		)

	for faction_value: Variant in recruit_counts.keys():
		var faction_name: String = str(faction_value)
		var province_count: int = int(recruit_counts[faction_name])
		messages.append(
			"%s군이 %d곳에서 병력 %d명씩 충원했습니다."
			% [
				faction_name,
				province_count,
				ai_recruitment_amount,
			]
		)

	return combine_messages(messages)


func _get_province_controller(province: Dictionary) -> String:
	var faction_name: String = str(province.get("faction", ""))
	var faction_id: String = ScenarioData.get_faction_id_by_name(
		scenario_id, faction_name
	)
	return get_faction_controller(faction_id)


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
			if _get_province_controller(neighbor) != CONTROLLER_PLAYER:
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

	var defeat_attacker_losses: int = maxi(1000, int(float(attacker_troops) * 0.35))
	var defender_losses: int = maxi(500, int(float(attacker_troops) * 0.20))

	attacker["troops"] = maxi(1000, attacker_troops - defeat_attacker_losses)
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
		"save_version": 3,
		"year": year,
		"season_index": season_index,
		"gold": gold,
		"food": food,
		"player_faction": player_faction,
		"play_style": play_style,
		"difficulty": difficulty,
		"scenario_id": scenario_id,
		"selected_province_id": selected_province_id,
		"provinces": provinces,
		"officers_by_province": officers_by_province,
		"strategy_state": strategy_state,
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
	play_style = str(save_data.get("play_style", "historical"))
	difficulty = str(save_data.get("difficulty", "normal"))
	scenario_id = str(save_data.get("scenario_id", "baekje_fall_660"))

	if not FACTION_ID_TO_NAME.values().has(player_faction):
		player_faction = "신라"
	player_faction_id = ScenarioData.get_faction_id_by_name(
		scenario_id, player_faction
	)
	if player_faction_id == "":
		player_faction_id = "silla"
		player_faction = ScenarioData.get_faction_name(scenario_id, player_faction_id)
	_refresh_faction_controllers()

	if not PLAY_STYLE_NAMES.has(play_style):
		play_style = "historical"

	if not DIFFICULTY_NAMES.has(difficulty):
		difficulty = "normal"

	var saved_provinces: Dictionary = save_data["provinces"]
	provinces = saved_provinces.duplicate(true)

	# 전략 상태를 되살립니다. 옛 세이브에는 없으므로 그때는 새로 만듭니다.
	if typeof(save_data.get("strategy_state", null)) == TYPE_DICTIONARY:
		strategy_state = strategy.normalize_loaded_state(
			save_data["strategy_state"],
			provinces
		)
	else:
		strategy_state = {}

	if typeof(save_data.get("officers_by_province", null)) == TYPE_DICTIONARY:
		var saved_assignments: Dictionary = save_data["officers_by_province"]
		officers_by_province = saved_assignments.duplicate(true)

	_ensure_additional_officer_assignments()

	# 옛 세이브에는 전략 상태가 없습니다. officers_by_province가 복원된
	# 뒤에 만들어야 인재 배치가 제대로 잡힙니다.
	if strategy_state.is_empty():
		_init_strategy_state()

	attack_source_id = ""
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
	# 인재 등용 · 병력 충원 같은 자동 처리 메시지가 영지 수만큼(수십 개)
	# 한꺼번에 쏟아지면 LogLabel이 한없이 길어져서 레이아웃이 밀립니다.
	# 화면에는 앞부분 몇 개만 보여주고 나머지는 개수로 요약합니다.
	const MAX_VISIBLE_MESSAGES: int = 6

	var visible_count: int = mini(messages.size(), MAX_VISIBLE_MESSAGES)
	var combined_message: String = ""

	for index in range(visible_count):
		if combined_message != "":
			combined_message += "\n"
		combined_message += messages[index]

	var hidden_count: int = messages.size() - visible_count
	if hidden_count > 0:
		combined_message += "\n… 외 %d건" % hidden_count

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
