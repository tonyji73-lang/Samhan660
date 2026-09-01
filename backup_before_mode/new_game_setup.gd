extends Control

const ScenarioData = preload("res://scenario_data.gd")

@export_group("Project Paths")
@export_file("*.tscn") var title_scene_path: String = (
	"res://title_screen.tscn"
)
@export_file("*.tscn") var campaign_scene_path: String = (
	"res://campaign_main.tscn"
)

@export_group("Optional Background")
@export var background_texture: Texture2D
@export var campaign_map_texture: Texture2D

@export_group("Optional Audio")
# Inspector에서 직접 지정하고 싶으면 여기에 오디오를 끌어다 놓으면 됩니다.
# 비워두면 DEFAULT_SETUP_MUSIC_PATH 경로에서 자동으로 불러옵니다.
@export var setup_music: AudioStream
@export_range(-40.0, 6.0, 0.5) var setup_music_volume_db: float = -8.0


# campaign_main.gd의 FACTION_ID_TO_NAME / PLAY_STYLE_NAMES / DIFFICULTY_NAMES와
# id 값이 반드시 일치해야 한다 (여기서 만든 id를 그대로 meta로 넘겨준다).
const FACTION_ORDER: Array[String] = ["silla", "baekje", "goguryeo"]
const FACTION_NAMES: Dictionary = {
	"silla": "신라",
	"baekje": "백제",
	"goguryeo": "고구려",
}
const FACTION_DESCRIPTIONS: Dictionary = {
	"silla": "가장 약소하나 외교와 인내로 결국 삼국을 통일하는 나라입니다.",
	"baekje": "가장 먼저 존망의 위기를 맞습니다. 초반부터 치열한 방어전이 필요합니다.",
	"goguryeo": "가장 넓은 영토와 강력한 군사력을 가진 북방의 강자입니다.",
}
const FACTION_UI_DATA: Dictionary = {
	"silla": {
		"ruler": "태종무열왕 김춘추",
		"commander": "김유신",
		"capital": "금성",
		"territories": "금성 · 사벌주 · 국원소경",
		"troops": 66000,
		"faction_difficulty": "보통",
		"strength": "외교와 인재 운용",
		"risk": "당 의존과 다면전",
		"notable": "김춘추 · 김유신 · 김법민 · 김흠순",
		"color": Color("#d2a62f"),
		"portrait_paths": [
			"res://assets/portraits/kim_yushin.png",
			"res://assets/portraits/kim_chunchu.png",
		],
	},
	"baekje": {
		"ruler": "의자왕",
		"commander": "계백",
		"capital": "사비성",
		"territories": "사비성 · 웅진성 · 고사성",
		"troops": 57000,
		"faction_difficulty": "어려움",
		"strength": "요새 방어와 해상 교류",
		"risk": "초기 침공과 내부 분열",
		"notable": "의자왕 · 계백 · 흑치상지 · 성충",
		"color": Color("#a64035"),
		"portrait_paths": [
			"res://assets/portraits/gyebaek.png",
			"res://assets/portraits/uija_wang.png",
		],
	},
	"goguryeo": {
		"ruler": "보장왕",
		"commander": "연개소문",
		"capital": "평양성",
		"territories": "평양성 · 국내성 · 안시성",
		"troops": 100000,
		"faction_difficulty": "보통",
		"strength": "강한 군사력과 산성",
		"risk": "후계 갈등과 당의 압박",
		"notable": "보장왕 · 연개소문 · 양만춘 · 고연무",
		"color": Color("#3d5f86"),
		"portrait_paths": [
			"res://assets/portraits/yeon_gaesomun.png",
			"res://assets/portraits/bojang_wang.png",
		],
	},
}

const DIFFICULTY_ORDER: Array[String] = ["easy", "normal", "hard"]
const DIFFICULTY_NAMES: Dictionary = {
	"easy": "쉬움",
	"normal": "보통",
	"hard": "어려움",
}
const DIFFICULTY_DESCRIPTIONS: Dictionary = {
	"easy": "시작 자원이 늘어나고 적 세력이 더 약하게 성장합니다.",
	"normal": "표준적인 난이도입니다.",
	"hard": "적 세력이 더 빠르게 병력을 모으고 더 공격적으로 움직입니다.",
}

const PLAY_STYLE_ORDER: Array[String] = ["historical", "fictional"]
const PLAY_STYLE_NAMES: Dictionary = {
	"historical": "역사적 게임플레이",
	"fictional": "가상 게임플레이",
}
const PLAY_STYLE_DESCRIPTIONS: Dictionary = {
	"historical": "AI 세력은 항상 플레이어만을 노립니다. 실제 역사의 흐름에 가깝게 진행됩니다.",
	"fictional": "AI 세력들끼리도 서로 전쟁을 벌일 수 있습니다. 예측할 수 없는 삼국지가 펼쳐집니다.",
}

const SEASON_NAMES: Dictionary = {
	"spring": "봄",
	"summer": "여름",
	"autumn": "가을",
	"winter": "겨울",
}

# 실제 역사에서 정세가 크게 갈리는 5개 시점. 시나리오를 고르면 연도/계절은
# 자동으로 정해지고 따로 조절할 수 없다 (예전엔 SpinBox로 직접 만질 수
# 있었지만, 시나리오 단위 선택으로 정리했다).
const SCENARIOS: Array[Dictionary] = [
	{
		"id": "silla_equilibrium_632",
		"name": "632년, 선덕여왕 즉위",
		"description": (
			"신라 최초의 여왕 선덕여왕이 즉위합니다. 아직 세 나라가 팽팽히 "
			+ "맞서던 균형기로, 이후의 역사가 어떻게 흘러갈지는 플레이어의 "
			+ "선택에 달려 있습니다."
		),
		"year": 632,
		"season": "spring",
	},
	{
		"id": "goguryeo_coup_642",
		"name": "642년, 연개소문의 정변",
		"description": (
			"연개소문이 정변을 일으켜 영류왕을 시해하고 보장왕을 세워 "
			+ "대막리지에 오릅니다. 같은 해 백제와 고구려가 손잡고 신라의 "
			+ "대야성을 함락시키며 정세가 급격히 요동칩니다."
		),
		"year": 642,
		"season": "summer",
	},
	{
		"id": "baekje_fall_660",
		"name": "660년, 백제 멸망 전야",
		"description": (
			"나당 연합군의 공격을 앞둔 660년 봄. "
			+ "세 나라의 운명이 크게 갈리기 시작하는 해입니다."
		),
		"year": 660,
		"season": "spring",
	},
	{
		"id": "baekgang_663",
		"name": "663년, 백강 전투 전야",
		"description": (
			"백제부흥군이 왜(倭)의 지원을 받아 나당연합군에 맞서고 "
			+ "있습니다. 백강 하구에서 벌어질 대해전이 동아시아의 판도를 "
			+ "다시 한번 뒤흔들 것입니다."
		),
		"year": 663,
		"season": "autumn",
	},
	{
		"id": "silla_tang_war_670",
		"name": "670년, 나당전쟁 발발",
		"description": (
			"고구려마저 무너진 지 2년, 신라는 이제 옛 동맹이었던 당나라를 "
			+ "상대로 창끝을 돌립니다. 한반도에서 당의 세력을 몰아내기 "
			+ "위한 마지막 전쟁이 시작됩니다."
		),
		"year": 670,
		"season": "spring",
	},
]

# 나중에 실제 오디오 파일을 res://assets/audio/setup_theme.mp3 에 넣으면
# Inspector 설정 없이도 자동으로 재생된다. (title_screen.gd와 동일한 방식)
const DEFAULT_SETUP_MUSIC_PATH: String = "res://assets/audio/setup_theme.mp3"
const MUSIC_FADE_IN_SECONDS: float = 1.2
const MUSIC_FADE_OUT_SECONDS: float = 0.4
const MUSIC_SILENT_DB: float = -40.0

# background_texture는 씬마다 따로 지정하는 Export 변수라서 title_screen.tscn에
# 지정해둔 배경이 이 화면으로 자동으로 넘어오지 않는다. Inspector를 비워두면
# 아래 경로에서 자동으로 불러온다 (title_screen과 같은 이미지를 쓰고 싶으면
# 이 경로에 그 파일을 두거나, Inspector에서 직접 지정하면 된다).
const DEFAULT_BACKGROUND_TEXTURE_PATH: String = (
	"res://assets/backgrounds/title_bg.png"
)
const DEFAULT_CAMPAIGN_MAP_PATH: String = (
	"res://assets/maps/samhan660_korea_focus_map_8192x4608.png"
)

const MAP_MIN_ZOOM: float = 1.0
const MAP_MAX_ZOOM: float = 5.0
const MAP_ZOOM_STEP: float = 1.18
const MAP_DETAIL_ZOOM: float = 1.45
const PROVINCE_MAP_UV: Dictionary = {
	"ansi": Vector2(0.455, 0.285),
	"gungnae": Vector2(0.575, 0.190),
	"pyongyang": Vector2(0.550, 0.360),
	"ungjin": Vector2(0.555, 0.615),
	"sabi": Vector2(0.545, 0.650),
	"gosa": Vector2(0.515, 0.710),
	"gukwon": Vector2(0.600, 0.560),
	"sabeol": Vector2(0.610, 0.660),
	"geumseong": Vector2(0.665, 0.720),
}
const PROVINCE_BASE_NAMES: Dictionary = {
	"ansi": "안시성",
	"gungnae": "국내성",
	"pyongyang": "평양성",
	"ungjin": "웅진성",
	"sabi": "사비성",
	"gosa": "고사성",
	"gukwon": "국원소경",
	"sabeol": "사벌주",
	"geumseong": "금성",
}
const MAP_ROADS: Array = [
	["ansi", "gungnae"],
	["gungnae", "pyongyang"],
	["pyongyang", "ungjin"],
	["pyongyang", "gukwon"],
	["ungjin", "sabi"],
	["ungjin", "gukwon"],
	["sabi", "gosa"],
	["sabi", "geumseong"],
	["gosa", "geumseong"],
	["gukwon", "sabeol"],
	["sabeol", "geumseong"],
]


var selected_faction_id: String = "silla"
var selected_difficulty_id: String = "normal"
var selected_play_style_id: String = "historical"
var selected_season_id: String = "spring"
var selected_scenario_index: int = 0

var menu_locked: bool = false

var background_rect: TextureRect
var fade_rect: ColorRect
var music_player: AudioStreamPlayer

var scenario_option: OptionButton
var scenario_group: ButtonGroup
var scenario_buttons: Dictionary = {}
var scenario_title_label: Label
var scenario_description_label: Label

var faction_group: ButtonGroup
var faction_buttons: Dictionary = {}
var faction_cards_vbox: VBoxContainer
var faction_guide_label: Label
var faction_description_label: Label
var map_marker_buttons: Dictionary = {}
var map_canvas: Control
var map_world: Control
var map_texture_rect: TextureRect
var map_detail_layer: Control
var map_road_lines: Array[Line2D] = []
var map_city_labels: Dictionary = {}
var map_zoom: float = MAP_MIN_ZOOM
var map_dragging: bool = false
var map_drag_last_position: Vector2 = Vector2.ZERO
var leader_portrait: TextureRect
var portrait_fallback_label: Label
var faction_name_label: Label
var ruler_label: Label
var commander_label: Label
var capital_label: Label
var territories_label: Label
var power_label: Label
var faction_difficulty_label: Label
var strength_label: Label
var risk_label: Label
var notable_characters_label: Label

var play_style_group: ButtonGroup
var play_style_buttons: Dictionary = {}
var play_style_description_label: Label

var difficulty_group: ButtonGroup
var difficulty_buttons: Dictionary = {}
var difficulty_description_label: Label

var scenario_date_label: Label

var back_button: Button
var start_button: Button
var status_label: Label


func _ready() -> void:
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_interface()
	_apply_background_texture()
	_apply_scenario_defaults(selected_scenario_index)
	_update_faction_details()
	_start_music()
	call_deferred("_play_intro")


func _unhandled_input(event: InputEvent) -> void:
	if menu_locked:
		return

	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

# ==========================================
# UI 구성
# ==========================================

func _build_interface() -> void:
	_build_background()
	_build_scroll_content()
	_build_fade_layer()
	_build_music_player()


func _build_background() -> void:
	background_rect = TextureRect.new()
	background_rect.name = "Background"
	background_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_rect)

	var tone_overlay: ColorRect = ColorRect.new()
	tone_overlay.name = "ToneOverlay"
	tone_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tone_overlay.color = Color(0.72, 0.67, 0.57, 0.54)
	tone_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tone_overlay)


func _apply_background_texture() -> void:
	if background_texture == null:
		background_texture = _load_default_background_texture()

	background_rect.texture = background_texture

	if background_texture == null:
		status_label.text = (
			"Inspector에서 Background Texture를 지정하세요."
		)


func _load_default_background_texture() -> Texture2D:
	if not ResourceLoader.exists(DEFAULT_BACKGROUND_TEXTURE_PATH):
		return null

	var loaded_resource: Resource = load(DEFAULT_BACKGROUND_TEXTURE_PATH)

	if loaded_resource is Texture2D:
		return loaded_resource as Texture2D

	push_warning(
		"NewGameSetup: %s는 텍스처 리소스가 아닙니다."
		% DEFAULT_BACKGROUND_TEXTURE_PATH
	)
	return null


func _build_scroll_content() -> void:
	var screen_margin: MarginContainer = MarginContainer.new()
	screen_margin.name = "ScreenMargin"
	screen_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_margin.add_theme_constant_override("margin_left", 12)
	screen_margin.add_theme_constant_override("margin_top", 6)
	screen_margin.add_theme_constant_override("margin_right", 12)
	screen_margin.add_theme_constant_override("margin_bottom", 4)
	add_child(screen_margin)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "SetupPanel"
	panel.custom_minimum_size = Vector2(1060.0, 600.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	screen_margin.add_child(panel)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.name = "SetupVBox"
	root_vbox.add_theme_constant_override("separation", 6)
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(root_vbox)

	root_vbox.add_child(_build_title_block())

	var main_row: HBoxContainer = HBoxContainer.new()
	main_row.name = "CampaignSelection"
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 12)
	main_row.add_child(_build_faction_block())
	main_row.add_child(_build_map_block())
	main_row.add_child(_build_profile_block())
	root_vbox.add_child(main_row)

	root_vbox.add_child(_build_options_block())
	root_vbox.add_child(_build_footer_block())


func _build_title_block() -> Control:
	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size = Vector2(0.0, 42.0)
	header.add_theme_constant_override("separation", 10)

	back_button = _create_menu_button("← 뒤로", "BackButton")
	back_button.custom_minimum_size = Vector2(92.0, 36.0)
	back_button.pressed.connect(_on_back_pressed)
	header.add_child(back_button)

	var campaign_title: Label = Label.new()
	campaign_title.text = "새 캠페인"
	campaign_title.custom_minimum_size = Vector2(155.0, 36.0)
	campaign_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	campaign_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	campaign_title.add_theme_font_size_override("font_size", 22)
	campaign_title.add_theme_color_override("font_color", Color("#211d16"))
	campaign_title.add_theme_stylebox_override(
		"normal",
		_create_light_box_style(Color("#f0eadc"), Color("#211d16"), 2)
	)
	header.add_child(campaign_title)

	scenario_title_label = Label.new()
	scenario_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scenario_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scenario_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	scenario_title_label.add_theme_font_size_override("font_size", 22)
	scenario_title_label.add_theme_color_override("font_color", Color("#f4ead4"))
	scenario_title_label.add_theme_color_override(
		"font_outline_color",
		Color("#17130e")
	)
	scenario_title_label.add_theme_constant_override("outline_size", 6)
	scenario_title_label.add_theme_stylebox_override(
		"normal",
		_create_light_box_style(Color("#211d17"), Color("#211d17"), 0)
	)
	header.add_child(scenario_title_label)

	var game_title: Label = Label.new()
	game_title.text = "삼한 660"
	game_title.custom_minimum_size = Vector2(120.0, 0.0)
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	game_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	game_title.add_theme_font_size_override("font_size", 18)
	game_title.add_theme_color_override("font_color", Color("#2a241b"))
	header.add_child(game_title)

	return header


func _build_scenario_block() -> Control:
	var timeline_panel: PanelContainer = PanelContainer.new()
	timeline_panel.custom_minimum_size = Vector2(0.0, 84.0)
	timeline_panel.add_theme_stylebox_override(
		"panel",
		_create_light_box_style(Color("#e8dfcc"), Color("#3a3328"), 1)
	)

	var timeline_vbox: VBoxContainer = VBoxContainer.new()
	timeline_vbox.add_theme_constant_override("separation", 2)
	timeline_panel.add_child(timeline_vbox)

	var timeline_row: HBoxContainer = HBoxContainer.new()
	timeline_row.alignment = BoxContainer.ALIGNMENT_CENTER
	timeline_row.add_theme_constant_override("separation", 6)
	timeline_vbox.add_child(timeline_row)

	scenario_group = ButtonGroup.new()
	for index: int in range(ScenarioData.SCENARIOS.size()):
		var scenario: Dictionary = ScenarioData.SCENARIOS[index]
		var button: Button = _create_timeline_button(
			"%d년" % int(scenario["year"])
		)
		button.button_group = scenario_group
		button.button_pressed = index == selected_scenario_index
		button.pressed.connect(_on_scenario_selected.bind(index))
		timeline_row.add_child(button)
		scenario_buttons[index] = button

	scenario_description_label = _create_description_label("")
	scenario_description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scenario_description_label.max_lines_visible = 2
	timeline_vbox.add_child(scenario_description_label)

	scenario_date_label = Label.new()
	scenario_date_label.name = "ScenarioDateLabel"
	scenario_date_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scenario_date_label.add_theme_font_size_override("font_size", 12)
	scenario_date_label.add_theme_color_override("font_color", Color("#7a2f25"))
	timeline_vbox.add_child(scenario_date_label)

	return timeline_panel


func _build_faction_block() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "FactionPanel"
	panel.custom_minimum_size = Vector2(220.0, 0.0)
	panel.add_theme_stylebox_override(
		"panel",
		_create_light_box_style(Color("#e9e1d2"), Color("#29241c"), 1)
	)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	panel.add_child(vbox)
	vbox.add_child(_create_section_label("플레이 세력"))

	faction_cards_vbox = VBoxContainer.new()
	faction_cards_vbox.add_theme_constant_override("separation", 7)
	vbox.add_child(faction_cards_vbox)

	faction_guide_label = _create_description_label("")
	faction_guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(faction_guide_label)

	return panel


func _build_map_block() -> Control:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.name = "MapColumn"
	vbox.custom_minimum_size = Vector2(430.0, 0.0)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 5)

	var map_panel: PanelContainer = PanelContainer.new()
	map_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_theme_stylebox_override("panel", _create_map_panel_style())
	vbox.add_child(map_panel)

	map_canvas = Control.new()
	map_canvas.name = "FactionMap"
	map_canvas.custom_minimum_size = Vector2(420.0, 275.0)
	map_canvas.clip_contents = true
	map_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	map_canvas.mouse_default_cursor_shape = Control.CURSOR_DRAG
	map_canvas.gui_input.connect(_on_map_gui_input)
	map_panel.add_child(map_canvas)

	map_world = Control.new()
	map_world.name = "MapWorld"
	map_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_canvas.add_child(map_world)

	map_texture_rect = TextureRect.new()
	map_texture_rect.name = "MapTexture"
	map_texture_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	map_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_texture_rect.texture = _load_campaign_map_texture()
	map_world.add_child(map_texture_rect)

	var map_tone: ColorRect = ColorRect.new()
	map_tone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_tone.color = Color(0.83, 0.77, 0.63, 0.12)
	map_tone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_world.add_child(map_tone)

	map_detail_layer = Control.new()
	map_detail_layer.name = "MapDetails"
	map_detail_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_detail_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_world.add_child(map_detail_layer)
	_build_map_details()

	var map_help: Label = _create_description_label(
		"휠: 확대/축소  ·  빈 지도 드래그: 이동"
	)
	map_help.position = Vector2(8.0, 8.0)
	map_help.size = Vector2(330.0, 26.0)
	map_help.custom_minimum_size = Vector2(330.0, 26.0)
	map_help.autowrap_mode = TextServer.AUTOWRAP_OFF
	map_help.add_theme_color_override("font_color", Color.WHITE)
	map_help.add_theme_color_override("font_outline_color", Color("#241b12"))
	map_help.add_theme_constant_override("outline_size", 5)
	map_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_help.z_index = 50
	map_canvas.add_child(map_help)

	map_canvas.resized.connect(_on_map_canvas_resized)

	vbox.add_child(_build_scenario_block())
	return vbox


func _build_profile_block() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "ProfilePanel"
	panel.custom_minimum_size = Vector2(290.0, 0.0)
	panel.add_theme_stylebox_override(
		"panel",
		_create_light_box_style(Color("#eee7da"), Color("#29241c"), 1)
	)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var portrait_panel: PanelContainer = PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(0.0, 108.0)
	portrait_panel.add_theme_stylebox_override(
		"panel",
		_create_light_box_style(Color("#d8cebb"), Color("#6c5c43"), 1)
	)
	vbox.add_child(portrait_panel)

	var portrait_canvas: Control = Control.new()
	portrait_panel.add_child(portrait_canvas)
	leader_portrait = TextureRect.new()
	leader_portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	leader_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	leader_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	leader_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_canvas.add_child(leader_portrait)

	portrait_fallback_label = Label.new()
	portrait_fallback_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait_fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_fallback_label.add_theme_font_size_override("font_size", 40)
	portrait_canvas.add_child(portrait_fallback_label)

	faction_name_label = Label.new()
	faction_name_label.add_theme_font_size_override("font_size", 25)
	vbox.add_child(faction_name_label)

	ruler_label = _create_profile_label()
	vbox.add_child(ruler_label)
	commander_label = _create_profile_label()
	vbox.add_child(commander_label)
	capital_label = _create_profile_label()
	vbox.add_child(capital_label)
	territories_label = _create_profile_label()
	territories_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(territories_label)
	power_label = _create_profile_label()
	vbox.add_child(power_label)
	faction_difficulty_label = _create_profile_label()
	vbox.add_child(faction_difficulty_label)
	strength_label = _create_profile_label()
	vbox.add_child(strength_label)
	risk_label = _create_profile_label()
	vbox.add_child(risk_label)

	var separator: HSeparator = HSeparator.new()
	vbox.add_child(separator)

	faction_description_label = _create_description_label("")
	faction_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	faction_description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(faction_description_label)

	var notable_label: Label = _create_section_label("주요 인물")
	notable_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(notable_label)
	notable_characters_label = _create_description_label("")
	notable_characters_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(notable_characters_label)

	return panel


func _build_play_style_block() -> Control:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(_create_section_label("플레이 스타일"))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	play_style_group = ButtonGroup.new()

	for play_style_id in PLAY_STYLE_ORDER:
		var button: Button = _create_choice_button(
			str(PLAY_STYLE_NAMES[play_style_id]),
			play_style_group
		)
		button.button_pressed = (play_style_id == selected_play_style_id)
		button.toggled.connect(
			_on_play_style_toggled.bind(play_style_id)
		)
		row.add_child(button)
		play_style_buttons[play_style_id] = button

	play_style_description_label = _create_description_label(
		str(PLAY_STYLE_DESCRIPTIONS.get(selected_play_style_id, ""))
	)
	vbox.add_child(play_style_description_label)

	return vbox


func _build_difficulty_block() -> Control:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 3)
	vbox.add_child(_create_section_label("난이도"))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	difficulty_group = ButtonGroup.new()

	for difficulty_id in DIFFICULTY_ORDER:
		var button: Button = _create_choice_button(
			str(DIFFICULTY_NAMES[difficulty_id]),
			difficulty_group
		)
		button.button_pressed = (difficulty_id == selected_difficulty_id)
		button.toggled.connect(
			_on_difficulty_toggled.bind(difficulty_id)
		)
		row.add_child(button)
		difficulty_buttons[difficulty_id] = button

	difficulty_description_label = _create_description_label(
		str(DIFFICULTY_DESCRIPTIONS.get(selected_difficulty_id, ""))
	)
	vbox.add_child(difficulty_description_label)

	return vbox


func _build_options_block() -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		_create_light_box_style(Color("#e8dfcf"), Color("#3a3328"), 1)
	)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.add_child(_build_play_style_block())
	row.add_child(_build_difficulty_block())
	panel.add_child(row)
	return panel


func _build_footer_block() -> Control:
	var button_row: HBoxContainer = HBoxContainer.new()
	button_row.custom_minimum_size = Vector2(0.0, 36.0)
	button_row.add_theme_constant_override("separation", 12)

	status_label = Label.new()
	status_label.name = "StatusLabel"
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color("#6f2a22"))
	button_row.add_child(status_label)

	start_button = _create_menu_button("선택한 역사 시작", "StartButton")
	start_button.custom_minimum_size = Vector2(220.0, 36.0)
	start_button.pressed.connect(_on_start_pressed)
	button_row.add_child(start_button)

	return button_row


func _create_faction_card(data: Dictionary) -> Button:
	var faction_id: String = str(data.get("id", "silla"))
	var faction_color: Color = Color(str(data.get("color", "#d2a62f")))
	var ruler_name: String = str(data.get("ruler", ""))
	var ruler_title: String = str(data.get("ruler_title", ""))
	var ruler_display: String = ruler_name
	if ruler_title != "":
		ruler_display = "%s %s" % [ruler_title, ruler_name]
	var button: Button = Button.new()
	button.name = "%sFactionButton" % faction_id.capitalize()
	button.text = "%s\n%s · %s" % [
		str(data.get("name", "신라")),
		ruler_display,
		ScenarioData.get_age_text(ruler_name, _get_scenario_year()),
	]
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0.0, 82.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 58)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("#312a20"))
	button.add_theme_color_override("font_hover_color", Color("#17130e"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)

	var portrait: Texture2D = _load_first_texture(data["portrait_paths"])
	if portrait != null:
		button.icon = portrait

	button.add_theme_stylebox_override(
		"normal",
		_create_light_box_style(Color("#f3ede2"), Color("#80715a"), 1)
	)
	button.add_theme_stylebox_override(
		"hover",
		_create_light_box_style(Color("#fffaf0"), faction_color, 2)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_create_light_box_style(faction_color.darkened(0.34), faction_color, 3)
	)
	return button


func _create_map_marker(
	data: Dictionary
) -> void:
	var faction_id: String = str(data.get("id", "silla"))
	var marker: Button = Button.new()
	marker.name = "%sMapMarker" % faction_id.capitalize()
	marker.text = "%s\n%s" % [
		str(data.get("name", "")),
		str(data.get("marker_label", data.get("capital", ""))),
	]
	marker.custom_minimum_size = Vector2(98.0, 48.0)
	marker.pivot_offset = Vector2(49.0, 24.0)
	marker.set_meta("map_uv", data.get("marker_uv", Vector2(0.5, 0.5)))
	marker.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	marker.add_theme_font_size_override("font_size", 12)
	marker.pressed.connect(_select_faction_from_map.bind(faction_id))
	map_marker_buttons[faction_id] = marker
	map_world.add_child(marker)


func _create_profile_label() -> Label:
	var label: Label = Label.new()
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#3e3529"))
	return label


func _create_timeline_button(button_text: String) -> Button:
	var button: Button = Button.new()
	button.text = button_text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(72.0, 30.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", Color("#3c3429"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override(
		"normal",
		_create_light_box_style(Color("#f6efe2"), Color("#766853"), 1)
	)
	button.add_theme_stylebox_override(
		"hover",
		_create_light_box_style(Color("#fffaf0"), Color("#8f3c2e"), 2)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_create_light_box_style(Color("#8f3c2e"), Color("#3f1914"), 2)
	)
	return button


func _load_campaign_map_texture() -> Texture2D:
	if campaign_map_texture != null:
		return campaign_map_texture

	var fallback_paths: Array[String] = [
		DEFAULT_CAMPAIGN_MAP_PATH,
		"res://campaign_map_9_regions.png",
		"res://campaign_map.png",
	]

	for path: String in fallback_paths:
		if not ResourceLoader.exists(path):
			continue
		var loaded_resource: Resource = load(path)
		if loaded_resource is Texture2D:
			return loaded_resource as Texture2D

	return null


func _load_first_texture(paths_value: Variant) -> Texture2D:
	if typeof(paths_value) != TYPE_ARRAY:
		return null

	var paths: Array = paths_value
	for path_value: Variant in paths:
		var path: String = str(path_value)
		if not ResourceLoader.exists(path):
			continue
		var loaded_resource: Resource = load(path)
		if loaded_resource is Texture2D:
			return loaded_resource as Texture2D

	return null


func _select_faction_from_map(faction_id: String) -> void:
	if not faction_buttons.has(faction_id):
		return
	selected_faction_id = faction_id
	var faction_button: Button = faction_buttons[faction_id]
	faction_button.button_pressed = true
	_update_faction_details()


func _update_faction_details() -> void:
	var data: Dictionary = _get_selected_faction_data()
	if data.is_empty():
		return

	var faction_color: Color = Color(str(data.get("color", "#d2a62f")))
	var scenario_year: int = _get_scenario_year()
	var ruler_name: String = str(data.get("ruler", ""))
	var commander_name: String = str(data.get("commander", ""))
	var ruler_title: String = str(data.get("ruler_title", ""))
	var ruler_display: String = ruler_name
	if ruler_title != "":
		ruler_display = "%s %s" % [ruler_title, ruler_name]

	faction_name_label.text = str(data.get("name", "신라"))
	faction_name_label.add_theme_color_override("font_color", faction_color.darkened(0.25))
	ruler_label.text = "군주  ·  %s (%s)" % [
		ruler_display,
		ScenarioData.get_age_text(ruler_name, scenario_year),
	]
	commander_label.text = "총사령관  ·  %s (%s)" % [
		commander_name,
		ScenarioData.get_age_text(commander_name, scenario_year),
	]
	capital_label.text = "수도  ·  %s" % data["capital"]
	territories_label.text = "초기 영지  ·  %s" % data["territories"]
	power_label.text = "기본 병력  ·  %s" % _format_number(int(data["troops"]))
	faction_difficulty_label.text = (
		"세력 난이도  ·  %s" % data["faction_difficulty"]
	)
	faction_difficulty_label.add_theme_color_override(
		"font_color",
		faction_color.darkened(0.20)
	)
	strength_label.text = "강점  ·  %s" % data["strength"]
	risk_label.text = "위험  ·  %s" % data["risk"]
	risk_label.add_theme_color_override("font_color", Color("#8c3026"))
	faction_description_label.text = str(data.get("description", ""))
	notable_characters_label.text = ScenarioData.get_notable_text(
		data.get("notable", []),
		scenario_year
	)

	var portrait: Texture2D = _load_first_texture(data["portrait_paths"])
	leader_portrait.texture = portrait
	leader_portrait.visible = portrait != null
	portrait_fallback_label.visible = portrait == null
	portrait_fallback_label.text = commander_name.substr(0, 1)
	portrait_fallback_label.add_theme_color_override(
		"font_color",
		faction_color.darkened(0.18)
	)

	_update_map_markers()


func _update_map_markers() -> void:
	for faction_id: String in map_marker_buttons:
		var marker: Button = map_marker_buttons[faction_id]
		var data: Dictionary = ScenarioData.get_faction(
			_get_scenario_id(),
			faction_id
		)
		if data.is_empty():
			continue
		var faction_color: Color = Color(
			str(data.get("color", "#777777"))
		)
		var selected: bool = faction_id == selected_faction_id
		var background: Color = Color("#f4eddf")
		var border_width: int = 1
		if selected:
			background = faction_color.darkened(0.32)
			border_width = 3

		marker.add_theme_stylebox_override(
			"normal",
			_create_light_box_style(background, faction_color, border_width)
		)
		marker.add_theme_stylebox_override(
			"hover",
			_create_light_box_style(
				faction_color.lightened(0.20),
				faction_color,
				2
			)
		)
		marker.add_theme_color_override(
			"font_color",
			Color.WHITE if selected else faction_color.darkened(0.30)
		)

	_position_map_markers()


func _get_selected_scenario() -> Dictionary:
	return ScenarioData.get_scenario_by_index(selected_scenario_index)


func _get_scenario_id() -> String:
	return str(_get_selected_scenario().get("id", ScenarioData.DEFAULT_SCENARIO_ID))


func _get_scenario_year() -> int:
	return int(_get_selected_scenario().get("year", 660))


func _get_selected_faction_data() -> Dictionary:
	return ScenarioData.get_faction(_get_scenario_id(), selected_faction_id)


func _rebuild_scenario_factions() -> void:
	if faction_cards_vbox == null or map_canvas == null:
		return

	for child: Node in faction_cards_vbox.get_children():
		child.queue_free()
	for child: Node in map_marker_buttons.values():
		child.queue_free()

	faction_buttons.clear()
	map_marker_buttons.clear()
	faction_group = ButtonGroup.new()

	var scenario: Dictionary = _get_selected_scenario()
	var faction_values: Array = scenario.get("factions", [])
	var available_ids: Array[String] = []

	for faction_value: Variant in faction_values:
		if typeof(faction_value) != TYPE_DICTIONARY:
			continue
		var faction_data: Dictionary = faction_value
		var faction_id: String = str(faction_data.get("id", ""))
		if faction_id == "":
			continue
		available_ids.append(faction_id)

		var button: Button = _create_faction_card(faction_data)
		button.button_group = faction_group
		button.toggled.connect(_on_faction_toggled.bind(faction_id))
		faction_cards_vbox.add_child(button)
		faction_buttons[faction_id] = button
		_create_map_marker(faction_data)

	if not available_ids.has(selected_faction_id):
		selected_faction_id = available_ids[0] if not available_ids.is_empty() else "silla"

	if faction_buttons.has(selected_faction_id):
		var selected_button: Button = faction_buttons[selected_faction_id]
		selected_button.button_pressed = true

	if faction_guide_label != null:
		faction_guide_label.text = (
			"이 연도에 존재하는 플레이 세력만 표시됩니다."
		)

	_update_map_interaction_visuals()
	call_deferred("_position_map_markers")


func _position_map_markers() -> void:
	if map_canvas == null or map_texture_rect == null:
		return
	if map_texture_rect.texture == null:
		return

	for marker_value: Variant in map_marker_buttons.values():
		var marker: Button = marker_value as Button
		if marker == null:
			continue
		var map_uv: Vector2 = marker.get_meta(
			"map_uv",
			Vector2(0.5, 0.5)
		)
		var pixel_position: Vector2 = _map_uv_to_canvas(map_uv)
		marker.position = pixel_position - Vector2(49.0, 24.0)

	_position_map_details()


func _map_uv_to_canvas(map_uv: Vector2) -> Vector2:
	if map_canvas == null or map_texture_rect == null:
		return Vector2.ZERO
	if map_texture_rect.texture == null:
		return Vector2.ZERO

	var canvas_size: Vector2 = map_canvas.size
	var texture_size: Vector2 = map_texture_rect.texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ZERO

	# STRETCH_KEEP_ASPECT_COVERED가 만드는 확대 배율과 잘린 여백을
	# 그대로 계산해야 원본 지도 좌표와 버튼 위치가 일치합니다.
	var render_scale: float = maxf(
		canvas_size.x / texture_size.x,
		canvas_size.y / texture_size.y
	)
	var rendered_size: Vector2 = texture_size * render_scale
	var image_origin: Vector2 = (canvas_size - rendered_size) * 0.5
	return image_origin + map_uv * rendered_size


func _build_map_details() -> void:
	map_road_lines.clear()
	map_city_labels.clear()

	for road: Array in MAP_ROADS:
		var line: Line2D = Line2D.new()
		line.name = "%sTo%s" % [str(road[0]), str(road[1])]
		line.width = 3.0
		line.default_color = Color(0.34, 0.20, 0.10, 0.82)
		line.antialiased = true
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.set_meta("from_city", str(road[0]))
		line.set_meta("to_city", str(road[1]))
		map_detail_layer.add_child(line)
		map_road_lines.append(line)

	for province_id_value: Variant in PROVINCE_MAP_UV.keys():
		var province_id: String = str(province_id_value)
		var city_label: Label = Label.new()
		city_label.name = "%sCastle" % province_id.capitalize()
		city_label.text = "▣\n%s" % PROVINCE_BASE_NAMES[province_id]
		city_label.custom_minimum_size = Vector2(78.0, 42.0)
		city_label.size = Vector2(78.0, 42.0)
		city_label.pivot_offset = Vector2(39.0, 21.0)
		city_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		city_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		city_label.add_theme_font_size_override("font_size", 12)
		city_label.add_theme_color_override("font_color", Color("#fff5da"))
		city_label.add_theme_color_override(
			"font_outline_color",
			Color("#21160e")
		)
		city_label.add_theme_constant_override("outline_size", 5)
		city_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		city_label.z_index = 2
		city_label.set_meta("province_id", province_id)
		map_detail_layer.add_child(city_label)
		map_city_labels[province_id] = city_label

	_update_map_interaction_visuals()


func _position_map_details() -> void:
	for line: Line2D in map_road_lines:
		var from_id: String = str(line.get_meta("from_city", ""))
		var to_id: String = str(line.get_meta("to_city", ""))
		if not PROVINCE_MAP_UV.has(from_id) or not PROVINCE_MAP_UV.has(to_id):
			continue
		line.points = PackedVector2Array([
			_map_uv_to_canvas(PROVINCE_MAP_UV[from_id]),
			_map_uv_to_canvas(PROVINCE_MAP_UV[to_id]),
		])

	for province_id: String in map_city_labels:
		var city_label: Label = map_city_labels[province_id]
		var pixel_position: Vector2 = _map_uv_to_canvas(
			PROVINCE_MAP_UV[province_id]
		)
		city_label.position = pixel_position - Vector2(39.0, 21.0)


func _update_map_details() -> void:
	if map_city_labels.is_empty():
		return
	var scenario: Dictionary = _get_selected_scenario()
	var overrides: Dictionary = scenario.get("province_overrides", {})
	for province_id: String in map_city_labels:
		var city_name: String = str(
			PROVINCE_BASE_NAMES.get(province_id, province_id)
		)
		if overrides.has(province_id):
			var province_data: Dictionary = overrides[province_id]
			city_name = str(province_data.get("name", city_name))
		var city_label: Label = map_city_labels[province_id]
		city_label.text = "▣\n%s" % city_name

	_position_map_details()


func _on_map_canvas_resized() -> void:
	_position_map_markers()
	_clamp_map_world_position()


func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed:
			_set_map_zoom(map_zoom * MAP_ZOOM_STEP, mouse_event.position)
			map_canvas.accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed:
			_set_map_zoom(map_zoom / MAP_ZOOM_STEP, mouse_event.position)
			map_canvas.accept_event()
			return
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			map_dragging = mouse_event.pressed
			map_drag_last_position = mouse_event.position
			map_canvas.accept_event()
			return

	if event is InputEventMouseMotion and map_dragging:
		var motion_event: InputEventMouseMotion = event
		var movement: Vector2 = motion_event.position - map_drag_last_position
		map_drag_last_position = motion_event.position
		map_world.position += movement
		_clamp_map_world_position()
		map_canvas.accept_event()


func _set_map_zoom(new_zoom: float, focus_position: Vector2) -> void:
	if map_world == null:
		return
	var old_zoom: float = map_zoom
	map_zoom = clampf(new_zoom, MAP_MIN_ZOOM, MAP_MAX_ZOOM)
	if is_equal_approx(old_zoom, map_zoom):
		return

	var world_point: Vector2 = (
		(focus_position - map_world.position) / old_zoom
	)
	map_world.scale = Vector2.ONE * map_zoom
	map_world.position = focus_position - world_point * map_zoom
	_clamp_map_world_position()
	_update_map_interaction_visuals()


func _clamp_map_world_position() -> void:
	if map_canvas == null or map_world == null:
		return
	if map_zoom <= MAP_MIN_ZOOM + 0.001:
		map_world.position = Vector2.ZERO
		return

	var scaled_size: Vector2 = map_canvas.size * map_zoom
	var minimum_position: Vector2 = map_canvas.size - scaled_size
	map_world.position.x = clampf(
		map_world.position.x,
		minimum_position.x,
		0.0
	)
	map_world.position.y = clampf(
		map_world.position.y,
		minimum_position.y,
		0.0
	)


func _update_map_interaction_visuals() -> void:
	var show_details: bool = map_zoom >= MAP_DETAIL_ZOOM
	var inverse_zoom: float = 1.0 / maxf(map_zoom, MAP_MIN_ZOOM)
	if map_detail_layer != null:
		map_detail_layer.visible = show_details
	for line: Line2D in map_road_lines:
		line.width = 3.0 * inverse_zoom
	for city_value: Variant in map_city_labels.values():
		var city_label: Label = city_value as Label
		if city_label != null:
			city_label.scale = Vector2.ONE * inverse_zoom
	for marker_value: Variant in map_marker_buttons.values():
		var marker: Button = marker_value as Button
		if marker != null:
			marker.visible = not show_details
			marker.scale = Vector2.ONE * inverse_zoom


func _format_number(value: int) -> String:
	var source: String = str(value)
	var result: String = ""
	var digit_count: int = 0
	for index: int in range(source.length() - 1, -1, -1):
		if digit_count > 0 and digit_count % 3 == 0:
			result = "," + result
		result = source.substr(index, 1) + result
		digit_count += 1
	return result

# ==========================================
# 선택 이벤트
# ==========================================

func _on_scenario_selected(index: int) -> void:
	_apply_scenario_defaults(index)


func _apply_scenario_defaults(index: int) -> void:
	if index < 0 or index >= ScenarioData.SCENARIOS.size():
		return

	selected_scenario_index = index
	var scenario: Dictionary = ScenarioData.SCENARIOS[index]
	if scenario_buttons.has(index):
		var selected_button: Button = scenario_buttons[index]
		selected_button.button_pressed = true

	scenario_description_label.text = str(scenario.get("description", ""))
	scenario_title_label.text = str(scenario.get("name", "새 캠페인"))

	var scenario_year: int = int(scenario.get("year", 660))
	selected_season_id = str(scenario.get("season", "spring"))

	scenario_date_label.text = (
		"시작 시점: %d년 %s"
		% [scenario_year, SEASON_NAMES.get(selected_season_id, "봄")]
	)

	_rebuild_scenario_factions()
	_update_faction_details()
	_update_map_details()


func _on_faction_toggled(pressed: bool, faction_id: String) -> void:
	if not pressed:
		return

	selected_faction_id = faction_id
	_update_faction_details()


func _on_play_style_toggled(pressed: bool, play_style_id: String) -> void:
	if not pressed:
		return

	selected_play_style_id = play_style_id
	play_style_description_label.text = str(
		PLAY_STYLE_DESCRIPTIONS.get(play_style_id, "")
	)


func _on_difficulty_toggled(pressed: bool, difficulty_id: String) -> void:
	if not pressed:
		return

	selected_difficulty_id = difficulty_id
	difficulty_description_label.text = str(
		DIFFICULTY_DESCRIPTIONS.get(difficulty_id, "")
	)


# ==========================================
# 화면 전환
# ==========================================

func _on_back_pressed() -> void:
	if menu_locked:
		return

	_set_menu_enabled(false)
	status_label.text = "타이틀로 돌아갑니다."
	await _fade_to_black()

	var change_error: Error = get_tree().change_scene_to_file(title_scene_path)

	if change_error != OK:
		status_label.text = "타이틀 화면을 열 수 없습니다."
		await _fade_from_black()
		_set_menu_enabled(true)


func _on_start_pressed() -> void:
	if menu_locked:
		return

	if ScenarioData.SCENARIOS.is_empty():
		status_label.text = "선택 가능한 시나리오가 없습니다."
		return

	var scenario: Dictionary = ScenarioData.SCENARIOS[selected_scenario_index]
	var scenario_year: int = int(scenario.get("year", 660))

	var settings: Dictionary = {
		"faction": selected_faction_id,
		"play_style": selected_play_style_id,
		"difficulty": selected_difficulty_id,
		"scenario_id": str(scenario["id"]),
		"scenario_year": scenario_year,
		"scenario_season": selected_season_id,
	}

	_set_menu_enabled(false)
	status_label.text = (
		"%s · %s(으)로 %d년 %s에 역사를 시작합니다."
		% [
			str(_get_selected_faction_data().get("name", "신라")),
			DIFFICULTY_NAMES.get(selected_difficulty_id, "보통"),
			scenario_year,
			SEASON_NAMES.get(selected_season_id, "봄"),
		]
	)

	await _fade_to_black()

	# campaign_main.gd의 _ready() -> _apply_new_game_settings()가
	# 이 메타를 읽고 제거한 뒤 새 게임 설정을 반영한다.
	get_tree().root.set_meta("new_game_settings", settings)

	var change_error: Error = get_tree().change_scene_to_file(
		campaign_scene_path
	)

	if change_error != OK:
		get_tree().root.remove_meta("new_game_settings")
		status_label.text = "캠페인 화면을 열 수 없습니다."
		await _fade_from_black()
		_set_menu_enabled(true)


func _set_menu_enabled(enabled: bool) -> void:
	menu_locked = not enabled
	back_button.disabled = not enabled
	start_button.disabled = not enabled
	if scenario_option != null:
		scenario_option.disabled = not enabled

	for button in scenario_buttons.values():
		(button as Button).disabled = not enabled

	for button in faction_buttons.values():
		(button as Button).disabled = not enabled

	for button in map_marker_buttons.values():
		(button as Button).disabled = not enabled

	for button in play_style_buttons.values():
		(button as Button).disabled = not enabled

	for button in difficulty_buttons.values():
		(button as Button).disabled = not enabled

# ==========================================
# 오디오
# ==========================================

func _build_music_player() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "SetupMusic"
	music_player.bus = "Music" if _has_audio_bus("Music") else "Master"
	add_child(music_player)


func _has_audio_bus(bus_name: String) -> bool:
	return AudioServer.get_bus_index(bus_name) != -1


# Inspector의 setup_music이 비어 있으면 DEFAULT_SETUP_MUSIC_PATH에서 자동으로
# 불러온다. 파일이 아직 없으면 조용히 아무것도 재생하지 않는다(에러 아님).
func _start_music() -> void:
	if setup_music == null:
		setup_music = _load_default_setup_music()

	if setup_music == null:
		return

	_enable_stream_loop(setup_music)

	music_player.stream = setup_music
	music_player.volume_db = MUSIC_SILENT_DB
	music_player.play()


func _load_default_setup_music() -> AudioStream:
	if not ResourceLoader.exists(DEFAULT_SETUP_MUSIC_PATH):
		return null

	var loaded_resource: Resource = load(DEFAULT_SETUP_MUSIC_PATH)

	if loaded_resource is AudioStream:
		return loaded_resource as AudioStream

	push_warning(
		"NewGameSetup: %s는 오디오 리소스가 아닙니다."
		% DEFAULT_SETUP_MUSIC_PATH
	)
	return null


func _enable_stream_loop(stream: AudioStream) -> void:
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD


func _fade_music_in() -> void:
	if music_player.stream == null or not music_player.playing:
		return

	var music_tween: Tween = create_tween()
	music_tween.set_trans(Tween.TRANS_SINE)
	music_tween.set_ease(Tween.EASE_OUT)
	music_tween.tween_property(
		music_player,
		"volume_db",
		setup_music_volume_db,
		MUSIC_FADE_IN_SECONDS
	)


func _fade_music_out() -> void:
	if music_player.stream == null or not music_player.playing:
		return

	var music_tween: Tween = create_tween()
	music_tween.set_trans(Tween.TRANS_SINE)
	music_tween.set_ease(Tween.EASE_IN)
	music_tween.tween_property(
		music_player,
		"volume_db",
		MUSIC_SILENT_DB,
		MUSIC_FADE_OUT_SECONDS
	)

	await music_tween.finished
	music_player.stop()

# ==========================================
# 페이드 / 인트로
# ==========================================

func _build_fade_layer() -> void:
	fade_rect = ColorRect.new()
	fade_rect.name = "FadeLayer"
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.color = Color.BLACK
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.z_index = 1000
	add_child(fade_rect)


func _play_intro() -> void:
	fade_rect.color.a = 1.0

	var intro_tween: Tween = create_tween()
	intro_tween.set_trans(Tween.TRANS_SINE)
	intro_tween.set_ease(Tween.EASE_OUT)
	intro_tween.tween_property(fade_rect, "color:a", 0.0, 0.5)

	_fade_music_in()

	await intro_tween.finished


func _fade_to_black() -> void:
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	var fade_tween: Tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_property(fade_rect, "color:a", 1.0, 0.42)

	_fade_music_out()

	await fade_tween.finished


func _fade_from_black() -> void:
	var fade_tween: Tween = create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_IN_OUT)
	fade_tween.tween_property(fade_rect, "color:a", 0.0, 0.35)

	await fade_tween.finished
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if music_player.stream != null and not music_player.playing:
		music_player.volume_db = MUSIC_SILENT_DB
		music_player.play()
		_fade_music_in()

# ==========================================
# 스타일 헬퍼
# ==========================================

func _create_section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("#2e281f"))
	return label


func _create_description_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("#514638"))
	return label


func _create_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.90, 0.87, 0.80, 0.94)
	style.border_color = Color(0.16, 0.14, 0.11, 0.92)

	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1

	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4

	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 6.0

	return style


func _create_light_box_style(
	background_color: Color,
	border_color: Color,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 10.0
	style.content_margin_top = 5.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 5.0
	return style


func _create_map_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = _create_light_box_style(
		Color("#d9cfba"),
		Color("#3a3328"),
		1
	)
	style.content_margin_left = 2.0
	style.content_margin_top = 2.0
	style.content_margin_right = 2.0
	style.content_margin_bottom = 2.0
	return style


func _create_button_style(
	background_color: Color,
	border_color: Color,
	border_width: int
) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color

	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width

	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5

	style.content_margin_left = 16.0
	style.content_margin_top = 8.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 8.0

	return style


func _create_menu_button(button_text: String, button_name: String) -> Button:
	var button: Button = Button.new()
	button.name = button_name
	button.text = button_text
	button.custom_minimum_size = Vector2(160.0, 48.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL

	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("#f0e5cb"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.65, 0.55))

	button.add_theme_stylebox_override(
		"normal",
		_create_button_style(
			Color(0.045, 0.040, 0.032, 0.86),
			Color(0.64, 0.48, 0.20, 0.70),
			1
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_create_button_style(
			Color(0.38, 0.27, 0.10, 0.94),
			Color("#e2b84f"),
			2
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_create_button_style(
			Color(0.25, 0.17, 0.06, 0.98),
			Color("#f0c964"),
			2
		)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_create_button_style(
			Color(0.05, 0.05, 0.05, 0.58),
			Color(0.35, 0.35, 0.35, 0.45),
			1
		)
	)

	return button


# 토글(라디오) 버튼: 같은 ButtonGroup을 공유하면 하나만 선택되도록 동작한다.
func _create_choice_button(button_text: String, group: ButtonGroup) -> Button:
	var button: Button = Button.new()
	button.text = button_text
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(118.0, 36.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_ALL
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", Color("#3b3328"))
	button.add_theme_color_override("font_hover_color", Color("#1c1813"))
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.65, 0.65, 0.65, 0.55))

	button.add_theme_stylebox_override(
		"normal",
		_create_light_box_style(
			Color("#f4eee2"),
			Color("#766853"),
			1
		)
	)
	button.add_theme_stylebox_override(
		"hover",
		_create_light_box_style(
			Color("#fffaf0"),
			Color("#8f3c2e"),
			2
		)
	)
	button.add_theme_stylebox_override(
		"pressed",
		_create_light_box_style(
			Color("#29241c"),
			Color("#17130e"),
			2
		)
	)
	button.add_theme_stylebox_override(
		"disabled",
		_create_light_box_style(
			Color("#cbc3b6"),
			Color("#8d857a"),
			1
		)
	)

	return button
