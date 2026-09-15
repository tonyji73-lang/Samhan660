extends Control
const Ending=preload("res://campaign_ending.gd")
var ending_dialog: AcceptDialog
var ending_load_dialog: FileDialog
var ending_save_dialog: FileDialog
var ending_busy: bool=false
var ending_save_message: String=""

const Economy = preload("res://faction_economy.gd")
const Army=preload("res://army_readiness.gd")
const Mobilization=preload("res://mobilization.gd")
const IronAI=preload("res://iron_procurement_ai.gd")
const MilitaryPlanning=preload("res://ai_military_planning.gd")
const ArmyOverlay=preload("res://army_readiness_overlay.gd")
var army_overlay: Control
var playability_dialog: AcceptDialog
var military_brief_details: RichTextLabel
const Playability=preload("res://campaign_playability.gd")
var politics_overlay: Control
const Noble=preload("res://noble_personnel.gd")
const Power=preload("res://noble_power_constraints.gd")
var power_dialog: AcceptDialog
var power_request_id: String=""
var power_successors: OptionButton
const PoliticsOverlay=preload("res://noble_politics_overlay.gd")
const Supply = preload("res://supply_transport.gd")
const SupplyOverlay = preload("res://supply_transport_overlay.gd")
var supply_overlay: Control
const Industry = preload("res://industry_assignment.gd")
const IndustryOverlay = preload("res://industry_assignment_overlay.gd")
var industry_overlay: Control
const Recruitment = preload("res://recruitment_system.gd")
const RecruitmentOverlay = preload("res://recruitment_overlay.gd")
var recruitment_overlay: Control

const Domestic = preload("res://domestic_assignment.gd")
const DomesticOverlay = preload("res://domestic_assignment_overlay.gd")
var domestic_overlay: Control

const OfficerRegistry = preload("res://officer_registry.gd")
const OfficerCatalog = preload("res://officer_catalog.gd")
const Korea35Data = preload("res://korea_35_data.gd")
const WorldMapData = preload("res://world_map_data.gd")
const ScenarioData = preload("res://scenario_data.gd")
const SamhanStrategySystems = preload("res://samhan_strategy_systems.gd")
const ProductionSystem = preload("res://production_system.gd")
const ProductionData = preload("res://production_data.gd")
const ProductionOverlay = preload("res://production_overlay.gd")
const DiplomacyOverlay = preload("res://diplomacy_overlay.gd")
const IronSupplyData = preload("res://iron_supply_data.gd")
const EventPresentation = preload("res://cutscenes/event_presentation.gd")
const BountifulHarvest = preload("res://bountiful_harvest.gd")
const CropFailure = preload("res://crop_failure.gd")

var crop_failure_events: Dictionary = {"version": 1, "years": {}, "pending": {}, "resolved": {}}

var harvest_events: Dictionary = {"version": 1, "years": {}}
var pending_harvest_presentation: Dictionary = {}

var event_presentation: CanvasLayer
var pending_campaign_opening: bool = false
# Dependency supplied only by isolated tests; never loaded from campaign saves.
var iron_supply_rules: Dictionary = IronSupplyData.SCENARIOS

const SAVE_PATH: String = "user://campaign_save_35_regions_v1.json"
const SEASONS: Array[String] = ["봄", "여름", "가을", "겨울"]
const MONTHS_PER_YEAR: int = 12
const MONTHS_PER_SEASON: int = 3
const SEASON_START_MONTH_BY_ID: Dictionary = {
	"spring": 1,
	"summer": 4,
	"autumn": 7,
	"winter": 10,
}
const FOOD_COLLECTION_RATE: float = 0.45
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

var year: int = 660
var month: int = 1
var season_index: int = 0
var _legacy_start_gold: int = 1000
var gold: int:
	get:
		return Economy.balance(strategy_state,player_faction_id) if strategy_state.has("faction_economy") else _legacy_start_gold
	set(value):
		if strategy_state.has("faction_economy"):
			Economy.post(strategy_state,player_faction_id,value-gold,"compatibility",year*12+month)
		else: _legacy_start_gold=value
var food: int = 3000

var player_faction: String = "신라"
var player_faction_id: String = "silla"
var faction_controllers: Dictionary = {}
var play_style: String = "historical"
var difficulty: String = "normal"
# Campaign start identity: advancing the calendar must never change this ID.
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

var officer_registry: Dictionary:
	get:
		return strategy_state.get("officer_registry", {})

# Read-only name projections for old callers; runtime writes use officer_id APIs.
var officers: Dictionary:
	get:
		return OfficerRegistry.name_view(officer_registry)

# 장기 전략 백엔드. 혼인·출산·교육·인재 보충·외교 관계를 담당합니다.
# samhan_strategy_systems.gd에 구현되어 있었으나 여태 아무 데서도
# 호출되지 않아 죽어 있었습니다.
var strategy: SamhanStrategySystems = SamhanStrategySystems.new()
var strategy_state: Dictionary = {}
var production_overlay: Control
var diplomacy_overlay: Control
var diplomacy_saved_turn_disabled: bool = false

var officers_by_province: Dictionary:
	get:
		return OfficerRegistry.assignments(officer_registry, true)

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
@onready var food_stock_label: Label = %FoodStockLabel
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
@onready var appoint_governor_button: Button = %AppointGovernorButton
@onready var transfer_panel: Control = $ProvinceTransferPanel
@onready var governor_transfer_confirmation: ConfirmationDialog = $GovernorTransferConfirmation
@onready var governor_appointment_confirmation: ConfirmationDialog = $GovernorAppointmentConfirmation

var pending_governor_transfer: Dictionary = {}
var pending_governor_appointment: Dictionary = {}
var pending_transfer_orders: Array[Dictionary] = []


func _ready() -> void:
	_ending_initialize.call_deferred()
	pending_campaign_opening = get_tree().root.has_meta("new_game_settings")
	_apply_legacy_core_province_values()
	_apply_new_game_settings()
	_refresh_faction_controllers()
	_ensure_province_food_economy()
	_ensure_additional_officer_assignments()
	# F6로 캠페인 씬을 직접 실행해도 생산/연구/건설 상태를 준비합니다.
	if strategy_state.is_empty():
		_init_strategy_state()

	_bind_city_buttons()
	_connect_map_city_card()
	var production_layer := CanvasLayer.new()
	production_layer.name = "ProductionLayer"
	production_layer.layer = 100
	add_child(production_layer)
	production_overlay = ProductionOverlay.new()
	production_overlay.name = "ProductionOverlay"
	production_layer.add_child(production_overlay)
	diplomacy_overlay = DiplomacyOverlay.new()
	diplomacy_overlay.name = "DiplomacyOverlay"
	production_layer.add_child(diplomacy_overlay)
	domestic_overlay=DomesticOverlay.new()
	production_layer.add_child(domestic_overlay)
	domestic_overlay.visibility_changed.connect(_sync_modal_map_input)
	recruitment_overlay=RecruitmentOverlay.new()
	production_layer.add_child(recruitment_overlay)
	recruitment_overlay.visibility_changed.connect(_sync_modal_map_input)
	army_overlay=ArmyOverlay.new(); production_layer.add_child(army_overlay); army_overlay.visibility_changed.connect(_sync_modal_map_input)
	politics_overlay=PoliticsOverlay.new(); production_layer.add_child(politics_overlay); politics_overlay.visibility_changed.connect(_sync_modal_map_input)
	playability_dialog=AcceptDialog.new(); add_child(playability_dialog); playability_dialog.title="캠페인 목표·전쟁 준비·현재 지원 범위"; playability_dialog.dialog_autowrap=true; playability_dialog.visibility_changed.connect(_sync_modal_map_input)
	navigation_menu.get_popup().add_item("캠페인 목표·전쟁 준비",6)
	navigation_menu.get_popup().add_item("국가별 AI 군수 계획",7)
	navigation_menu.get_popup().add_item("귀족·군권·인사정치",5)
	navigation_menu.get_popup().id_pressed.connect(func(id):
		if id==5 and not event_presentation.active: open_politics()
		if id==6 and not event_presentation.active: open_campaign_brief()
		if id==7 and not event_presentation.active: open_ai_military_brief())
	recruitment_overlay.army_requested.connect(open_army)
	supply_overlay=SupplyOverlay.new()
	production_layer.add_child(supply_overlay)
	supply_overlay.visibility_changed.connect(_sync_modal_map_input)
	transfer_panel.cargo_requested.connect(open_supply)
	industry_overlay=IndustryOverlay.new()
	production_layer.add_child(industry_overlay)
	industry_overlay.visibility_changed.connect(_sync_modal_map_input)
	diplomacy_overlay.closed.connect(_close_diplomacy)
	production_overlay.visibility_changed.connect(_sync_modal_map_input)
	diplomacy_overlay.visibility_changed.connect(_sync_modal_map_input)
	_connect_navigation_menu()
	event_presentation = EventPresentation.new()
	add_child(event_presentation)
	event_presentation.setup(self)
	_connect_button_once(
		officer_list.item_selected,
		_on_officer_list_item_selected
	)
	_connect_button_once(
		appoint_governor_button.pressed,
		_on_appoint_governor_button_pressed
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
	_connect_button_once(
		governor_appointment_confirmation.confirmed,
		_on_governor_appointment_confirmed
	)
	_connect_button_once(
		governor_appointment_confirmation.canceled,
		_on_governor_appointment_canceled
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
	_present_campaign_opening.call_deferred()


func _present_campaign_opening() -> void:
	if not pending_campaign_opening:
		return
	pending_campaign_opening = false
	event_presentation.dispatch({
		"scenario_year": int(_get_scenario_by_id(scenario_id).get("year", 0)),
		"player_faction": player_faction_id,
	})


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and army_overlay!=null and army_overlay.visible:
		army_overlay.hide(); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("ui_cancel") and supply_overlay!=null and supply_overlay.visible:
		supply_overlay.hide(); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("ui_cancel") and industry_overlay!=null and industry_overlay.visible:
		industry_overlay.hide(); get_viewport().set_input_as_handled(); return
	if event.is_action_pressed("ui_cancel") and recruitment_overlay!=null and recruitment_overlay.visible:
		recruitment_overlay.hide()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") and domestic_overlay!=null and domestic_overlay.visible:
		domestic_overlay.hide()
		get_viewport().set_input_as_handled()
		return
	if event_presentation != null and event_presentation.active:
		if event.is_action_pressed("ui_cancel"):
			if not event_presentation.menu_open():
				event_presentation.open_menu()
				get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if diplomacy_overlay != null and diplomacy_overlay.visible:
		if diplomacy_overlay.confirmation.visible:
			return
		_close_diplomacy()
		get_viewport().set_input_as_handled()
		return
	if production_overlay != null and production_overlay.visible:
		production_overlay.hide()
		get_viewport().set_input_as_handled()
		return
	if governor_transfer_confirmation.visible:
		return
	if governor_appointment_confirmation.visible:
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


func _ensure_province_food_economy(legacy_player_food: int = -1) -> void:
	for province_id: String in Korea35Data.PROVINCE_IDS:
		if not provinces.has(province_id):
			continue
		var province: Dictionary = provinces[province_id]
		var population_in_thousands: float = (
			float(maxi(0, int(province.get("population", 0)))) / 1000.0
		)
		var agriculture: int = clampi(int(province.get("agriculture", 0)), 0, 100)
		if not province.has("granary_capacity"):
			province["granary_capacity"] = roundi(
				3000.0
				+ population_in_thousands * 30.0
				+ float(agriculture) * 30.0
			)
		if not province.has("food_stock"):
			if province.has("food"):
				province["food_stock"] = maxi(0, int(province["food"]))
			else:
				province["food_stock"] = roundi(
					float(int(province["granary_capacity"])) * 0.60
				)
		province["granary_capacity"] = maxi(0, int(province["granary_capacity"]))
		province["food_stock"] = maxi(0, int(province["food_stock"]))
		if not province.has("food_shortage"):
			province["food_shortage"] = false
		if not province.has("food_shortage_amount"):
			province["food_shortage_amount"] = 0

	if legacy_player_food >= 0:
		var starting_province_id: String = _get_starting_province_id()
		if provinces.has(starting_province_id):
			provinces[starting_province_id]["food_stock"] = legacy_player_food
	food = _get_total_player_food_stock()


func _get_total_player_food_stock() -> int:
	var total: int = 0
	for province_id: String in Korea35Data.PROVINCE_IDS:
		if not provinces.has(province_id):
			continue
		if _get_province_controller(provinces[province_id]) != CONTROLLER_PLAYER:
			continue
		total += int(provinces[province_id].get("food_stock", 0))
	return total


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
	_connect_button_once(map_area.city_card_production_requested, _on_city_card_production_requested)
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
		map_area.city_card_move_requested,
		_on_city_card_move_requested
	)
	_connect_button_once(
		map_area.city_card_detail_requested,
		_on_city_card_detail_requested
	)


func _connect_navigation_menu() -> void:
	navigation_menu.connect("diplomacy_requested", _open_diplomacy)
	navigation_menu.connect("navigation_requested", _on_navigation_requested)
	navigation_menu.connect("quit_requested", _on_navigation_quit_requested)


func _open_diplomacy() -> void:
	if domestic_overlay!=null: domestic_overlay.hide()
	if recruitment_overlay!=null: recruitment_overlay.hide()
	if army_overlay!=null: army_overlay.hide()
	if politics_overlay!=null: politics_overlay.hide()
	if power_dialog!=null: power_dialog.hide()
	if playability_dialog!=null: playability_dialog.hide()
	if supply_overlay!=null: supply_overlay.hide()
	if industry_overlay!=null: industry_overlay.hide()
	if event_presentation != null and event_presentation.active:
		return
	if diplomacy_overlay.visible:
		return
	production_overlay.hide()
	transfer_panel.close_panel()
	map_area.hide_city_card()
	map_area.map_dragging = false
	province_panel.hide()
	diplomacy_saved_turn_disabled = end_turn_button.disabled
	end_turn_button.disabled = true
	diplomacy_overlay.open_for_campaign(self)


func _sync_modal_map_input() -> void:
	map_area.modal_input_locked = (power_dialog!=null and power_dialog.visible) or Ending.finished(strategy_state) or (ending_load_dialog!=null and ending_load_dialog.visible) or (ending_save_dialog!=null and ending_save_dialog.visible) or production_overlay.visible or diplomacy_overlay.visible or (domestic_overlay!=null and domestic_overlay.visible) or (recruitment_overlay!=null and recruitment_overlay.visible) or (industry_overlay!=null and industry_overlay.visible) or (supply_overlay!=null and supply_overlay.visible) or (army_overlay!=null and army_overlay.visible) or (politics_overlay!=null and politics_overlay.visible) or (playability_dialog!=null and playability_dialog.visible)
	if map_area.modal_input_locked:
		map_area.map_dragging = false


func _close_diplomacy() -> void:
	if diplomacy_overlay == null or not diplomacy_overlay.visible:
		return
	diplomacy_overlay.confirmation.hide()
	diplomacy_overlay.hide()
	end_turn_button.disabled = diplomacy_saved_turn_disabled


func get_diplomacy_factions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	# Prepared scenario order and the existing controller policy are authoritative.
	for id: String in ScenarioData.get_active_faction_ids(scenario_id):
		if get_faction_controller(id) == CONTROLLER_INACTIVE:
			continue
		result.append({"id": id, "name": ScenarioData.get_faction_name(scenario_id, id)})
	return result


func get_diplomacy_envoys() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in officer_registry.get("people", {}):
		var checked: Dictionary = strategy.get_diplomatic_envoy(strategy_state, player_faction, id, provinces, {}, {})
		if checked.ok: result.append(checked.envoy)
	return result


func get_diplomatic_action_quote(target_id: String, action_id: String, envoy_name: String) -> Dictionary:
	var names: Array[String] = []
	var target: String = ""
	for faction: Dictionary in get_diplomacy_factions():
		names.append(str(faction.name))
		if faction.id == target_id:
			target = str(faction.name)
	return strategy.get_diplomatic_action_quote(strategy_state, player_faction, target, action_id,
		{"name": envoy_name}, year, month, gold, provinces, officers, officers_by_province, names)


func request_diplomatic_action(target_id: String, action_id: String, envoy_name: String) -> Dictionary:
	if Ending.finished(strategy_state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	if event_presentation != null and event_presentation.active:
		return {"ok": false, "executed": false, "reason": "사건 처리를 마친 뒤 외교할 수 있습니다."}
	if not action_id in ["gift", "trade_pact", "cancel_trade_pact"]:
		return {"ok": false, "executed": false, "reason": "지원하지 않는 외교 행동입니다."}
	var quote: Dictionary=get_diplomatic_action_quote(target_id,action_id,envoy_name)
	var budget: Dictionary=Economy.validate_national(strategy_state,player_faction_id,player_faction_id,int(quote.get("gold_cost",0)))
	if not budget.ok:
		budget["executed"]=false
		return budget
	var names: Array[String] = []
	var target: String = ""
	for faction: Dictionary in get_diplomacy_factions():
		names.append(str(faction.name))
		if faction.id == target_id:
			target = str(faction.name)
	var result: Dictionary = strategy.perform_diplomatic_action(strategy_state, player_faction, target,
		action_id, {"name": envoy_name}, year, month, gold, provinces, officers, officers_by_province, names)
	if result.get("executed", false):
		Economy.post(strategy_state,player_faction_id,-int(result.get("gold_cost",0)),"diplomacy:"+action_id,year*12+month)
	update_top_bar()
	log_label.text = str(result.get("message", result.get("reason", "")))
	return result


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
	month = int(SEASON_START_MONTH_BY_ID.get(season_id, 1))
	_sync_season_from_month()

	# 선택한 연도에 맞춰 소속 세력만 다시 배치합니다.
	# provinces 전체를 대입하면 _apply_legacy_core_province_values()가
	# 먼저 승계해둔 9개 핵심 도시의 인구·병력·장수 수치가 지워집니다.
	_apply_year_factions(year)
	_apply_scenario_rulers()

	_apply_difficulty_settings()

	# 전략 상태는 provinces·officers·season_index가 모두 확정된 뒤에
	# 만들어야 합니다.
	_init_strategy_state()
	# Only the new-game settings path grants scenario starting technology.
	# _init_strategy_state() is also used by legacy loads and must not grant it.
	IronSupplyData.apply_new_game_technologies(strategy_state, scenario_id)


func _init_strategy_state(apply_start_relations: bool = true) -> void:
	# provinces와 officers가 확정된 뒤에 만들어야 합니다. 세력 목록과
	# 수도를 이 자료에서 뽑아 쓰기 때문입니다.
	strategy_state = strategy.create_initial_state(
		year,
		provinces,
		{},
		{},
		_get_scenario_by_id(scenario_id),
		season_index,
		apply_start_relations
	)
	if apply_start_relations:
		strategy_state["officer_registry"] = OfficerRegistry.new_game(scenario_id, provinces)
		officer_registry["clock_month"]=year*12+month
		officer_registry["post_history"]=[]
		for post: String in officer_registry.posts:
			if post.begins_with("governor:"):
				var id: String=officer_registry.posts[post]
				officer_registry.post_history.append({"post":post,"city_id":post.trim_prefix("governor:"),"officer_id":id,"previous_id":"","new_id":id,"month":year*12+month,"reason":"초기 태수 배치"})
		Domestic.ensure(strategy_state)
		Economy.initialize(strategy_state,_get_scenario_by_id(scenario_id),player_faction_id,_legacy_start_gold)
		Army.initialize(strategy_state,provinces,pending_transfer_orders,strategy.RECRUIT_UNIT_DEFS.merged(strategy.SPECIAL_UNIT_DEFS))
		Mobilization.initialize(strategy_state,provinces)
		OfficerRegistry.Politics.initialize(officer_registry,scenario_id,year*12+month)
		Supply.ensure(strategy_state)
		Industry.normalize(strategy_state,provinces,strategy,year*12+month)
		OfficerRegistry.bind_dynasty(strategy_state)
		_sync_officer_labels()


func _apply_scenario_rulers() -> void:
	# Initial rulers and governors are installed together by OfficerRegistry.
	pass


func _get_scenario_by_id(target_id: String) -> Dictionary:
	return ScenarioData.get_scenario(target_id)


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
	if diplomacy_overlay != null and diplomacy_overlay.visible:
		return
	if event_presentation != null and event_presentation.active:
		return
	if not provinces.has(province_id):
		return

	selected_province_id = province_id
	var province: Dictionary = provinces[province_id]

	province_name_label.text = province["name"]
	faction_label.text = "세력: %s" % province["faction"]
	governor_label.text = "태수: %s" % province["governor"]
	population_label.text = "민간 인구: %d" % province["population"]
	agriculture_label.text = "농업: %d" % province["agriculture"]
	commerce_label.text = "상업: %d" % province["commerce"]
	public_order_label.text = "치안: %d" % province["public_order"]
	troops_label.text = "병력: %d" % province["troops"]
	food_stock_label.text = "군량: %d / %d" % [
		int(province.get("food_stock", 0)),
		int(province.get("granary_capacity", 0)),
	]
	fortress_label.text = "성벽: %d" % province["fortress"]

	update_officer_list(province_id)

	var player_owned: bool = province["faction"] == player_faction and not Ending.finished(strategy_state)
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
				"production": player_owned,
				"recruit": player_owned,
				"sortie": not attack_button.disabled,
				"move": player_owned,
				"detail": true,
			}
		)


func _on_city_card_domestic_requested(province_id: String) -> void:
	if province_id != selected_province_id:
		select_province(province_id)
	_on_develop_button_pressed()


func _on_city_card_production_requested(province_id: String) -> void:
	if domestic_overlay!=null: domestic_overlay.hide()
	if recruitment_overlay!=null: recruitment_overlay.hide()
	if army_overlay!=null: army_overlay.hide()
	if politics_overlay!=null: politics_overlay.hide()
	if power_dialog!=null: power_dialog.hide()
	if playability_dialog!=null: playability_dialog.hide()
	if supply_overlay!=null: supply_overlay.hide()
	if industry_overlay!=null: industry_overlay.hide()
	if event_presentation != null and event_presentation.active:
		return
	if ProductionSystem.ownership_reason(provinces, province_id, player_faction) != "":
		return
	_close_diplomacy()
	map_area.hide_city_card()
	province_panel.hide()
	production_overlay.call("open_for_province", self, province_id)


func get_production_view_model(province_id: String, recipe_id: String) -> Dictionary:
	if not provinces.has(province_id) or not ProductionData.recipe_is_enabled(recipe_id):
		return {}
	var recipe: Dictionary = ProductionData.RECIPES[recipe_id]
	var owned: bool = ProductionSystem.ownership_reason(provinces, province_id, player_faction) == ""
	var faction: String = str(provinces[province_id].get("faction", ""))
	var order: Dictionary = strategy_state.get("city_production", {}).get(province_id, {}).get(recipe_id, {})
	var validation: Dictionary = ProductionSystem.validate_batch(strategy_state, provinces, province_id, recipe_id, player_faction, gold, scenario_id, iron_supply_rules)
	var regional_reason: String = IronSupplyData.blocked_reason(scenario_id, province_id, iron_supply_rules) if bool(recipe.get("regional_supply", false)) else ""
	var research_options: Array[Dictionary] = _production_requirement_options(province_id, faction, recipe["research"], true, owned)
	var building_options: Array[Dictionary] = _production_requirement_options(province_id, faction, recipe["buildings"], false, owned)
	var research_status: Array[String] = []
	var building_status: Array[String] = []
	var can_research: bool = false
	var can_build: bool = false
	for option: Dictionary in research_options:
		research_status.append(option["status"])
		can_research = can_research or bool(option["can_execute"])
	for option: Dictionary in building_options:
		building_status.append(option["status"])
		can_build = can_build or bool(option["can_execute"])
	var reservations: Array[String] = []
	for id: String in ProductionData.RECIPE_ORDER:
		var reservation: Dictionary = strategy_state.get("city_production", {}).get(province_id, {}).get(id, {})
		reservations.append("%s: %s" % [ProductionData.RECIPES[id]["name"], "예약" if bool(reservation.get("enabled", false)) else "중지"])
	return {
		"name": provinces[province_id]["name"], "year": year, "month": month, "gold": gold, "owned": owned,
		"inventory": ProductionSystem.get_inventory_view(strategy_state, provinces, province_id),
		"enabled": bool(order.get("enabled", false)), "status": order.get("status", "중지"),
		"last_reason": _production_reason_text(str(order.get("reason", ""))),
		"reason": _production_reason_text(str(validation.get("reason", ""))),
		"research_status": "\n".join(research_status), "building_status": "\n".join(building_status),
		"research_options": research_options, "building_options": building_options,
		"can_research": can_research, "can_build": can_build,
		"can_start": owned and regional_reason.is_empty(), "regional_reason": regional_reason,
		"evidence": IronSupplyData.evidence_text(province_id), "reservations": " / ".join(reservations),
		"supply_notice": IronSupplyData.placement_text(scenario_id, province_id, iron_supply_rules),
	}


func _production_requirement_options(province_id: String, faction: String, requirements: Dictionary, is_research: bool, owned: bool) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var definitions: Dictionary = SamhanStrategySystems.RESEARCH_DEFS if is_research else SamhanStrategySystems.BUILDING_DEFS
	var levels: Dictionary = strategy_state.get("faction_research", {}).get(faction, {}) if is_research else strategy_state.get("province_buildings", {}).get(province_id, {})
	var queue: Dictionary = strategy_state.get("research_queues", {}).get(faction, {}) if is_research else strategy_state.get("construction_queues", {}).get(province_id, {})
	for requirement_id: String in requirements:
		var name_text: String = str(definitions[requirement_id]["name"])
		var level: int = int(levels.get(requirement_id, 0))
		var complete: bool = level >= int(requirements[requirement_id])
		var queue_id_key: String = "research_id" if is_research else "building_id"
		var queue_text: String = _production_queue_text(queue) if str(queue.get(queue_id_key, "")) == requirement_id else ""
		var quote: Dictionary = strategy.get_research_quote(strategy_state, faction, requirement_id) if is_research else strategy.get_building_quote(strategy_state, province_id, requirement_id, scenario_id, iron_supply_rules)
		options.append({
			"id": requirement_id,
			"status": "%s %d / 필요 %d단계%s" % [name_text, level, requirements[requirement_id], queue_text],
			"label": _production_quote_text(name_text + (" 연구" if is_research else " 건설"), quote, complete),
			"can_execute": owned and not complete and ((bool(quote.get("ok", false)) and gold >= int(quote.get("gold_cost", 0))) or queue.has("industry_job_id")),
		})
	return options


func _production_reason_text(reason: String) -> String:
	for id: String in SamhanStrategySystems.RESEARCH_DEFS:
		reason = reason.replace(id, str(SamhanStrategySystems.RESEARCH_DEFS[id]["name"]))
	for id: String in SamhanStrategySystems.BUILDING_DEFS:
		reason = reason.replace(id, str(SamhanStrategySystems.BUILDING_DEFS[id]["name"]))
	return reason


func _production_queue_text(queue: Dictionary) -> String:
	if queue.has("industry_job_id"):
		var job: Dictionary=Industry.jobs(strategy_state).get(queue.industry_job_id,{})
		return "진행 중인 업무 · %d/%d · %s" % [job.get("progress",0),job.get("required",0),job.get("reason","")]
	return " · 진행 중인 명령: 남은 계절 정산 %d회" % int(queue.get("remaining_turns", 0)) if not queue.is_empty() else ""


func _production_quote_text(label: String, quote: Dictionary, complete: bool) -> String:
	if complete:
		return label + " — 요구 단계 충족"
	if not bool(quote.get("ok", false)):
		return label + " — " + str(quote.get("reason", "진행 불가"))
	return "%s 시작 · 금 %d · 기준 %d개월 · 담당자 선택%s" % [label, quote["gold_cost"], int(quote["turns"])*3, " · 금 부족" if gold < int(quote["gold_cost"]) else ""]


func request_production_command(province_id: String, recipe_id: String, action: String, requirement_id: String = "", officer_id: String = "") -> Dictionary:
	var authority: Dictionary=Economy.validate(strategy_state,provinces,player_faction_id,player_faction_id,province_id)
	if not authority.ok: return authority
	var reason: String = ProductionSystem.ownership_reason(provinces, province_id, player_faction)
	if reason != "":
		return {"ok": false, "reason": reason}
	if not ProductionData.recipe_is_enabled(recipe_id):
		return {"ok": false, "reason": "알 수 없는 생산법입니다."}
	if action in ["start", "stop"]:
		return ProductionSystem.set_enabled(strategy_state, provinces, province_id, recipe_id, player_faction, action == "start", scenario_id, iron_supply_rules)
	if action not in ["research", "build"]:
		return {"ok": false, "reason": "알 수 없는 생산 명령입니다."}
	var recipe: Dictionary = ProductionData.RECIPES[recipe_id]
	var is_research: bool = action == "research"
	var requirements: Dictionary = recipe["research"] if is_research else recipe["buildings"]
	var levels: Dictionary = strategy_state.get("faction_research", {}).get(player_faction, {}) if is_research else strategy_state.get("province_buildings", {}).get(province_id, {})
	if requirement_id.is_empty():
		for id: String in requirements:
			if int(levels.get(id, 0)) < int(requirements[id]):
				requirement_id = id
				break
	if not requirements.has(requirement_id):
		return {"ok": false, "reason": "필요 조건이 아니거나 이미 모든 요구 단계를 충족했습니다."}
	if int(levels.get(requirement_id, 0)) >= int(requirements[requirement_id]):
		return {"ok": false, "reason": "이미 생산에 필요한 단계를 충족했습니다."}
	var quote: Dictionary = strategy.get_research_quote(strategy_state, player_faction, requirement_id) if is_research else strategy.get_building_quote(strategy_state, province_id, requirement_id, scenario_id, iron_supply_rules)
	if not bool(quote.get("ok", false)):
		return quote
	var budget: Dictionary=Economy.validate(strategy_state,provinces,player_faction_id,player_faction_id,province_id,int(quote.gold_cost))
	if not budget.ok: return budget
	var result: Dictionary=Industry.start(strategy_state,provinces,strategy,player_faction_id,province_id,action,requirement_id,officer_id,year*12+month,scenario_id,iron_supply_rules)
	update_top_bar()
	return result

func open_industry(city: String, kind: String, requirement: String = "") -> void:
	if event_presentation!=null and event_presentation.active: return
	if not Economy.validate(strategy_state,provinces,player_faction_id,player_faction_id,city).ok: return
	supply_overlay.hide(); domestic_overlay.hide(); recruitment_overlay.hide(); production_overlay.hide(); _close_diplomacy(); transfer_panel.close_panel()
	industry_overlay.open(self,city,kind,requirement)


func _on_city_card_recruit_requested(province_id: String) -> void:
	if province_id != selected_province_id:
		select_province(province_id)
	_on_recruit_button_pressed()


func _on_city_card_sortie_requested(province_id: String) -> void:
	if province_id != selected_province_id:
		select_province(province_id)
	_on_attack_button_pressed()


func _on_city_card_move_requested(province_id: String) -> void:
	if province_id != selected_province_id:
		select_province(province_id)
	_on_transfer_button_pressed()


func _on_city_card_detail_requested(province_id: String) -> void:
	var detail_was_visible: bool = province_panel.visible
	if province_id != selected_province_id:
		select_province(province_id)
	province_panel.visible = not detail_was_visible


func _hide_province_detail() -> void:
	province_panel.visible = false


func update_province_log(province_id: String) -> void:
	var province: Dictionary = provinces[province_id]
	var player_owned: bool = province["faction"] == player_faction and not Ending.finished(strategy_state)

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
	appoint_governor_button.disabled = true
	appoint_governor_button.tooltip_text = "임명할 장수를 선택하세요."
	for id: String in get_city_officer_ids(province_id):
		var officer: Dictionary = get_officer(id)
		officer_list.add_item(str(officer.name))
		officer_list.set_item_metadata(officer_list.item_count - 1, id)


func _on_officer_list_item_selected(index: int) -> void:
	if selected_province_id == "":
		return

	if index < 0 or index >= officer_list.item_count:
		return

	var officer_name: String = str(officer_list.get_item_metadata(index))

	if get_officer(officer_name).is_empty():
		return

	var officer: Dictionary = get_officer(officer_name)

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
	var validation: Dictionary = validate_governor_appointment(
		selected_province_id,
		officer_name
	)
	appoint_governor_button.disabled = not bool(validation.get("ok", false))
	appoint_governor_button.tooltip_text = str(
		validation.get("reason", "선택한 장수를 이 성의 태수로 임명합니다.")
	)


func validate_governor_appointment(province_id: String, reference: String) -> Dictionary:
	if Ending.finished(strategy_state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	if not provinces.has(province_id):
		return {"ok": false, "reason": "존재하지 않는 영지입니다."}
	if provinces[province_id].faction != player_faction:
		return {"ok": false, "reason": "플레이어 소유 영지에서만 태수를 임명할 수 있습니다."}
	var id: String = OfficerRegistry.resolve(officer_registry, reference)
	if id.is_empty() or not OfficerRegistry.eligible(officer_registry, id, provinces, province_id):
		return {"ok": false, "reason": "이 성에 배치된 같은 세력의 활동 장수만 임명할 수 있습니다."}
	if get_governor_id(province_id) == id:
		return {"ok": false, "reason": "이미 이 성의 태수입니다."}
	var old: Dictionary = get_officer(get_governor_id(province_id))
	return {"ok": true, "officer_id": id, "current_governor": old.get("name", "태수 없음"), "requires_confirmation": not old.is_empty()}


func _find_assigned_officer_province(reference: String) -> String:
	var p: Dictionary = OfficerRegistry.get_person(officer_registry, reference)
	return "" if p.is_empty() or p.get("in_transit", false) else str(p.location)


func _get_officer_faction(reference: String) -> String:
	return OfficerRegistry.faction_name(officer_registry, OfficerRegistry.get_person(officer_registry, reference))


func _is_vacant_governor(governor_name: String) -> bool:
	return (
		governor_name == ""
		or governor_name == "태수 없음"
		or governor_name == "수비대장"
	)


func _on_appoint_governor_button_pressed() -> void:
	var selected_items: PackedInt32Array = officer_list.get_selected_items()
	if selected_items.is_empty():
		log_label.text = "임명할 장수를 선택하세요."
		return
	var officer_name: String = str(officer_list.get_item_metadata(selected_items[0]))
	var validation: Dictionary = validate_governor_appointment(
		selected_province_id,
		officer_name
	)
	if not bool(validation.get("ok", false)):
		log_label.text = str(validation.get("reason", "태수로 임명할 수 없습니다."))
		return
	if bool(validation.get("requires_confirmation", false)):
		pending_governor_appointment = {
			"province_id": selected_province_id,
			"officer_id": officer_name,
		}
		governor_appointment_confirmation.dialog_text = (
			"현재 태수 %s을(를) %s(으)로 교체하시겠습니까?"
			% [str(validation.get("current_governor", "")), get_officer(officer_name).get("name", officer_name)]
		)
		governor_appointment_confirmation.popup_centered(Vector2i(460, 160))
		return
	_apply_governor_appointment(selected_province_id, officer_name)


func _apply_governor_appointment(province_id: String, reference: String) -> Dictionary:
	officer_registry["clock_month"]=year*12+month
	var validation: Dictionary = validate_governor_appointment(province_id, reference)
	if not validation.get("ok", false): return validation
	var old: String = str(provinces[province_id].get("governor", "태수 없음"))
	var id: String = validation.officer_id
	if not OfficerRegistry.set_post(officer_registry, "governor:" + province_id, id): return {"ok":false,"reason":"권력 인계 협의에서 방식을 선택하세요."}
	_sync_officer_labels()
	select_province(province_id)
	_refresh_map_markers()
	log_label.text = "%s을(를) %s의 태수로 임명했습니다." % [get_officer(id).name, provinces[province_id].name]
	return {"ok": true, "officer_id": id, "previous_governor": old, "governor": get_officer(id).name}


func _on_governor_appointment_confirmed() -> void:
	var request: Dictionary = pending_governor_appointment
	pending_governor_appointment = {}
	var result: Dictionary = _apply_governor_appointment(
		str(request.get("province_id", "")),
		str(request.get("officer_id", request.get("officer_name", "")))
	)
	if not bool(result.get("ok", false)):
		log_label.text = str(result.get("reason", "태수로 임명할 수 없습니다."))


func _on_governor_appointment_canceled() -> void:
	pending_governor_appointment = {}


func update_attack_button(province_id: String) -> void:
	if Ending.finished(strategy_state):
		attack_button.disabled=true
		attack_button.tooltip_text=Ending.BLOCKED
		return
	if not provinces.has(province_id):
		attack_button.disabled = true
		return

	var province: Dictionary = provinces[province_id]
	var player_owned: bool = province["faction"] == player_faction and not Ending.finished(strategy_state)

	if attack_source_id == "":
		attack_button.text = "공격 준비"
		attack_button.disabled = not player_owned or not has_enemy_neighbor(province_id) or not validate_attack_staff(province_id).ok
		attack_button.tooltip_text = str(validate_attack_staff(province_id).get("reason",""))
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
	if Ending.finished(strategy_state):
		log_label.text=Ending.BLOCKED
		return
	if selected_province_id == "":
		return
	if attack_source_id.is_empty() and not validate_attack_staff(selected_province_id).ok:
		log_label.text=validate_attack_staff(selected_province_id).reason
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

		if Army.count(strategy_state,Army.at_city(strategy_state,selected_province_id,player_faction_id,true)) < 3000:
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

	var source_food_stock: int = int(
		provinces[attack_source_id].get("food_stock", 0)
	)
	if source_food_stock < ATTACK_FOOD_COST:
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
		log_label.text = "명령 국가 소유 영지에서만 지원할 수 있습니다."
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
	var officer_labels: Dictionary = {}
	for id: String in get_city_officer_ids(selected_province_id):
		if not OfficerRegistry.eligible(officer_registry, id, provinces, selected_province_id): continue
		available_officers.append(id)
		officer_labels[id] = get_officer(id).name
	transfer_panel.open_for_transfer(
		selected_province_id,
		str(source.get("name", selected_province_id)),
		destinations,
		int(source.get("troops", 0)),
		available_officers,
		get_governor_id(selected_province_id),
		false,
		false,
		officer_labels
	)


func validate_province_transfer(request: Dictionary, actor: String = "") -> Dictionary:
	if actor.is_empty(): actor=player_faction_id
	var actor_name: String=str(strategy_state.faction_economy.factions.get(actor,""))
	if Ending.finished(strategy_state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	var source_id: String = str(request.get("source_id", ""))
	var target_id: String = str(request.get("target_id", ""))
	var troop_count: int = int(request.get("troops", 0))
	var food_count: int = int(request.get("food", 0))
	var gold_count: int = int(request.get("gold", 0))
	var requested_officers: Array[String] = []
	var seen_officers: Dictionary = {}
	var officer_values: Variant = request.get("officer_ids", request.get("officers", []))
	if typeof(officer_values) != TYPE_ARRAY:
		return {"ok": false, "reason": "장수 이동 요청 형식이 올바르지 않습니다."}
	for officer_value: Variant in officer_values:
		var officer_name: String = OfficerRegistry.resolve(officer_registry, str(officer_value))
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
	if str(source.get("faction", "")) != actor_name:
		return {"ok": false, "reason": "명령 국가 소유 영지에서만 지원할 수 있습니다."}
	if str(target.get("faction", "")) != str(source.get("faction", "")):
		return {"ok": false, "reason": "같은 세력의 영지로만 지원할 수 있습니다."}
	if not are_provinces_connected(source_id, target_id):
		return {"ok": false, "reason": "직접 연결된 영지로만 지원할 수 있습니다."}
	if troop_count < 0 or food_count < 0 or gold_count < 0:
		return {"ok": false, "reason": "이동 수량은 음수일 수 없습니다."}
	if food_count > 0 or gold_count > 0:
		return {"ok": false, "reason": "금은 국가 국고로 관리합니다. 도시 군량·철·칼은 화물 수송 화면을 이용하세요."}
	if troop_count > int(source.get("troops", 0)):
		return {"ok": false, "reason": "출발 영지의 보유 병력보다 많이 이동할 수 없습니다."}
	if troop_count == 0 and requested_officers.is_empty():
		return {"ok": false, "reason": "병력 또는 이동할 장수를 선택하세요."}

	var source_officers: Array = get_city_officer_ids(source_id)
	for officer_name: String in requested_officers:
		if OfficerRegistry.eligible(officer_registry,officer_name,provinces,source_id) and not OfficerRegistry.action_available(officer_registry,officer_name,provinces,"move",source_id):
			return {"ok":false,"reason":"진행 중인 내정 업무를 먼저 완료하거나 취소한 뒤 이동하세요."}
		if is_officer_transfer_pending(officer_name):
			return {"ok": false, "reason": "%s은(는) 이미 이동 중입니다." % officer_name}
		if not source_officers.has(officer_name) or not OfficerRegistry.eligible(officer_registry, officer_name, provinces, source_id):
			return {"ok": false, "reason": "%s은(는) 출발 영지에 배치되어 있지 않습니다." % officer_name}

	var governor_name: String = get_governor_id(source_id)
	return {
		"ok": true,
		"requires_governor_confirmation": (
			governor_name != ""
			and governor_name != "태수 없음"
			and requested_officers.has(governor_name)
		),
		"governor_name": get_officer(governor_name).get("name", ""),
		"officer_ids": requested_officers,
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
	queue_province_transfer(request, false)


func queue_province_transfer(
	request: Dictionary, governor_transfer_confirmed: bool = false, actor: String = ""
) -> Dictionary:
	if actor.is_empty(): actor=player_faction_id
	if Ending.finished(strategy_state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	officer_registry["clock_month"]=year*12+month
	var validation: Dictionary = validate_province_transfer(request,actor)
	if request.has("unit_ids"):
		var ids: Array=request.unit_ids
		var seen: Dictionary={}
		for uid: String in ids:
			if seen.has(uid) or not Army.check_unit(strategy_state,provinces,actor,uid).ok or Army.units(strategy_state)[uid].location!=request.get("source_id","") or not Army.training_job(strategy_state,uid).is_empty(): return {"ok":false,"reason":"현재 도시의 중복 없는 가용 부대를 선택하고 훈련을 중지하세요."}
			seen[uid]=true
		if Army.count(strategy_state,ids)!=int(request.get("troops",0)): return {"ok":false,"reason":"부대 병력 합계가 다릅니다."}
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
	var requested_officers: Array = validation.officer_ids
	if typeof(request.get("excluded_unit_ids",[]))!=TYPE_ARRAY: return {"ok":false,"reason":"제외 부대 목록 형식을 확인하세요."}
	var excluded: Array=request.get("excluded_unit_ids",[])
	var available_units: Array=Army.at_city(strategy_state,source_id,actor,true)
	for uid: String in excluded: available_units.erase(uid)
	if troop_count>Army.count(strategy_state,available_units): return {"ok":false,"reason":"훈련·준비 중인 부대를 제외한 가용 병력이 부족합니다."}
	var power_reason: String=Power.move_reason(self,request)
	if not power_reason.is_empty(): return {"ok":false,"reason":power_reason}
	var moved_units: Array=request.unit_ids.duplicate() if request.has("unit_ids") else Army.take(strategy_state,source_id,troop_count,actor,true,excluded)
	for uid: String in moved_units:
		if not requested_officers.has(Army.units(strategy_state)[uid].commander_id): Army.units(strategy_state)[uid].commander_id=""
	Army.relocate(strategy_state,moved_units,"","transit"); Army.sync(strategy_state,provinces)

	var source_officers: Array = get_city_officer_ids(source_id).duplicate()
	for officer_value: Variant in requested_officers:
		var officer_name: String = OfficerRegistry.resolve(officer_registry, str(officer_value))
		OfficerRegistry.set_location(officer_registry, officer_name, "", true)
	_sync_officer_labels()
	if bool(validation.get("requires_governor_confirmation", false)):
		provinces[source_id]["governor"] = "태수 없음"

	pending_transfer_orders.append(
		{
			"source_id": source_id,
			"target_id": target_id,
			"faction": str(provinces[source_id].get("faction", "")),
			"troops": troop_count,
			"unit_ids":moved_units,
			"officer_ids": requested_officers.duplicate(),
			"remaining_turns": 1,
		}
	)
	var parts: Array[String] = []
	if troop_count > 0:
		parts.append("병력 %d명" % troop_count)
	for officer_value: Variant in requested_officers:
		parts.append(get_officer(str(officer_value)).get("name", str(officer_value)))
	var message: String = "%s에서 %s로 %s 이동을 명령했습니다. 1턴 후 도착합니다." % [
		str(provinces[source_id].get("name", source_id)),
		str(provinces[target_id].get("name", target_id)),
		", ".join(parts),
	]
	if actor!=player_faction_id: return {"ok":true,"message":message}
	transfer_panel.close_panel()
	select_province(selected_province_id)
	log_label.text = message
	return {"ok": true, "message": message}


func is_officer_transfer_pending(reference: String) -> bool:
	var p: Dictionary = OfficerRegistry.get_person(officer_registry, reference)
	return not p.is_empty() and bool(p.get("in_transit", false))


func process_pending_transfer_orders() -> String:
	if Ending.finished(strategy_state): return ""
	var remaining_orders: Array[Dictionary] = []
	var messages: Array[String] = []
	for order_value: Variant in pending_transfer_orders:
		if typeof(order_value) != TYPE_DICTIONARY:
			continue
		var order: Dictionary = (order_value as Dictionary).duplicate(true)
		order["remaining_turns"] = maxi(0, int(order.get("remaining_turns", 1)) - 1)
		if int(order["remaining_turns"]) > 0:
			remaining_orders.append(order)
			continue
		messages.append_array(_resolve_pending_transfer_order(order))
	pending_transfer_orders = remaining_orders
	return "\n".join(messages)


func _resolve_pending_transfer_order(order: Dictionary) -> Array[String]:
	var messages: Array[String] = []
	var target_id: String = str(order.get("target_id", ""))
	if not provinces.has(target_id) or str(provinces[target_id].faction) != str(order.get("faction", "")):
		# Preserve affiliation and person when destination has fallen. Do not
		# donate officers/troops to the new owner. Return to a still-owned source.
		var source: String = str(order.get("source_id", ""))
		if not provinces.has(source) or provinces[source].faction != order.get("faction", ""):
			source = ""
		for id: String in order.get("officer_ids", []): OfficerRegistry.set_location(officer_registry,id,source)
		Army.relocate(strategy_state,order.get("unit_ids",[]),source,"stationed" if not source.is_empty() else "unplaced"); Army.sync(strategy_state,provinces)
		OfficerRegistry.diagnose(officer_registry,"transfer_destination_lost",order)
		return ["이동 목적지의 소유권이 바뀌어 복귀하거나 미배치 상태로 보존했습니다."]
	Army.relocate(strategy_state,order.get("unit_ids",[]),target_id); Army.sync(strategy_state,provinces)
	for id: String in order.get("officer_ids", []):
		OfficerRegistry.set_location(officer_registry,id,target_id)
		messages.append("%s이 %s에 도착했습니다." % [get_officer(id).get("name",id), provinces[target_id].name])
	_sync_officer_labels()
	return messages


func _on_governor_transfer_confirmed() -> void:
	var request: Dictionary = pending_governor_transfer
	pending_governor_transfer = {}
	var result: Dictionary = queue_province_transfer(request, true)
	if not bool(result.get("ok", false)):
		transfer_panel.show_error(str(result.get("reason", "이동할 수 없습니다.")))


func _on_governor_transfer_canceled() -> void:
	pending_governor_transfer = {}


func get_best_commander(province_id: String, action: String = "defense") -> Dictionary:
	var best: Dictionary = {"officer_id": "", "name": "수비대장", "leadership": 50, "war": 50, "intelligence": 50}
	var assigned: Array=[]
	if strategy_state.has("army"):
		for uid: String in (Army.attack_units(strategy_state,province_id) if action=="attack" else Army.at_city(strategy_state,province_id)):
			var oid: String=Army.units(strategy_state)[uid].commander_id
			if not oid.is_empty() and OfficerRegistry.action_available(officer_registry,oid,provinces,action,province_id): assigned.append(oid)
	for id: String in (assigned if not assigned.is_empty() else get_city_officer_ids(province_id)):
		if not OfficerRegistry.action_available(officer_registry, id, provinces, action, province_id): continue
		if action=="attack" and Army.at_city(strategy_state,province_id).any(func(uid): return Army.units(strategy_state)[uid].commander_id==id and not Power.unit_reason(strategy_state,uid).is_empty()): continue
		var officer: Dictionary = get_officer(id)
		if best.officer_id.is_empty() or int(officer.leadership) > int(best.leadership): best = officer
	return best


func get_ruler(faction_id: String) -> Dictionary:
	return get_officer(str(officer_registry.get("posts", {}).get("ruler:" + faction_id, "")))


func resolve_attack(source_id: String, target_id: String) -> void:
	var result: Dictionary=resolve_army_battle(source_id,target_id,player_faction_id)
	log_label.text=str(result.get("message",result.get("reason","")))
	attack_source_id=""
	if result.ok:
		select_province(target_id); update_top_bar()
		log_label.text=str(result.get("message",result.get("reason","")))
		if event_presentation!=null:
			event_presentation.dispatch.call_deferred({"event_key":"battle_start","attacker_name":result.attacker_name,"defender_name":result.defender_name},result)

func resolve_army_battle(source_id: String, target_id: String, actor: String) -> Dictionary:
	if Ending.finished(strategy_state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	Army.sync(strategy_state,provinces)
	if not provinces.has(source_id) or not provinces.has(target_id) or not province_connections.get(source_id,[]).has(target_id): return {"ok":false,"reason":"연결된 전장이 아닙니다."}
	if Economy.resolve(strategy_state,str(provinces[target_id].faction))==actor: return {"ok":false,"reason":"아군 도시는 공격할 수 없습니다."}
	var available: Dictionary=validate_attack_staff(source_id)
	if not available.ok: return available
	var participants: Array=Army.attack_units(strategy_state,source_id,actor)
	if participants.is_empty(): return {"ok":false,"reason":"훈련을 중지하고 출정 가능한 부대를 준비하세요."}
	var commander: Dictionary=get_best_commander(source_id,"attack")
	var authority_reason: String=Power.attack_reason(self,source_id,str(commander.get("officer_id","")))
	if not authority_reason.is_empty(): return {"ok":false,"reason":authority_reason}
	var paid: Dictionary=Economy.spend(strategy_state,provinces,actor,actor,source_id,0,ATTACK_FOOD_COST,"attack",year*12+month)
	if not paid.ok: return paid
	var defender: Dictionary=get_best_commander(target_id)
	mark_external_action(commander)
	var result: Dictionary=Army.combat(strategy_state,provinces,source_id,target_id,int(commander.leadership),int(defender.leadership),year*12+month)
	result.merge({"ok":true,"attacker_name":commander.name,"defender_name":defender.name,"battle_grade":"승리" if result.won else "패배"})
	if result.won:
		Supply.capture(strategy_state,provinces,target_id,year*12+month)
		ProductionSystem.stop_on_capture(strategy_state,target_id)
		provinces[target_id].public_order=35
		Power.applying=true
		_move_commander_to_province(str(commander.get("officer_id","")),source_id,target_id)
		Power.applying=false
		# Occupying troops retain the actual departing leader, not an officer left at the source.
		for uid: String in Army.at_city(strategy_state,target_id,actor): Army.units(strategy_state)[uid].commander_id=str(commander.get("officer_id",""))
	Army.process(strategy_state,provinces,year*12+month)
	result["message"]="%s · %s → %s\n실효 전투력 %.1f / %.1f · 손실 %d / %d" % [result.battle_grade,provinces[source_id].name,provinces[target_id].name,result.attacker_power,result.defender_power,result.attacker_losses,result.defender_losses]
	if result.won:
		var land_path: Array=Supply.route(strategy_state,provinces,actor,source_id,target_id)
		result["land_supply_connected"]=not land_path.is_empty()
		result.message+="\n점령지 군량 %d · 현재 주둔군 월 소비 %d · 태수·모집 가능 인물을 확인하세요." % [int(provinces[target_id].food_stock),Supply.upkeep(provinces[target_id])]
		if land_path.is_empty(): result.message+="\n출발지와 아군 육상 보급로가 없습니다. 현재 화물은 해상 수송을 지원하지 않습니다. 현지 수확·주둔 규모·다른 육로 확보를 검토하세요."
	_queue_ending_check.call_deferred("battle_complete")
	return result

func player_controls_all_provinces() -> bool:
	return Ending.evaluate(strategy_state,provinces).get("status","")=="victory"


func _on_develop_button_pressed() -> void:
	open_domestic("agriculture")


func _on_commerce_button_pressed() -> void:
	open_domestic("commerce")


func open_domestic(kind: String) -> void:
	if not is_selected_province_player_owned(): return
	if event_presentation!=null and event_presentation.active: return
	if recruitment_overlay!=null: recruitment_overlay.hide()
	if army_overlay!=null: army_overlay.hide()
	if politics_overlay!=null: politics_overlay.hide()
	if power_dialog!=null: power_dialog.hide()
	if playability_dialog!=null: playability_dialog.hide()
	if supply_overlay!=null: supply_overlay.hide()
	if industry_overlay!=null: industry_overlay.hide()
	_close_diplomacy()
	production_overlay.hide()
	transfer_panel.close_panel()
	domestic_overlay.open(self,selected_province_id,kind)


func get_domestic_quote(city: String, kind: String, id: String) -> Dictionary:
	return Domestic.quote(strategy_state,provinces,player_faction,city,kind,id,gold,year*12+month)


func start_domestic(city: String, kind: String, id: String) -> Dictionary:
	var result: Dictionary=Domestic.start(strategy_state,provinces,player_faction,city,kind,id,gold,year*12+month)
	update_top_bar()
	return result


func cancel_domestic(id: String) -> Dictionary:
	var result: Dictionary=Domestic.cancel(strategy_state,provinces,player_faction,id,gold,year*12+month)
	update_top_bar()
	log_label.text=result.reason
	return result


func dismiss_governor(city: String) -> bool:
	if Ending.finished(strategy_state): return false
	if not provinces.has(city) or provinces[city].faction!=player_faction: return false
	officer_registry["clock_month"]=year*12+month
	if not OfficerRegistry.set_post(officer_registry,"governor:"+city,"","해임"): return false
	_sync_officer_labels()
	select_province(city)
	return true


func validate_attack_staff(city: String) -> Dictionary:
	if not provinces.has(city): return {"ok":false,"reason":"존재하지 않는 도시입니다."}
	if Army.attack_units(strategy_state,city).is_empty():
		for uid: String in Army.at_city(strategy_state,city):
			if not Power.unit_reason(strategy_state,uid).is_empty(): return {"ok":false,"reason":Power.unit_reason(strategy_state,uid)}
	var blocked: bool=false
	for id: String in get_city_officer_ids(city):
		if not OfficerRegistry.eligible(officer_registry,id,provinces,city): continue
		if OfficerRegistry.action_available(officer_registry,id,provinces,"attack",city): return {"ok":true}
		blocked=true
	return {"ok":not blocked,"reason":"내정 담당자를 출정시키려면 업무를 먼저 완료하거나 취소하세요." if blocked else ""}


func mark_external_action(commander: Dictionary) -> void:
	var p: Dictionary=OfficerRegistry.get_person(officer_registry,str(commander.get("officer_id","")))
	if not p.is_empty(): p["external_action_month"]=year*12+month


func _province_id(province: Dictionary) -> String:
	for city: String in provinces:
		if is_same(provinces[city],province): return city
	return ""


func city_operation_quote(city: String) -> Dictionary:
	var province: Dictionary=provinces.get(city,{})
	var governor: Dictionary=Domestic.governor(strategy_state,provinces,city,year*12+month)
	var base_tax: int=calculate_base_commerce_income(province)
	var base_harvest: int=calculate_base_annual_harvest(province)
	var tax: int=roundi(base_tax*float(governor.multiplier))
	var harvest: int=roundi(base_harvest*float(governor.multiplier))
	return {"base_tax":base_tax,"tax":tax,"tax_bonus":tax-base_tax,"base_harvest":base_harvest,"annual_harvest":harvest,"harvest_bonus":harvest-base_harvest,"governor":governor,"commerce":province.get("commerce",0),"agriculture":province.get("agriculture",0),"public_order":province.get("public_order",0)}


func calculate_monthly_commerce_income(province: Dictionary) -> int:
	var city: String=_province_id(province)
	return city_operation_quote(city).tax if not city.is_empty() else calculate_base_commerce_income(province)


func calculate_annual_harvest(province: Dictionary) -> int:
	var city: String=_province_id(province)
	return city_operation_quote(city).annual_harvest if not city.is_empty() else calculate_base_annual_harvest(province)


func get_city_operation_text(city: String) -> String:
	var q: Dictionary=city_operation_quote(city)
	var p: Dictionary=get_officer(q.governor.officer_id)
	var text: String="태수: %s · 운영 +%.1f%%\n월 세입: 기본 %d + 태수 %d = %d\n연간 수확: 기본 %d + 태수 %d = %d\n국가 수취율·9/10월 배분·소비·창고 규칙 별도 적용" % [p.get("name","공석/근무 불가"),(q.governor.multiplier-1)*100,q.base_tax,q.tax_bonus,q.tax,q.base_harvest,q.harvest_bonus,q.annual_harvest]
	var receipt: Dictionary=Domestic.ensure(strategy_state).settlements.get(city,{})
	if receipt.has("tax"): text+="\n직전 세입 결산: 기본 %d + 태수 %d = %d" % [receipt.base_tax,receipt.tax_bonus,receipt.tax]
	if receipt.has("harvest"): text+="\n직전 수확 결산: 기본 %d + 태수 %d = %d" % [receipt.base_collected,receipt.collected_bonus,receipt.harvest]
	return text

func claim_economy_phase(phase: String) -> bool:
	if Ending.finished(strategy_state): return false
	var stamps: Dictionary=strategy_state.faction_economy.phase_months
	var stamp: int=year*12+month
	if int(stamps.get(phase,-1))>=stamp: return false
	stamps[phase]=stamp
	return true

func get_faction_gold(id: String) -> int:
	return Economy.balance(strategy_state,id)

func get_recruitment_quote(city: String, amount: int = 1000) -> Dictionary:
	var q: Dictionary=Recruitment.quote(strategy_state,provinces,player_faction_id,player_faction_id,city,amount)
	var before: Dictionary=city_operation_quote(city)
	var shadow: Dictionary=provinces.get(city,{}).duplicate(true)
	shadow.population=maxi(0,int(shadow.get("population",0))-amount)
	q["tax_before"]=before.tax; q["harvest_before"]=before.annual_harvest
	q["tax_after"]=roundi(calculate_base_commerce_income(shadow)*float(before.governor.multiplier))
	q["harvest_after"]=roundi(calculate_base_annual_harvest(shadow)*float(before.governor.multiplier))
	var harvest_month: int=10 if month==9 else 9
	var harvest_year: int=year if month<10 else year+1
	var share: float=0.3 if harvest_month==10 else 0.7
	q["next_harvest_date"]="%d.%02d" % [harvest_year,harvest_month]
	q["next_harvest_before"]=roundi(roundi(int(q.harvest_before)*FOOD_COLLECTION_RATE)*share)
	q["next_harvest_after"]=roundi(roundi(int(q.harvest_after)*FOOD_COLLECTION_RATE)*share)
	return q

func recruit_for_faction(id: String, city: String, amount: int) -> Dictionary:
	var result: Dictionary=Recruitment.execute(strategy_state,provinces,id,id,city,amount,year*12+month)
	if result.ok: strategy.reconcile_unit_roster(strategy_state,city,int(provinces[city].troops))
	return result

func request_recruitment(city: String, amount: int = 1000) -> Dictionary:
	if event_presentation!=null and event_presentation.active: return {"ok":false,"reason":"사건 처리를 먼저 완료하세요."}
	var result: Dictionary=recruit_for_faction(player_faction_id,city,amount)
	if result.ok:
		select_province(city)
		log_label.text="%d명 모집 · 금 %d / 도시 군량 %d 지불" % [amount,result.gold_cost,result.food_cost]
	else: log_label.text=result.reason
	update_top_bar()
	return result

func _on_recruit_button_pressed() -> void:
	if army_overlay!=null: army_overlay.hide()
	if politics_overlay!=null: politics_overlay.hide()
	if power_dialog!=null: power_dialog.hide()
	if playability_dialog!=null: playability_dialog.hide()
	if supply_overlay!=null: supply_overlay.hide()
	if industry_overlay!=null: industry_overlay.hide()
	if not is_selected_province_player_owned():
		log_label.text="플레이어 소유 도시에서만 모집할 수 있습니다."
		return
	domestic_overlay.hide()
	production_overlay.hide()
	_close_diplomacy()
	recruitment_overlay.open(self,selected_province_id)

func _on_end_turn_button_pressed() -> void:
	if Ending.finished(strategy_state) or ending_busy: return
	if army_overlay!=null and army_overlay.visible: return
	if politics_overlay!=null and politics_overlay.visible: return
	if power_dialog!=null and power_dialog.visible: return
	if playability_dialog!=null and playability_dialog.visible: return
	if supply_overlay!=null and supply_overlay.visible: return
	if industry_overlay!=null and industry_overlay.visible: return
	if recruitment_overlay!=null and recruitment_overlay.visible: return
	if domestic_overlay!=null and domestic_overlay.visible: return
	if diplomacy_overlay != null and diplomacy_overlay.visible:
		return
	if event_presentation != null and event_presentation.active:
		return
	ending_busy=true
	var season_changed: bool = _advance_month()

	officer_registry["clock_month"]=year*12+month
	Army.initialize(strategy_state,provinces,pending_transfer_orders,strategy.RECRUIT_UNIT_DEFS.merged(strategy.SPECIAL_UNIT_DEFS))
	Mobilization.initialize(strategy_state,provinces)
	Supply.ensure(strategy_state)
	Industry.normalize(strategy_state,provinces,strategy,year*12+month)
	Power.begin_month(self)
	var economy_messages: Array[String] = Domestic.process(strategy_state,provinces,year*12+month)
	economy_messages.append_array(Industry.process(strategy_state,provinces,year*12+month))
	economy_messages.append_array(Supply.process(strategy_state,provinces,year*12+month))
	economy_messages.append_array(process_monthly_commerce_income())
	economy_messages.append_array(process_seasonal_harvest())
	economy_messages.append_array(process_monthly_troop_food_upkeep())
	economy_messages.append_array(process_monthly_storage_losses())
	Army.process(strategy_state,provinces,year*12+month)
	var production_result: Dictionary = ProductionSystem.process_all(
		strategy_state, provinces, year * MONTHS_PER_YEAR + month, scenario_id, iron_supply_rules
	)
	for message: String in production_result["messages"]:
		economy_messages.append(_production_reason_text(message))
	var public_order_message: String = process_public_order()
	var transfer_message: String = process_pending_transfer_orders()

	var ai_message: String = run_enemy_ai_turns()

	# 건설·연구·교역과, 봄에는 인재 보충·혼인·출산·자녀 성장을 처리합니다.
	var strategy_message: String = (
		_process_strategy_season() if season_changed else ""
	)

	update_top_bar()

	if selected_province_id != "":
		select_province(selected_province_id)

	log_label.text = "%d년 %d월이 되었습니다." % [year, month]
	if not economy_messages.is_empty():
		log_label.text += "\n" + combine_messages(economy_messages)
	if transfer_message != "":
		log_label.text += "\n" + transfer_message

	if public_order_message != "":
		log_label.text += "\n" + public_order_message

	if ai_message != "":
		log_label.text += "\n" + ai_message

	if strategy_message != "":
		log_label.text += "\n" + strategy_message
	_present_harvest_event()
	_present_pending_choice()
	ending_busy=false
	Power.finish_month(self)
	evaluate_campaign_ending.call_deferred("month_complete")


func _present_pending_choice(resuming: bool = false) -> void:
	if not resuming: Noble.ai(self)
	if CropFailure.cancel_if_unowned(crop_failure_events, provinces, player_faction):
		log_label.text += "\n흉년 발생 영지의 소유권이 바뀌어 후속 정책 선택이 취소되었습니다."
		return
	var pending: Dictionary = crop_failure_events.get("pending", {})
	if not pending.is_empty():
		event_presentation.play_choice(pending, resuming)
	elif officer_registry.has("politics") and player_faction_id==officer_registry.politics.faction_id:
		var demand: Dictionary=officer_registry.politics.pending if resuming else Noble.propose(self)
		if not demand.is_empty(): event_presentation.play_choice(demand,resuming)


func get_event_choice_reason(event_id: String, occurrence: String, choice: String) -> String:
	if event_id==Noble.EVENT: return Noble.reason(self,occurrence,choice)
	if event_id == CropFailure.EVENT_ID:
		return CropFailure.choice_reason(crop_failure_events, provinces, player_faction, occurrence, choice)
	return "지원하지 않는 선택 이벤트입니다"


func resolve_event_choice(event_id: String, occurrence: String, choice: String) -> Dictionary:
	if Ending.finished(strategy_state): return {"ok":false,"executed":false,"reason":Ending.BLOCKED,"messages":[],"gold_spent":0}
	if event_id==Noble.EVENT:
		var result: Dictionary=Noble.resolve(self,occurrence,choice)
		update_top_bar()
		return result
	if event_id != CropFailure.EVENT_ID:
		return {}
	var result: Dictionary = CropFailure.resolve(crop_failure_events, provinces, player_faction, occurrence, choice)
	if not result.is_empty():
		update_top_bar()
		event_presentation.event_finished.connect(_refresh_after_event_choice, CONNECT_ONE_SHOT)
	return result


func _refresh_after_event_choice(_event_id: String) -> void:
	select_province(selected_province_id)


func _present_harvest_event() -> void:
	if pending_harvest_presentation.is_empty():
		return
	var result: Dictionary = pending_harvest_presentation
	pending_harvest_presentation = {}
	if event_presentation != null:
		event_presentation.play("domestic_bountiful_harvest", result, str(result.occurrence_id))


func _advance_month() -> bool:
	if Ending.finished(strategy_state): return false
	var previous_season_index: int = season_index
	month += 1
	if month > MONTHS_PER_YEAR:
		month = 1
		year += 1
	_sync_season_from_month()
	return season_index != previous_season_index


func _sync_season_from_month() -> void:
	month = clampi(month, 1, MONTHS_PER_YEAR)
	season_index = floori(float(month - 1) / float(MONTHS_PER_SEASON))


func _process_strategy_season() -> String:
	if Ending.finished(strategy_state): return ""
	if strategy_state.is_empty():
		return ""
	if not claim_economy_phase("season"): return ""

	var result: Dictionary = strategy.process_season(
		strategy_state,
		year,
		season_index,
		provinces,
		officers_by_province,
		_get_scenario_by_id(scenario_id)
	)

	var gold_delta: Dictionary = result.get("faction_gold_delta", {})
	for faction: String in gold_delta:
		Economy.post(strategy_state,Economy.resolve(strategy_state,faction),int(gold_delta[faction]),"trade",year*12+month)

	var messages: Array = result.get("messages", [])
	if messages.is_empty():
		return ""
	return combine_messages(messages)


func get_public_order_efficiency(public_order: int) -> float:
	return 0.5 + float(clampi(public_order, 0, 100)) / 200.0


func calculate_base_commerce_income(province: Dictionary) -> int:
	var population_in_thousands: float = (
		float(maxi(0, int(province.get("population", 0)))) / 1000.0
	)
	var commerce: int = clampi(int(province.get("commerce", 0)), 0, 100)
	var efficiency: float = get_public_order_efficiency(
		int(province.get("public_order", 0))
	)
	return roundi(
		population_in_thousands
		* float(commerce) / 100.0
		* efficiency
		* 2.0
	)


func calculate_base_annual_harvest(province: Dictionary) -> int:
	var population_in_thousands: float = (
		float(maxi(0, int(province.get("population", 0)))) / 1000.0
	)
	var agriculture: int = clampi(int(province.get("agriculture", 0)), 0, 100)
	var efficiency: float = get_public_order_efficiency(
		int(province.get("public_order", 0))
	)
	return roundi(
		population_in_thousands
		* float(agriculture) / 100.0
		* efficiency
		* 100.0
	)


func calculate_collected_harvest(province: Dictionary) -> int:
	# 총 농업생산 중 주민 소비·종자·민간 보유분을 제외한 국가 징수분입니다.
	# 향후 세율 정책은 이 고정 징수율을 정책값으로 교체할 수 있습니다.
	return roundi(float(calculate_annual_harvest(province)) * FOOD_COLLECTION_RATE)


func process_monthly_commerce_income() -> Array[String]:
	if Ending.finished(strategy_state): return []
	var messages: Array[String] = []
	var total_income: int = 0
	for province_id: String in Economy.city_ids(strategy_state,provinces):
		if not provinces.has(province_id):
			continue
		var province: Dictionary = provinces[province_id]
		if _get_province_controller(province) == CONTROLLER_INACTIVE:
			continue
		var receipts: Dictionary=Domestic.ensure(strategy_state).settlements
		if not receipts.has(province_id): receipts[province_id]={}
		var receipt: Dictionary=receipts[province_id]
		if int(receipt.get("tax_month",-1))==year*12+month: continue
		var quote: Dictionary=city_operation_quote(province_id)
		receipt.merge(quote,true)
		receipt["tax_month"]=year*12+month
		var income: int = quote.tax
		Economy.post(strategy_state,Economy.resolve(strategy_state,str(province.faction)),income,"tax",year*12+month,province_id,"tax:%s:%d" % [province_id,year*12+month])
		if _get_province_controller(province)!=CONTROLLER_PLAYER: continue
		total_income += income
		if province_id == selected_province_id:
			messages.append("%s 상업세: 기본 %d + 태수 %d = %d" % [str(province["name"]),quote.base_tax,quote.tax_bonus,income])
	if messages.is_empty() and total_income > 0:
		messages.append("플레이어 도시 상업세 합계 +%d" % total_income)
	return messages


func process_seasonal_harvest() -> Array[String]:
	if Ending.finished(strategy_state): return []
	var harvest_rate: float = 0.0
	if month == 9:
		harvest_rate = 0.70
	elif month == 10:
		harvest_rate = 0.30
	if harvest_rate <= 0.0:
		return []

	var messages: Array[String] = []
	var player_harvest_total: int = 0
	var september_harvests: Dictionary = {}
	for province_id: String in Economy.city_ids(strategy_state,provinces):
		if not provinces.has(province_id):
			continue
		var province: Dictionary = provinces[province_id]
		var controller: String = _get_province_controller(province)
		if controller == CONTROLLER_INACTIVE:
			continue
		var receipts: Dictionary=Domestic.ensure(strategy_state).settlements
		if not receipts.has(province_id): receipts[province_id]={}
		var receipt: Dictionary=receipts[province_id]
		if int(receipt.get("harvest_month",-1))==year*12+month: continue
		var collected_harvest: int = calculate_collected_harvest(province)
		var harvest: int = roundi(float(collected_harvest) * harvest_rate)
		var base: int=roundi(roundi(calculate_base_annual_harvest(province)*FOOD_COLLECTION_RATE)*harvest_rate)
		receipt.merge({"harvest_month":year*12+month,"base_collected":base,"collected_bonus":harvest-base,"harvest":harvest},true)
		province["food_stock"] = int(province.get("food_stock", 0)) + harvest
		if controller == CONTROLLER_PLAYER:
			player_harvest_total += harvest
			if month == 9:
				september_harvests[province_id] = harvest
			if province_id == selected_province_id:
				messages.append("%s 수확: 기본 %d + 태수 %d = %d" % [str(province["name"]),base,harvest-base,harvest])
	if messages.is_empty() and player_harvest_total > 0:
		messages.append("플레이어 도시 가을 수확 합계 +%d" % player_harvest_total)
	var bounty: Dictionary = BountifulHarvest.apply_september(
		harvest_events, scenario_id, year, month, provinces, player_faction, september_harvests
	)
	if not bounty.is_empty():
		pending_harvest_presentation = bounty
		messages.append("%s 풍년: 9월 수확 추가 군량 +%d · 치안 +%d" % [bounty.province_name, bounty.grain_delta, bounty.public_order_delta])
	var failure: Dictionary = CropFailure.apply_september(crop_failure_events, scenario_id, year, month,
		provinces, player_faction, september_harvests,
		str(harvest_events.get("years", {}).get(str(year), {}).get("province_id", "")))
	if not failure.is_empty():
		messages.append("%s 흉년: 9월 수확 군량 -%d" % [failure.payload.province_name, failure.payload.harvest_loss])
	return messages


func calculate_monthly_troop_food(province: Dictionary) -> int:
	return Supply.upkeep(province)


func process_monthly_troop_food_upkeep() -> Array[String]:
	if not claim_economy_phase("upkeep"): return []
	var messages: Array[String] = []
	var player_consumed_total: int = 0
	var player_shortage_total: int = 0
	for province_id: String in Economy.city_ids(strategy_state,provinces):
		if not provinces.has(province_id):
			continue
		var province: Dictionary = provinces[province_id]
		var controller: String = _get_province_controller(province)
		if controller == CONTROLLER_INACTIVE:
			province["food_shortage"] = false
			province["food_shortage_amount"] = 0
			continue
		var required_food: int = calculate_monthly_troop_food(province)
		var available_food: int = maxi(0, int(province.get("food_stock", 0)))
		var consumed_food: int = mini(required_food, available_food)
		var shortage_amount: int = maxi(0, required_food - consumed_food)
		province["food_stock"] = available_food - consumed_food
		province["food_shortage"] = shortage_amount > 0
		province["food_shortage_amount"] = shortage_amount
		if controller != CONTROLLER_PLAYER:
			continue
		player_consumed_total += consumed_food
		player_shortage_total += shortage_amount
		if province_id == selected_province_id:
			var message: String = "%s 주둔군 군량 -%d" % [
				str(province["name"]),
				consumed_food,
			]
			if shortage_amount > 0:
				message += " (부족 %d)" % shortage_amount
			messages.append(message)
	if messages.is_empty() and (player_consumed_total > 0 or player_shortage_total > 0):
		var summary: String = "플레이어 도시 주둔군 군량 -%d" % player_consumed_total
		if player_shortage_total > 0:
			summary += " (부족 %d)" % player_shortage_total
		messages.append(summary)
	return messages


func get_monthly_normal_storage_loss_rate() -> float:
	return 0.01 if season_index == 3 else 0.005


func calculate_monthly_storage_loss(province: Dictionary) -> int:
	var stock: int = maxi(0, int(province.get("food_stock", 0)))
	var capacity: int = maxi(0, int(province.get("granary_capacity", 0)))
	var normal_stock: int = mini(stock, capacity)
	var excess_stock: int = maxi(0, stock - capacity)
	var normal_loss: int = roundi(
		float(normal_stock) * get_monthly_normal_storage_loss_rate()
	)
	var excess_loss: int = roundi(float(excess_stock) * 0.075)
	return mini(stock, normal_loss + excess_loss)


func process_monthly_storage_losses() -> Array[String]:
	if not claim_economy_phase("storage"): return []
	var messages: Array[String] = []
	var player_loss_total: int = 0
	for province_id: String in Economy.city_ids(strategy_state,provinces):
		if not provinces.has(province_id):
			continue
		var province: Dictionary = provinces[province_id]
		var controller: String = _get_province_controller(province)
		if controller == CONTROLLER_INACTIVE:
			continue
		var loss: int = calculate_monthly_storage_loss(province)
		province["food_stock"] = maxi(
			0,
			int(province.get("food_stock", 0)) - loss
		)
		if controller != CONTROLLER_PLAYER or loss <= 0:
			continue
		player_loss_total += loss
		if province_id == selected_province_id:
			messages.append("%s 저장손실 -%d" % [str(province["name"]), loss])
	if messages.is_empty() and player_loss_total > 0:
		messages.append("플레이어 도시 저장손실 합계 -%d" % player_loss_total)
	return messages


func process_public_order() -> String:
	if Ending.finished(strategy_state): return ""
	var recovered_names: Array[String] = []

	# 치안 회복도 한반도 지역만 처리합니다.
	for province_id: String in Economy.city_ids(strategy_state,provinces):
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


func run_enemy_ai_turns() -> String:
	if Ending.finished(strategy_state): return ""
	if not claim_economy_phase("ai"): return ""
	Power.ai(self)
	var ai_province_ids: Array[String] = []

	# 유목 부족은 여기서 제외합니다. 초원과 요동을 잇는 길은
	# STRATEGIC_ROUTES라서 여러 턴에 걸쳐 이동해야 하는데, 이 로직은
	# 한 턴에 인접지를 치는 방식이라 그대로 두면 순간이동이 됩니다.
	for province_id: String in Economy.city_ids(strategy_state,provinces):
		if not provinces.has(province_id):
			continue
		if _get_province_controller(provinces[province_id]) == CONTROLLER_AI:
			ai_province_ids.append(province_id)

	var messages: Array[String] = []
	var recruit_counts: Dictionary = {}
	var supply_factions: Dictionary={}
	var planned_attacks: Dictionary={}
	for city: String in ai_province_ids:
		var faction_id: String=Economy.resolve(strategy_state,str(provinces[city].faction))
		supply_factions[faction_id]=true
		var target: String=find_ai_target(city)
		if not target.is_empty() and int(provinces[city].troops)>=int(float(provinces[target].troops)*ai_attack_ratio) and validate_attack_staff(city).ok: planned_attacks[city]=ATTACK_FOOD_COST
	var supply_ids: Array=supply_factions.keys(); supply_ids.sort()
	for faction_id: String in supply_ids:
		messages.append_array(MilitaryPlanning.run(self,faction_id,planned_attacks))

	for source_id in ai_province_ids:
		if not provinces.has(source_id):
			continue

		var source: Dictionary = provinces[source_id]

		if _get_province_controller(source) != CONTROLLER_AI:
			continue

		var payer: String=Economy.resolve(strategy_state,str(source.faction))
		var target_id: String = find_ai_target(source_id)

		if target_id != "":
			var target: Dictionary = provinces[target_id]
			var required_troops: int = int(
				float(target["troops"]) * ai_attack_ratio
			)

			var available: Array=Army.attack_units(strategy_state,source_id,payer)
			var attack_power: float=Army.power(strategy_state,available)*(1+float(get_best_commander(source_id,"attack").leadership)/100.0)
			var defense_power: float=Army.power(strategy_state,Army.at_city(strategy_state,target_id))*(1+float(get_best_commander(target_id).leadership)/100.0+float(target.fortress)/200.0)
			if Army.count(strategy_state,available) >= required_troops and attack_power>defense_power*1.1:
				messages.append(resolve_ai_attack(source_id, target_id))
				continue

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
	var alert: Dictionary={}
	if event_presentation!=null and provinces.has(target_id) and provinces.has(source_id) and provinces[target_id].faction==player_faction:
		alert={"target_province_id":target_id,"target_province_name":provinces[target_id].name,"enemy_faction_name":provinces[source_id].faction,"enemy_troops":provinces[source_id].troops}
	var actor: String=Economy.resolve(strategy_state,str(provinces.get(source_id,{}).get("faction","")))
	var result: Dictionary=resolve_army_battle(source_id,target_id,actor)
	if result.ok and not alert.is_empty(): event_presentation.dispatch.call_deferred({"event_key":"enemy_crossed_border"},alert)
	return str(result.get("message",result.get("reason","")))

func _move_commander_to_province(reference: String, source_id: String, target_id: String) -> void:
	var id: String = OfficerRegistry.resolve(officer_registry, reference)
	# The existing capture policy removes defending officers from field service;
	# retain their identities and original affiliations instead of deleting them.
	for defender_id: String in get_city_officer_ids(target_id):
		if defender_id == id: continue
		OfficerRegistry.set_location(officer_registry, defender_id, "")
		officer_registry.people[defender_id]["captured_by"] = str(provinces[target_id].faction)
	OfficerRegistry.set_post(officer_registry,"governor:"+target_id,"","점령 자동 해제")
	Domestic.process(strategy_state,provinces,year*12+month)
	if id.is_empty():
		_sync_officer_labels()
		return
	# One officer has one location; a lone commander returns to defend its source.
	if get_city_officer_ids(source_id).size() > 1:
		OfficerRegistry.set_location(officer_registry,id,target_id)
		OfficerRegistry.set_post(officer_registry,"governor:"+target_id,id,"점령 자동 배치")
		var remaining: Array[String] = get_city_officer_ids(source_id)
		if get_governor_id(source_id).is_empty() and not remaining.is_empty():
			OfficerRegistry.set_post(officer_registry,"governor:"+source_id,remaining[0],"점령 자동 배치")
	_sync_officer_labels()


func _ensure_additional_officer_assignments() -> void:
	# Compatibility hook: never re-seed a running/loaded campaign.
	_sync_officer_labels()


func _sync_officer_labels() -> void:
	if not officer_registry.is_empty():
		OfficerRegistry.sync_province_labels(officer_registry, provinces)


func get_officer(reference: String) -> Dictionary:
	return OfficerRegistry.view(officer_registry, reference)


func get_city_officer_ids(city_id: String) -> Array[String]:
	return OfficerRegistry.at_city(officer_registry, city_id)


func get_governor_id(city_id: String) -> String:
	return OfficerRegistry.governor_id(officer_registry, city_id)


func register_generated_officer(data: Dictionary, faction_id: String, city_id: String, origin: String = "generated", stable_id: String = "") -> String:
	if Ending.finished(strategy_state): return ""
	var id: String = OfficerRegistry.register_generated(officer_registry, data, faction_id, city_id, origin, stable_id)
	OfficerRegistry.bind_dynasty(strategy_state)
	return id


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


func _on_save_button_pressed(save_path: String = SAVE_PATH) -> bool:
	if Ending.finished(strategy_state):
		return save_ending_result("" if save_path==SAVE_PATH else save_path)
	return _write_campaign_save(save_path)

func _write_campaign_save(save_path: String) -> bool:
	var save_data: Dictionary = {
		"save_version": 13,
		"year": year,
		"month": month,
		"season_index": season_index,
		"gold": gold,
		"food": _get_total_player_food_stock(),
		"player_faction": player_faction,
		"play_style": play_style,
		"difficulty": difficulty,
		"scenario_id": scenario_id,
		"selected_province_id": selected_province_id,
		"provinces": provinces,
		"officer_registry_version": 1,
		"pending_transfer_orders": pending_transfer_orders,
		"strategy_state": OfficerRegistry.export_strategy(strategy_state),
		"event_presentation": event_presentation.export_state() if event_presentation != null else {},
		"harvest_events": harvest_events,
		"crop_failure_events": crop_failure_events,
	}
	var save_file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)

	if save_file == null:
		log_label.text = "저장 파일을 만들 수 없습니다."
		push_error(
			"CampaignMain: save failed (%s)"
			% error_string(FileAccess.get_open_error())
		)
		return false

	save_file.store_string(JSON.stringify(save_data, "\t"))
	save_file.flush()
	if save_file.get_error()!=OK:
		log_label.text="저장 쓰기에 실패했습니다."
		return false
	log_label.text = "%d년 %d월 · %s 진행 상황을 저장했습니다." % [
		year,
		month,
		SEASONS[season_index],
	]

	return true

func _on_load_button_pressed(save_path: String = SAVE_PATH) -> void:
	if not FileAccess.file_exists(save_path):
		log_label.text = "불러올 저장 파일이 없습니다."
		return

	var save_file: FileAccess = FileAccess.open(save_path, FileAccess.READ)

	if save_file == null:
		log_label.text = "저장 파일을 열 수 없습니다."
		return

	var serialized_save: String=save_file.get_as_text()
	var parsed_value: Variant = JSON.parse_string(serialized_save)

	if typeof(parsed_value) != TYPE_DICTIONARY:
		log_label.text = "저장 파일 형식이 올바르지 않습니다."
		return

	var save_data: Dictionary = parsed_value

	if not _is_valid_save_data(save_data):
		log_label.text = "9영지 저장 데이터가 손상되었거나 호환되지 않습니다."
		return

	ending_busy=true
	if ending_dialog!=null: ending_dialog.hide()
	if ending_load_dialog!=null: ending_load_dialog.hide()
	if ending_save_dialog!=null: ending_save_dialog.hide()
	pending_governor_transfer={}
	pending_governor_appointment={}
	governor_transfer_confirmation.hide()
	governor_appointment_confirmation.hide()
	ending_save_message=""
	end_turn_button.disabled=false
	pending_campaign_opening = false
	if event_presentation != null:
		var presentation_data: Variant = save_data.get("event_presentation", {})
		event_presentation.restore_state(presentation_data if presentation_data is Dictionary else {})
	year = int(save_data.get("year", 660))
	if save_data.has("month"):
		month = clampi(int(save_data.get("month", 1)), 1, MONTHS_PER_YEAR)
	else:
		var legacy_season_index: int = clampi(
			int(save_data.get("season_index", 0)),
			0,
			SEASONS.size() - 1
		)
		month = legacy_season_index * MONTHS_PER_SEASON + 1
	_sync_season_from_month()
	_legacy_start_gold = maxi(0, int(save_data.get("gold", 1000)))
	harvest_events = BountifulHarvest.restore_state(save_data.get("harvest_events"), year, month)
	crop_failure_events = CropFailure.restore_state(save_data.get("crop_failure_events"), year, month)
	pending_harvest_presentation = {}
	food = maxi(0, int(save_data.get("food", 3000)))
	player_faction = str(save_data.get("player_faction", "신라"))
	play_style = str(save_data.get("play_style", "historical"))
	difficulty = str(save_data.get("difficulty", "normal"))
	# Preserve explicit start identity. Never infer a pilot from the current year;
	# legacy saves without it retain the existing, non-pilot 660 fallback.
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
	var has_saved_food_stocks: bool = false
	for province_id: String in Korea35Data.PROVINCE_IDS:
		if provinces.has(province_id) and provinces[province_id].has("food_stock"):
			has_saved_food_stocks = true
			break
	_ensure_province_food_economy(
		-1 if has_saved_food_stocks else food
	)

	# 전략 상태를 되살립니다. 옛 세이브에는 없으므로 그때는 새로 만듭니다.
	if typeof(save_data.get("strategy_state", null)) == TYPE_DICTIONARY:
		strategy_state = strategy.normalize_loaded_state(
			save_data["strategy_state"],
			provinces
		)
	else:
		strategy_state = {}

	pending_transfer_orders.clear()
	var saved_transfer_orders: Variant = save_data.get("pending_transfer_orders", [])
	if typeof(saved_transfer_orders) == TYPE_ARRAY:
		for order_value: Variant in saved_transfer_orders:
			if typeof(order_value) == TYPE_DICTIONARY:
				pending_transfer_orders.append(
					(order_value as Dictionary).duplicate(true)
				)


	# 옛 세이브에는 전략 상태가 없습니다. officers_by_province가 복원된
	# 뒤에 만들어야 인재 배치가 제대로 잡힙니다.
	if strategy_state.is_empty():
		_init_strategy_state(false)
	strategy_state["officer_registry"] = OfficerRegistry.migrate(save_data, strategy_state, provinces, scenario_id, OfficerCatalog.data().legacy_campaign)
	Domestic.ensure(strategy_state)
	Economy.initialize(strategy_state,_get_scenario_by_id(scenario_id),player_faction_id,_legacy_start_gold,true)
	Army.initialize(strategy_state,provinces,pending_transfer_orders,strategy.RECRUIT_UNIT_DEFS.merged(strategy.SPECIAL_UNIT_DEFS))
	Mobilization.initialize(strategy_state,provinces)
	Supply.ensure(strategy_state)
	Industry.normalize(strategy_state,provinces,strategy,year*12+month)
	officer_registry["clock_month"]=year*12+month
	if domestic_overlay!=null: domestic_overlay.hide()
	if recruitment_overlay!=null: recruitment_overlay.hide()
	if army_overlay!=null: army_overlay.hide()
	if politics_overlay!=null: politics_overlay.hide()
	if power_dialog!=null: power_dialog.hide()
	if playability_dialog!=null: playability_dialog.hide()
	if supply_overlay!=null: supply_overlay.hide()
	if industry_overlay!=null: industry_overlay.hide()
	pending_transfer_orders = OfficerRegistry.migrate_orders(officer_registry, pending_transfer_orders)
	_sync_officer_labels()
	if production_overlay != null:
		production_overlay.hide()
	_close_diplomacy()

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
	log_label.text = "%d년 %d월 · %s 저장 기록을 불러왔습니다." % [
		year,
		month,
		SEASONS[season_index],
	]
	var legacy_ending: bool=not strategy_state.has("campaign_ending")
	Ending.initialize(strategy_state,scenario_id,player_faction_id,year*12+month,int(_get_scenario_by_id(scenario_id).get("year",year))*12+1)
	if legacy_ending:
		strategy_state.campaign_ending.campaign_id=serialized_save.sha256_text().substr(0,32)
		strategy_state.campaign_ending.start_basis="legacy_scenario_january"
	ending_busy=false
	if not Ending.finished(strategy_state): _present_pending_choice(true)
	_sync_modal_map_input()
	evaluate_campaign_ending.call_deferred("load_complete")


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
	_sync_officer_labels()
	var mode_label: String = (
		"가상" if play_style == "fictional" else "역사"
	)
	date_label.text = (
		"%d년 %d월 · %s · %s · %s"
		% [
			year,
			month,
			SEASONS[season_index],
			mode_label,
			DIFFICULTY_NAMES.get(difficulty, "보통"),
		]
	)
	gold_label.text = "금: %d" % gold
	if strategy_state.has("faction_economy"):
		var account: Dictionary=strategy_state.faction_economy.accounts.get(player_faction_id,{})
		gold_label.tooltip_text="%s 국고 · 시작 %d + 수입 %d − 지출 %d = %d" % [player_faction,account.get("opening",0),account.get("income",0),account.get("expense",0),gold]
	food = _get_total_player_food_stock()
	food_label.text = "총 군량: %d" % food

func open_supply(city: String) -> void:
	if event_presentation!=null and event_presentation.active: return
	if not Economy.validate(strategy_state,provinces,player_faction_id,player_faction_id,city).ok: return
	transfer_panel.close_panel()
	production_overlay.hide(); diplomacy_overlay.hide(); domestic_overlay.hide(); recruitment_overlay.hide(); industry_overlay.hide()
	supply_overlay.open(self,city)
func open_army(city: String) -> void:
	if event_presentation!=null and event_presentation.active: return
	if not Economy.validate(strategy_state,provinces,player_faction_id,player_faction_id,city).ok: return
	recruitment_overlay.hide(); supply_overlay.hide(); industry_overlay.hide(); production_overlay.hide(); domestic_overlay.hide(); _close_diplomacy(); transfer_panel.close_panel()
	army_overlay.open(self,city)
func open_politics() -> void:
	for overlay: Control in [army_overlay,domestic_overlay,recruitment_overlay,industry_overlay,supply_overlay,production_overlay,diplomacy_overlay]:
		if overlay!=null: overlay.hide()
	map_area.hide_city_card(); province_panel.hide(); politics_overlay.open(self)

func open_campaign_brief() -> void:
	open_politics()
	politics_overlay.hide()
	playability_dialog.title="캠페인 목표·전쟁 준비·현재 지원 범위"
	if military_brief_details!=null: military_brief_details.hide()
	playability_dialog.get_label().show()
	playability_dialog.dialog_text=Playability.text(self)
	playability_dialog.popup_centered(Vector2i(1000,640))

func open_ai_military_brief() -> void:
	open_politics()
	politics_overlay.hide()
	playability_dialog.title="국가별 AI 군수·동원 계획"
	playability_dialog.dialog_text=""
	if military_brief_details==null:
		military_brief_details=RichTextLabel.new()
		military_brief_details.custom_minimum_size=Vector2(1400,700)
		military_brief_details.add_theme_font_size_override("normal_font_size",24)
		military_brief_details.scroll_active=true
		playability_dialog.add_child(military_brief_details)
	military_brief_details.text=MilitaryPlanning.text(self)
	military_brief_details.show(); military_brief_details.scroll_to_line(0)
	playability_dialog.get_label().hide()
	playability_dialog.popup_centered(Vector2i(1500,850))

func _ending_initialize() -> void:
	Power.bind(self)
	_power_ui_initialize()
	Ending.initialize(strategy_state,scenario_id,player_faction_id,year*12+month,year*12+month)
	ending_dialog=AcceptDialog.new()
	ending_dialog.title="캠페인 결과"
	ending_dialog.dialog_autowrap=true
	ending_dialog.get_ok_button().text="결과 닫기"
	add_child(ending_dialog)
	ending_dialog.add_button("결과 저장·재시도",false,"save")
	ending_dialog.add_button("다른 위치에 결과 저장",false,"save_as")
	ending_dialog.add_button("진행 저장 불러오기",false,"load")
	ending_dialog.add_button("새 캠페인",false,"new")
	ending_dialog.add_button("메인 화면",false,"title")
	ending_dialog.custom_action.connect(_ending_action)
	ending_dialog.visibility_changed.connect(_sync_modal_map_input)
	ending_load_dialog=FileDialog.new()
	ending_save_dialog=FileDialog.new()
	ending_save_dialog.file_mode=FileDialog.FILE_MODE_SAVE_FILE
	ending_save_dialog.access=FileDialog.ACCESS_FILESYSTEM
	ending_save_dialog.filters=PackedStringArray(["*.json ; 캠페인 종료 기록"])
	ending_save_dialog.current_dir=ProjectSettings.globalize_path("user://")
	add_child(ending_save_dialog)
	ending_save_dialog.file_selected.connect(func(path):
		ending_save_dialog.hide()
		save_ending_result(path)
		show_ending_result())
	ending_save_dialog.canceled.connect(func(): show_ending_result.call_deferred())
	ending_load_dialog.canceled.connect(func(): show_ending_result.call_deferred())
	ending_load_dialog.visibility_changed.connect(_sync_modal_map_input)
	ending_save_dialog.visibility_changed.connect(_sync_modal_map_input)
	ending_load_dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE
	ending_load_dialog.title="불러오기 · 캠페인 저장 선택"
	ending_load_dialog.display_mode=FileDialog.DISPLAY_LIST
	ending_load_dialog.access=FileDialog.ACCESS_FILESYSTEM
	ending_load_dialog.filters=PackedStringArray(["*.json ; 캠페인 저장"] )
	ending_load_dialog.current_dir=ProjectSettings.globalize_path("user://")
	add_child(ending_load_dialog)
	ending_load_dialog.file_selected.connect(func(path):
		_on_load_button_pressed(path)
		if Ending.finished(strategy_state): show_ending_result.call_deferred())
	navigation_menu.get_popup().add_item("저장 파일 선택",9)
	navigation_menu.get_popup().id_pressed.connect(func(id):
		if id==9: ending_load_dialog.popup_centered(Vector2i(1000,650)))
	navigation_menu.get_popup().add_item("캠페인 결과",10)
	navigation_menu.get_popup().id_pressed.connect(func(id):
		if id==10 and Ending.finished(strategy_state): show_ending_result())
	event_presentation.event_finished.connect(func(_id): evaluate_campaign_ending.call_deferred("presentation_complete"))
	evaluate_campaign_ending("initialization")

func evaluate_campaign_ending(source: String = "stable") -> Dictionary:
	if ending_busy or strategy_state.is_empty(): return {"status":"deferred"}
	if event_presentation!=null and event_presentation.active: return {"status":"deferred"}
	if not Ending.finished(strategy_state): CropFailure.cancel_if_unowned(crop_failure_events,provinces,player_faction)
	if not crop_failure_events.get("pending",{}).is_empty(): return {"status":"deferred"}
	var pending: Dictionary=officer_registry.get("politics",{}).get("pending",{})
	if not pending.is_empty() and pending.get("faction_id",player_faction_id)==player_faction_id: return {"status":"deferred"}
	MilitaryPlanning.Network.invalidate(self)
	var evaluation: Dictionary=Ending.evaluate(strategy_state,provinces)
	if evaluation.status=="configuration_error":
		log_label.text="캠페인 목표 설정 오류: "+evaluation.reason
		return evaluation
	var changed: bool=Ending.confirm(strategy_state,provinces,year*12+month,source)
	if Ending.finished(strategy_state):
		attack_source_id=""
		end_turn_button.disabled=true
		if changed: ending_save_message="전용 종료 저장 대기"
		if changed: save_ending_result()
		show_ending_result()
	return evaluation

# Player battle presentation is itself deferred by resolve_attack. Queue the
# check behind it; AI battles still finish the synchronous monthly settlement.
func _queue_ending_check(source: String) -> void:
	evaluate_campaign_ending.call_deferred(source)

func show_ending_result() -> void:
	if ending_dialog==null or not Ending.finished(strategy_state): return
	if event_presentation!=null and event_presentation.active: return
	open_politics()
	politics_overlay.hide()
	ending_dialog.title="승리" if strategy_state.campaign_ending.status=="victory" else "패배"
	ending_dialog.dialog_text=Ending.result_text(strategy_state)+"\n\n"+ending_save_message
	ending_dialog.popup_centered(Vector2i(1100,650))
	_sync_modal_map_input()

func save_ending_result(path_override: String = "") -> bool:
	if not Ending.finished(strategy_state): return false
	var directory: String="user://campaign_endings"
	var error: Error=DirAccess.make_dir_recursive_absolute(directory)
	var path: String=directory+"/"+str(strategy_state.campaign_ending.result.result_id).replace(":","-")+".json"
	if not path_override.is_empty(): path=path_override
	if error!=OK and path_override.is_empty():
		ending_save_message="종료 저장 실패: "+error_string(error)+". 결과 저장으로 재시도하세요."
		return false
	if ProjectSettings.globalize_path(path)==ProjectSettings.globalize_path(SAVE_PATH):
		ending_save_message="수동 저장은 종료 기록으로 덮어쓰지 않습니다."
		return false
	if FileAccess.file_exists(path):
		var prior: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not prior is Dictionary or prior.get("strategy_state",{}).get("campaign_ending",{}).get("result",{}).get("result_id","")!=strategy_state.campaign_ending.result.result_id:
			ending_save_message="기존 수동 저장 또는 다른 캠페인 기록은 덮어쓰지 않습니다. 새 파일 이름을 선택하세요."
			return false
	var temporary: String=path+"."+Crypto.new().generate_random_bytes(8).hex_encode()+".tmp"
	var saved: bool=_write_campaign_save(temporary)
	if saved:
		var replace_error: Error=DirAccess.rename_absolute(temporary,path)
		saved=replace_error==OK
	ending_save_message=("종료 저장 완료: "+path) if saved else "종료 저장 실패. 현재 결과를 유지합니다. 결과 저장으로 재시도하세요."
	return saved

func _ending_action(action: StringName) -> void:
	match str(action):
		"save":
			save_ending_result()
			show_ending_result()
		"load":
			ending_dialog.hide()
			ending_load_dialog.popup_centered(Vector2i(1000,650))
		"save_as":
			ending_dialog.hide()
			ending_save_dialog.current_file=str(strategy_state.campaign_ending.result.result_id).replace(":","-")+".json"
			ending_save_dialog.popup_centered(Vector2i(1000,650))
		"new": _on_navigation_requested.call_deferred("setup")
		"title": _on_navigation_requested.call_deferred("title")
func _power_ui_initialize() -> void:
	if power_dialog!=null: return
	power_dialog=AcceptDialog.new(); power_dialog.title="권력 인계 협의"; power_dialog.dialog_autowrap=true; add_child(power_dialog)
	power_dialog.visibility_changed.connect(_sync_modal_map_input)
	power_dialog.add_button("A 보상·즉시 인계",false,"compensate").set_meta("power_choice","compensate")
	power_dialog.add_button("B 기한 보장",false,"wait").set_meta("power_choice","wait")
	power_dialog.add_button("C 강제 회수",false,"force").set_meta("power_choice","force")
	power_dialog.add_button("협의 철회",false,"withdraw").set_meta("power_choice","withdraw")
	power_dialog.get_ok_button().text="닫기·권한 유지"
	power_dialog.custom_action.connect(func(choice):
		var result: Dictionary=Power.resolve(self,power_request_id,choice)
		log_label.text=str(result.get("reason","")); show_power_transfer(power_request_id))
	power_successors=OptionButton.new(); power_dialog.add_child(power_successors); power_successors.position=Vector2(24,440); power_successors.size=Vector2(650,34)
	power_successors.item_selected.connect(func(index):
		if index<=0: return
		var result: Dictionary=Power.retarget(self,power_request_id,str(power_successors.get_item_metadata(index)))
		log_label.text=str(result.get("reason","")); show_power_transfer(power_request_id))
	navigation_menu.get_popup().add_item("권력 인계·차질 현황",8)
	navigation_menu.get_popup().id_pressed.connect(func(id):
		if id==8 and not event_presentation.active: show_power_transfer(""))
func show_power_transfer(id: String) -> void:
	if power_dialog==null or Ending.finished(strategy_state): return
	if event_presentation!=null and event_presentation.active:
		power_request_id=id
		if not event_presentation.event_finished.is_connected(_show_deferred_power): event_presentation.event_finished.connect(_show_deferred_power,CONNECT_ONE_SHOT)
		return
	var requests: Dictionary=Power.records(strategy_state).get("requests",{})
	if id.is_empty():
		for key: String in requests:
			if requests[key].status in ["offered","waiting","successor_needed"]: id=key; break
	if id.is_empty() and not requests.is_empty(): id=str(requests.keys().back())
	var row: Dictionary=requests.get(id,{})
	if row.is_empty(): log_label.text="진행 중인 권력 인계 협의가 없습니다."; return
	power_request_id=id
	for overlay: Control in [politics_overlay,army_overlay,domestic_overlay,industry_overlay,production_overlay,diplomacy_overlay]:
		if overlay!=null: overlay.hide()
	power_dialog.dialog_text=Power.describe(self,row)
	for button: Node in power_dialog.find_children("*","Button",true,false):
		if button.has_meta("power_choice"): button.disabled=row.status not in ["offered","waiting","successor_needed"] or (button.get_meta("power_choice")=="wait" and row.status!="offered")
	power_successors.clear(); power_successors.add_item("후임 재지정 (기존 인계 기한 유지)")
	power_successors.visible=row.status in ["waiting","successor_needed"] and row.request.kind in ["governor","commander"]
	if power_successors.visible:
		power_successors.add_item("공석으로 인계"); power_successors.set_item_metadata(1,"")
		var successor_city: String=row.city if row.request.kind=="governor" else str(strategy_state.unit_rosters.get(row.request.target,{}).get("location",row.city))
		for person: String in get_city_officer_ids(successor_city):
			power_successors.add_item(get_officer(person).name); power_successors.set_item_metadata(power_successors.item_count-1,person)
	power_dialog.popup_centered(Vector2i(1050,650))

func _show_deferred_power(_event_id: String) -> void:
	show_power_transfer.call_deferred(power_request_id)
