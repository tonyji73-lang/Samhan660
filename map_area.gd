extends Control

const WorldMapData = preload("res://world_map_data.gd")
const ScenarioData = preload("res://scenario_data.gd")
const Korea35Data = preload("res://korea_35_data.gd")
const FloatingCityCardScene = preload("res://floating_city_card.tscn")

signal city_card_domestic_requested(province_id: String)
signal city_card_recruit_requested(province_id: String)
signal city_card_sortie_requested(province_id: String)
signal city_card_move_requested(province_id: String)
signal city_card_detail_requested(province_id: String)

const MAP_BRIGHTNESS_SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

uniform float brightness : hint_range(0.8, 1.4) = 1.16;
uniform float contrast : hint_range(0.8, 1.3) = 1.04;
uniform float saturation : hint_range(0.0, 1.3) = 0.96;

void fragment() {
	vec4 source_color = texture(TEXTURE, UV);
	vec3 color = source_color.rgb * brightness;
	color = (color - vec3(0.5)) * contrast + vec3(0.5);
	float luminance = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luminance), color, saturation);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), source_color.a);
}
"""


class GeneralMarkerVisual:
	extends Control

	const PORTRAIT_SHADER_CODE: String = """
shader_type canvas_item;

void fragment() {
	vec4 portrait_color = texture(TEXTURE, UV);
	float distance_from_center = distance(UV, vec2(0.5));
	float circle_mask = 1.0 - smoothstep(
		0.47,
		0.50,
		distance_from_center
	);
	COLOR = vec4(
		portrait_color.rgb,
		portrait_color.a * circle_mask
	);
}
"""

	var faction_color: Color = Color("#d2a43b")
	var initials: String = "?"
	var selected_marker: bool = false
	var hovered_marker: bool = false

	var portrait_rect: TextureRect
	var initials_label: Label


	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_build_children()
		resized.connect(_layout_children)
		call_deferred("_layout_children")


	func _build_children() -> void:
		portrait_rect = TextureRect.new()
		portrait_rect.name = "Portrait"
		portrait_rect.expand_mode = (
			TextureRect.EXPAND_IGNORE_SIZE
		)
		portrait_rect.stretch_mode = (
			TextureRect.STRETCH_KEEP_ASPECT_COVERED
		)
		portrait_rect.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		var portrait_shader: Shader = Shader.new()
		portrait_shader.code = PORTRAIT_SHADER_CODE

		var portrait_material: ShaderMaterial = (
			ShaderMaterial.new()
		)
		portrait_material.shader = portrait_shader
		portrait_rect.material = portrait_material

		add_child(portrait_rect)

		initials_label = Label.new()
		initials_label.name = "Initials"
		initials_label.horizontal_alignment = (
			HORIZONTAL_ALIGNMENT_CENTER
		)
		initials_label.vertical_alignment = (
			VERTICAL_ALIGNMENT_CENTER
		)
		initials_label.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)
		initials_label.add_theme_color_override(
			"font_color",
			Color.WHITE
		)
		initials_label.add_theme_color_override(
			"font_outline_color",
			Color("#111111")
		)
		initials_label.add_theme_constant_override(
			"outline_size",
			4
		)

		add_child(initials_label)


	func configure(
		portrait_texture: Texture2D,
		new_initials: String,
		new_faction_color: Color,
		is_selected: bool
	) -> void:
		initials = new_initials
		faction_color = new_faction_color
		selected_marker = is_selected

		if portrait_rect != null:
			portrait_rect.texture = portrait_texture
			portrait_rect.visible = (
				portrait_texture != null
			)

		if initials_label != null:
			initials_label.text = initials
			initials_label.visible = (
				portrait_texture == null
			)

		queue_redraw()


	func set_hovered(value: bool) -> void:
		hovered_marker = value
		queue_redraw()


	func _layout_children() -> void:
		if portrait_rect == null:
			return

		var circle_radius: float = _get_circle_radius()
		var circle_center: Vector2 = _get_circle_center()

		var portrait_size: Vector2 = Vector2.ONE * (
			circle_radius * 2.0 - 8.0
		)

		var portrait_position: Vector2 = (
			circle_center - portrait_size * 0.5
		)

		portrait_rect.position = portrait_position
		portrait_rect.size = portrait_size

		initials_label.position = portrait_position
		initials_label.size = portrait_size
		initials_label.add_theme_font_size_override(
			"font_size",
			maxi(
				14,
				int(circle_radius * 0.80)
			)
		)

		queue_redraw()


	func _draw() -> void:
		var circle_radius: float = _get_circle_radius()
		var circle_center: Vector2 = _get_circle_center()

		var active_color: Color = faction_color

		if hovered_marker:
			active_color = active_color.lightened(0.18)

		var pin_points: PackedVector2Array = (
			PackedVector2Array([
				Vector2(
					circle_center.x
					- circle_radius * 0.42,
					circle_center.y
					+ circle_radius * 0.72
				),
				Vector2(
					circle_center.x
					+ circle_radius * 0.42,
					circle_center.y
					+ circle_radius * 0.72
				),
				Vector2(
					circle_center.x,
					size.y - 2.0
				)
			])
		)

		draw_colored_polygon(
			pin_points,
			Color("#161616")
		)

		var inner_pin_points: PackedVector2Array = (
			PackedVector2Array([
				Vector2(
					circle_center.x
					- circle_radius * 0.32,
					circle_center.y
					+ circle_radius * 0.72
				),
				Vector2(
					circle_center.x
					+ circle_radius * 0.32,
					circle_center.y
					+ circle_radius * 0.72
				),
				Vector2(
					circle_center.x,
					size.y - 6.0
				)
			])
		)

		draw_colored_polygon(
			inner_pin_points,
			active_color.darkened(0.18)
		)

		draw_circle(
			circle_center,
			circle_radius + 4.0,
			Color("#111111")
		)

		draw_circle(
			circle_center,
			circle_radius,
			active_color
		)

		draw_circle(
			circle_center,
			circle_radius - 5.0,
			Color("#222222")
		)

		if selected_marker:
			draw_arc(
				circle_center,
				circle_radius + 7.0,
				0.0,
				TAU,
				48,
				Color.WHITE,
				3.0,
				true
			)


	func _get_circle_radius() -> float:
		return minf(
			size.x * 0.43,
			size.y * 0.35
		)


	func _get_circle_center() -> Vector2:
		var circle_radius: float = _get_circle_radius()

		return Vector2(
			size.x * 0.5,
			circle_radius + 5.0
		)


const DEFAULT_MAP_TEXTURE_PATH: String = (
	WorldMapData.MAP_TEXTURE_PATH
)

const MAP_TEXTURE_SIZE: Vector2 = WorldMapData.MAP_TEXTURE_SIZE

const REFERENCE_MAP_HEIGHT: float = 1024.0
const MAP_MIN_ZOOM: float = 1.0
const MAP_MAX_ZOOM: float = 5.0
const MAP_ZOOM_STEP: float = 1.18
const MAP_DETAIL_ZOOM: float = 1.45

const REFERENCE_MARKER_SIZE: Vector2 = Vector2(
	80.0,
	96.0
)

const MIN_MARKER_SCALE: float = 0.72
const MAX_MARKER_SCALE: float = 1.55

# 줌아웃했을 때 마커가 줄어드는 하한. 줌 1.0에서 마커 폭이 약 26px이 되어
# 한반도의 가장 가까운 도시 간격(23px)과 비슷해집니다. 줌 1.45x 이상에서는
# 1.0이 되어 지금과 같은 초상화 마커로 돌아옵니다.
const MARKER_MIN_ZOOM_SCALE: float = 0.34

const FACTION_COLORS: Dictionary = {
	"고구려": Color("#3d5f86"),
	"백제": Color("#a64035"),
	"신라": Color("#d2a43b"),
	"백제부흥군": Color("#8f342f"),
	"고구려부흥군": Color("#516f91"),
	"당": Color("#556b45"),
}

# Positions on samhan660_korea_focus_map_8192x4608.png.
const CITY_MAP_UV: Dictionary = {
	"ansi": Vector2(0.275, 0.145),
	"gungnae": Vector2(0.405, 0.175),
	"pyongyang": Vector2(0.415, 0.345),
	"ungjin": Vector2(0.465, 0.610),
	"sabi": Vector2(0.455, 0.660),
	"gosa": Vector2(0.425, 0.725),
	"gukwon": Vector2(0.515, 0.565),
	"sabeol": Vector2(0.545, 0.645),
	"geumseong": Vector2(0.595, 0.705)
}

const CITY_NAMES: Dictionary = {
	"ansi": "안시성",
	"gungnae": "국내성",
	"pyongyang": "평양성",
	"ungjin": "웅진성",
	"sabi": "사비성",
	"gosa": "고사성",
	"gukwon": "국원소경",
	"sabeol": "사벌주",
	"geumseong": "금성"
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
	["sabeol", "geumseong"]
]

# Intermediate points make each road follow a plausible valley or mountain
# pass instead of drawing a modern-looking straight line between cities.
# These are gameplay routes for the 8K campaign map, not a claim that every
# bend is a documented seventh-century road.
const ROAD_WAYPOINTS: Dictionary = {
	"ansi_gungnae": [
		Vector2(0.305, 0.128),
		Vector2(0.335, 0.155),
		Vector2(0.370, 0.142),
		Vector2(0.392, 0.165)
	],
	"gungnae_pyongyang": [
		Vector2(0.388, 0.215),
		Vector2(0.410, 0.252),
		Vector2(0.392, 0.292),
		Vector2(0.408, 0.325)
	],
	"pyongyang_ungjin": [
		Vector2(0.400, 0.392),
		Vector2(0.430, 0.432),
		Vector2(0.410, 0.485),
		Vector2(0.445, 0.535),
		Vector2(0.448, 0.580)
	],
	"pyongyang_gukwon": [
		Vector2(0.438, 0.390),
		Vector2(0.458, 0.438),
		Vector2(0.482, 0.465),
		Vector2(0.478, 0.515),
		Vector2(0.505, 0.545)
	],
	"ungjin_sabi": [
		Vector2(0.448, 0.625),
		Vector2(0.463, 0.642)
	],
	"ungjin_gukwon": [
		Vector2(0.472, 0.580),
		Vector2(0.490, 0.598),
		Vector2(0.504, 0.575)
	],
	"sabi_gosa": [
		Vector2(0.438, 0.675),
		Vector2(0.445, 0.697),
		Vector2(0.430, 0.712)
	],
	"sabi_geumseong": [
		Vector2(0.480, 0.678),
		Vector2(0.505, 0.697),
		Vector2(0.528, 0.678),
		Vector2(0.553, 0.700),
		Vector2(0.578, 0.687)
	],
	"gosa_geumseong": [
		Vector2(0.448, 0.742),
		Vector2(0.477, 0.720),
		Vector2(0.505, 0.747),
		Vector2(0.535, 0.720),
		Vector2(0.565, 0.735)
	],
	"gukwon_sabeol": [
		Vector2(0.528, 0.585),
		Vector2(0.515, 0.610),
		Vector2(0.535, 0.628)
	],
	"sabeol_geumseong": [
		Vector2(0.565, 0.660),
		Vector2(0.570, 0.683),
		Vector2(0.585, 0.692)
	]
}

const CITY_BUTTON_NAMES: Dictionary = {
	"ansi": "AnsiButton",
	"gungnae": "GungnaeButton",
	"pyongyang": "PyongyangButton",
	"ungjin": "UngjinButton",
	"gukwon": "GukwonButton",
	"sabi": "SabiButton",
	"sabeol": "SabeolButton",
	"gosa": "GosaButton",
	"geumseong": "GeumseongButton"
}

const DEFAULT_GENERAL_NAMES: Dictionary = {
	"ansi": "양만춘",
	"gungnae": "고연무",
	"pyongyang": "연개소문",
	"ungjin": "흑치상지",
	"gukwon": "김법민",
	"sabi": "의자왕",
	"sabeol": "품일",
	"gosa": "부여태",
	"geumseong": "김춘추"
}

# 아래 WORLD_* 상수는 옛 9영지 씬을 그대로 둔 채 새 세계지도 데이터를 사용하게 합니다.
const WORLD_FACTION_COLORS: Dictionary = WorldMapData.FACTION_COLORS
var WORLD_CITY_MAP_UV: Dictionary = Korea35Data.merge_world_dictionary(
	WorldMapData.PROVINCE_MAP_UV, Korea35Data.PROVINCE_MAP_UV
)
var WORLD_CITY_NAMES: Dictionary = Korea35Data.merge_world_dictionary(
	WorldMapData.PROVINCE_NAMES, Korea35Data.PROVINCE_NAMES
)
var WORLD_MAP_ROADS: Array = Korea35Data.get_world_roads(WorldMapData.MAP_ROADS)
var WORLD_ROAD_WAYPOINTS: Dictionary = Korea35Data.merge_world_dictionary(
	WorldMapData.ROAD_WAYPOINTS, Korea35Data.get_road_waypoints()
)
var WORLD_CITY_BUTTON_NAMES: Dictionary = Korea35Data.merge_world_dictionary(
	WorldMapData.CITY_BUTTON_NAMES, Korea35Data.get_city_button_names()
)
var WORLD_DEFAULT_GENERAL_NAMES: Dictionary = Korea35Data.merge_world_dictionary(
	WorldMapData.DEFAULT_GENERAL_NAMES, Korea35Data.DEFAULT_GENERAL_NAMES
)

const PORTRAIT_PATHS: Dictionary = {
	"선덕여왕": "res://assets/portraits/seondeok_queen.png",
	"무왕": "res://assets/portraits/mu_wang.png",
	"영류왕": "res://assets/portraits/yeongnyu_wang.png",
	"보장왕": "res://assets/portraits/bojang_wang.png",
	"부여풍": "res://assets/portraits/buyeo_pung.png",
	"당 고종": "res://assets/portraits/tang_gaozong.png",
	"안승": "res://assets/portraits/anseung.png",
	"양만춘": "res://assets/portraits/yang_manchun.png",
	"고연무": "res://assets/portraits/go_yeonmu.png",
	"연개소문": "res://assets/portraits/yeon_gaesomun.png",
	"연남생": "res://assets/portraits/yeon_namsaeng.png",
	"흑치상지": "res://assets/portraits/heukchi_sangji.png",
	"흥수": "res://assets/portraits/heungsu.png",
	"계백": "res://assets/portraits/gyebaek.png",
	"김법민": "res://assets/portraits/kim_beopmin.png",
	"의자왕": "res://assets/portraits/uija_wang.png",
	"품일": "res://assets/portraits/pumil.png",
	"부여태": "res://assets/portraits/buyeo_tae.png",
	"김춘추": "res://assets/portraits/kim_chunchu.png",
	"김유신": "res://assets/portraits/kim_yushin.png",
	"김흠순": "res://assets/portraits/kim_heumsun.png",
	"김인문": "res://assets/portraits/kim_inmun.png",
	"관창": "res://assets/portraits/gwanchang.png",
	"성충": "res://assets/portraits/seongchung.png",
	"설인귀": "res://assets/portraits/xue_rengui.png",
	"알천": "res://assets/portraits/alcheon.png",
	"윤충": "res://assets/portraits/yunchung.png",
	"복신": "res://assets/portraits/boksin.png",
	"지수신": "res://assets/portraits/jisusin.png",
	"유인원": "res://assets/portraits/liu_renyuan.png",
	"유인궤": "res://assets/portraits/liu_rengui.png",
	"설오유": "res://assets/portraits/seol_oyu.png",
	"김원술": "res://assets/portraits/kim_wonsul.png",
	"고간": "res://assets/portraits/gao_kan.png",
	"이근행": "res://assets/portraits/li_jinxing.png",
	"예군": "res://assets/portraits/ye_gun.png",
	"검모잠": "res://assets/portraits/geom_mojam.png"
}

@onready var map_background: TextureRect = (
	$CampaignMapBackground
)

var city_buttons: Dictionary = {}
var marker_visuals: Dictionary = {}
var portrait_cache: Dictionary = {}
var territory_overlay: TextureRect
var territory_material: ShaderMaterial
var territory_palette_texture: ImageTexture
var territory_palette_signature: String = ""
var road_lines: Array[Line2D] = []
# 지역 경계선. 각 항목은 [지역 id, 링 좌표, Line2D] 형태입니다.
var border_lines: Array = []
# 선택 불가한 배경 지역(중국·일본)의 경계선입니다. 세력 색 갱신 대상이
# 아니므로 따로 보관합니다.
var outside_border_lines: Array = []
# 장거리 원정로. 각 항목은 [출발, 도착, 점선 Line2D 배열] 형태입니다.
var strategic_lines: Array = []
var city_labels: Dictionary = {}
var map_zoom: float = MAP_MIN_ZOOM
var map_pan_offset: Vector2 = Vector2.ZERO
var map_dragging: bool = false
var map_drag_last_position: Vector2 = Vector2.ZERO
var refresh_elapsed: float = 0.0
var floating_city_card: Control
var floating_city_card_province_id: String = ""


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG

	# Clear the dark tint from the previous map setup.
	modulate = Color.WHITE
	self_modulate = Color.WHITE

	_configure_map_background()
	_build_map_details()
	_collect_city_buttons()
	_build_floating_city_card()
	resized.connect(_layout_city_buttons)
	gui_input.connect(_on_map_gui_input)
	call_deferred("_layout_city_buttons")
	call_deferred("_refresh_marker_data")


func _build_floating_city_card() -> void:
	floating_city_card = FloatingCityCardScene.instantiate() as Control
	floating_city_card.name = "FloatingCityCard"
	floating_city_card.visible = false
	floating_city_card.z_index = 3500
	add_child(floating_city_card)
	floating_city_card.connect(
		"domestic_requested",
		_on_city_card_action.bind(city_card_domestic_requested)
	)
	floating_city_card.connect(
		"recruit_requested",
		_on_city_card_action.bind(city_card_recruit_requested)
	)
	floating_city_card.connect(
		"sortie_requested",
		_on_city_card_action.bind(city_card_sortie_requested)
	)
	floating_city_card.connect(
		"move_requested",
		_on_city_card_action.bind(city_card_move_requested)
	)
	floating_city_card.connect(
		"detail_requested",
		_on_city_card_action.bind(city_card_detail_requested)
	)


func _on_city_card_action(province_id: String, action_signal: Signal) -> void:
	action_signal.emit(province_id)


func show_city_card(
	province_id: String,
	province: Dictionary,
	action_states: Dictionary = {}
) -> void:
	if floating_city_card == null or not city_buttons.has(province_id):
		return
	floating_city_card_province_id = province_id
	floating_city_card.call("configure", province_id, province, action_states)
	floating_city_card.visible = true
	floating_city_card.reset_size()
	call_deferred("_position_floating_city_card")


func hide_city_card() -> void:
	floating_city_card_province_id = ""
	if floating_city_card != null:
		floating_city_card.visible = false


func _position_floating_city_card() -> void:
	if (
		floating_city_card == null
		or not floating_city_card.visible
		or not city_buttons.has(floating_city_card_province_id)
	):
		return

	var marker_button: Button = city_buttons[floating_city_card_province_id]
	var marker_anchor: Vector2 = marker_button.position + Vector2(
		marker_button.size.x * 0.5,
		marker_button.size.y
	)
	var card_size: Vector2 = floating_city_card.size
	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = floating_city_card.custom_minimum_size

	const MARGIN: float = 12.0
	const GAP: float = 18.0
	var card_position: Vector2 = Vector2(
		marker_anchor.x + marker_button.size.x * 0.45 + GAP,
		marker_anchor.y - card_size.y - GAP
	)
	if card_position.x + card_size.x > size.x - MARGIN:
		card_position.x = marker_anchor.x - marker_button.size.x * 0.45 - card_size.x - GAP
	if card_position.y < MARGIN:
		card_position.y = marker_anchor.y + GAP

	card_position.x = clampf(
		card_position.x,
		MARGIN,
		maxf(MARGIN, size.x - card_size.x - MARGIN)
	)
	card_position.y = clampf(
		card_position.y,
		MARGIN,
		maxf(MARGIN, size.y - card_size.y - MARGIN)
	)
	floating_city_card.position = card_position.round()


func _process(delta: float) -> void:
	refresh_elapsed += delta

	if refresh_elapsed < 0.15:
		return

	refresh_elapsed = 0.0
	_refresh_marker_data()


func _configure_map_background() -> void:
	if ResourceLoader.exists(DEFAULT_MAP_TEXTURE_PATH):
		var map_resource: Resource = load(
			DEFAULT_MAP_TEXTURE_PATH
		)
		if map_resource is Texture2D:
			map_background.texture = map_resource as Texture2D

	map_background.set_anchors_preset(
		Control.PRESET_TOP_LEFT
	)
	map_background.position = Vector2.ZERO
	map_background.size = size
	map_background.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)
	map_background.stretch_mode = (
		TextureRect.STRETCH_SCALE
	)
	map_background.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)

	map_background.modulate = Color.WHITE
	map_background.self_modulate = Color.WHITE

	# TODO: MAP_BRIGHTNESS_SHADER_CODE 자체는 문법상 문제가 없는데, 이
	# 환경(Godot 4.7 + D3D12 렌더러로 추정)에서 셰이더 컴파일이 실패해서
	# 지도 자체가 안 뜨는 문제가 있었습니다. 원인 파악 전까지는 이 밝기/
	# 대비/채도 보정 효과를 끄고 원본 텍스처를 그대로 씁니다. 렌더러를
	# Vulkan으로 바꾸거나 원인을 찾으면 아래 세 줄의 주석을 풀어서 다시
	# 켤 수 있습니다.
	# var map_shader: Shader = Shader.new()
	# map_shader.code = MAP_BRIGHTNESS_SHADER_CODE
	# var map_material: ShaderMaterial = ShaderMaterial.new()
	# map_material.shader = map_shader
	# map_background.material = map_material
	map_background.z_index = -10


func _build_map_details() -> void:
	_build_territory_overlay()

	for road: Array in WORLD_MAP_ROADS:
		if road.size() < 2:
			continue

		var line: Line2D = Line2D.new()
		var sea_route: bool = road.size() > 2 and str(road[2]) == "sea"
		line.name = "%s_%s_Road" % [str(road[0]), str(road[1])]
		line.default_color = Color("#bed9df") if sea_route else Color("#a36f3b")
		line.width = 3.5 if sea_route else 5.0
		line.antialiased = true
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.z_index = -5
		line.visible = false
		add_child(line)
		road_lines.append(line)

	_build_strategic_routes()
	_build_region_borders()


# 원정로는 즉시 인접 도로가 아니라 여러 턴에 걸쳐 이동하는 길입니다.
# 일반 도로와 헷갈리지 않도록 점선으로 그립니다. Line2D는 점선을 직접
# 지원하지 않으므로 짧은 선을 여러 개 만들어 번갈아 배치합니다.
const STRATEGIC_DASH_COUNT: int = 26


func _build_strategic_routes() -> void:
	for route_value: Variant in WorldMapData.STRATEGIC_ROUTES:
		var route: Array = route_value
		if route.size() < 2:
			continue

		var from_id: String = str(route[0])
		var to_id: String = str(route[1])
		var dashes: Array[Line2D] = []
		for dash_index: int in range(STRATEGIC_DASH_COUNT):
			var line: Line2D = Line2D.new()
			line.name = "%s_%s_Route_%d" % [from_id, to_id, dash_index]
			line.default_color = Color(0.95, 0.72, 0.35, 0.95)
			line.width = 4.0
			line.antialiased = true
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			# 일반 도로(-5)보다 살짝 아래에 둡니다.
			line.z_index = -6
			line.visible = false
			add_child(line)
			dashes.append(line)

		strategic_lines.append([from_id, to_id, dashes])


func _build_region_borders() -> void:
	# 경계선을 마스크에 구워두면 줌에 따라 사라지거나 각집니다. 좌표를
	# 들고 Line2D로 그리면 굵기가 화면 기준으로 일정하게 유지됩니다.
	_add_border_rings(Korea35Data.REGION_BORDERS, true)

	# 중국·일본은 캠페인 provinces에 없어 선택할 수 없는 배경 지역입니다.
	# 한국과 같은 굵기로 그리면 플레이 가능한 영역처럼 보이므로 흐리게 둡니다.
	#
	# world_map_data.gd가 예전 OUTSIDE_REGION_BORDERS(링 배열 형식)를
	# PROVINCE_POLYGONS(지역당 Vector2 목록 하나짜리 형식)로 교체하면서
	# 이 줄이 존재하지 않는 이름을 참조하게 됐고, 그 때문에 map_area.gd
	# 전체가 로드되지 않아 지도가 아예 안 그려지고 있었습니다. 형식을 맞춰
	# 변환해서 씁니다. 한국 지역 id는 REGION_BORDERS 쪽 몫이므로 제외합니다.
	var outside_borders: Dictionary = {}
	for region_id_value: Variant in WorldMapData.PROVINCE_POLYGONS.keys():
		var region_id: String = str(region_id_value)
		if Korea35Data.PROVINCE_IDS.has(region_id):
			continue
		var points_value: Variant = WorldMapData.PROVINCE_POLYGONS[region_id]
		if typeof(points_value) != TYPE_ARRAY:
			continue
		var ring: PackedVector2Array = PackedVector2Array(points_value)
		if ring.size() < 3:
			continue
		outside_borders[region_id] = [ring]
	_add_border_rings(outside_borders, false)


func _add_border_rings(source: Dictionary, playable: bool) -> void:
	for province_id_value: Variant in source.keys():
		var province_id: String = str(province_id_value)
		var rings: Array = source[province_id]
		for ring_index: int in range(rings.size()):
			var ring: PackedVector2Array = rings[ring_index]
			if ring.size() < 3:
				continue

			var line: Line2D = Line2D.new()
			line.name = "%s_Border_%d" % [province_id.capitalize(), ring_index]
			line.antialiased = true
			line.joint_mode = Line2D.LINE_JOINT_ROUND
			line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			line.end_cap_mode = Line2D.LINE_CAP_ROUND
			line.closed = true
			line.visible = false

			if playable:
				line.width = 1.6
				# 어두운 지도 위에서 묻히지 않도록 밝은 색을 씁니다.
				line.default_color = Color(0.93, 0.88, 0.74, 0.50)
				# 영토 채움(-8)보다 위, 도로(-5)보다 아래에 둡니다.
				line.z_index = -7
			else:
				line.width = 1.2
				line.default_color = Color(0.88, 0.84, 0.72, 0.22)
				line.z_index = -8

			add_child(line)
			# playable이 false면 세력 색 갱신 대상에서 제외합니다.
			if playable:
				border_lines.append([province_id, ring, line])
			else:
				outside_border_lines.append([province_id, ring, line])

	for city_id_value: Variant in WORLD_CITY_NAMES.keys():
		var city_id: String = str(city_id_value)
		var label: Label = Label.new()
		label.name = "%sCityLabel" % city_id.capitalize()
		label.text = str(WORLD_CITY_NAMES[city_id])
		label.size = Vector2(126.0, 30.0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override(
			"font_outline_color",
			Color("#21150d")
		)
		label.add_theme_constant_override("outline_size", 5)
		# 마커 버튼은 장수가 있으면 2500, 선택 상태면 3000까지 올라갑니다.
		# 라벨이 그보다 낮으면 초상화 뒤로 숨으므로 그 위로 올립니다.
		# (Godot의 z_index는 -4096~4096으로 강제 제한되므로, 예전에 쓰던
		# 10000/20000/30000 같은 값은 전부 클램프 에러를 일으켰습니다.)
		label.z_index = 3500
		label.visible = false
		add_child(label)
		city_labels[city_id] = label


func _build_territory_overlay() -> void:
	if not ResourceLoader.exists(WorldMapData.TERRITORY_ID_MAP_PATH):
		push_warning(
			"영토 마스크를 찾을 수 없습니다: %s"
			% WorldMapData.TERRITORY_ID_MAP_PATH
		)
		return

	var mask_resource: Resource = load(WorldMapData.TERRITORY_ID_MAP_PATH)
	if not mask_resource is Texture2D:
		push_warning("영토 마스크가 Texture2D 형식이 아닙니다.")
		return

	territory_overlay = TextureRect.new()
	territory_overlay.name = "LandTerritoryOverlay"
	territory_overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
	territory_overlay.texture = mask_resource as Texture2D
	territory_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	territory_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	territory_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	territory_overlay.z_index = -8

	var territory_shader: Shader = Shader.new()
	territory_shader.code = WorldMapData.TERRITORY_SHADER_CODE
	territory_material = ShaderMaterial.new()
	territory_material.shader = territory_shader
	territory_overlay.material = territory_material
	add_child(territory_overlay)


func _collect_city_buttons() -> void:
	city_buttons.clear()
	marker_visuals.clear()

	for city_id_value in WORLD_CITY_BUTTON_NAMES.keys():
		var city_id: String = str(city_id_value)
		var node_name: String = str(
			WORLD_CITY_BUTTON_NAMES[city_id]
		)
		var button_node: Node = get_node_or_null(
			NodePath(node_name)
		)

		if not button_node is Button:
			var generated_button: Button = Button.new()
			generated_button.name = node_name
			add_child(generated_button)
			button_node = generated_button

		var button: Button = button_node as Button
		_configure_city_button(button)

		var marker: GeneralMarkerVisual = (
			GeneralMarkerVisual.new()
		)
		marker.name = "GeneralMarkerVisual"
		marker.set_anchors_and_offsets_preset(
			Control.PRESET_FULL_RECT
		)

		button.add_child(marker)

		button.mouse_entered.connect(
			_on_marker_hover_changed.bind(
				city_id,
				true
			)
		)
		button.mouse_exited.connect(
			_on_marker_hover_changed.bind(
				city_id,
				false
			)
		)

		city_buttons[city_id] = button
		marker_visuals[city_id] = marker


func _configure_city_button(button: Button) -> void:
	button.set_anchors_preset(
		Control.PRESET_TOP_LEFT
	)
	button.custom_minimum_size = Vector2.ZERO
	button.flat = true
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	button.add_theme_color_override(
		"font_color",
		Color.TRANSPARENT
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color.TRANSPARENT
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color.TRANSPARENT
	)
	button.add_theme_color_override(
		"font_focus_color",
		Color.TRANSPARENT
	)
	button.add_theme_color_override(
		"font_disabled_color",
		Color.TRANSPARENT
	)
	button.add_theme_font_size_override(
		"font_size",
		1
	)


func _layout_city_buttons() -> void:
	if not is_node_ready():
		return

	var map_rect: Rect2 = _get_displayed_map_rect()

	if map_rect.size.x <= 0.0:
		return

	if map_rect.size.y <= 0.0:
		return

	map_background.position = map_rect.position
	map_background.size = map_rect.size

	var base_map_rect: Rect2 = _get_base_map_rect()
	var ui_scale: float = clampf(
		base_map_rect.size.y / REFERENCE_MAP_HEIGHT,
		MIN_MARKER_SCALE,
		MAX_MARKER_SCALE
	)

	# ui_scale은 base_map_rect 기준이라 줌을 반영하지 않습니다. 반면 아래
	# marker_anchor는 줌이 적용된 map_rect를 쓰므로, 줌아웃하면 위치만
	# 오그라들고 마커는 그대로 남아 서로 파묻혔습니다. 줌을 함께 곱합니다.
	var zoom_scale: float = clampf(
		remap(map_zoom, MAP_MIN_ZOOM, MAP_DETAIL_ZOOM, MARKER_MIN_ZOOM_SCALE, 1.0),
		MARKER_MIN_ZOOM_SCALE,
		1.0
	)

	var marker_size: Vector2 = (
		REFERENCE_MARKER_SIZE * ui_scale * zoom_scale
	)

	for city_id_value in city_buttons.keys():
		var city_id: String = str(city_id_value)
		var button: Button = city_buttons[city_id]
		var normalized_point: Vector2 = WORLD_CITY_MAP_UV[city_id]

		var marker_anchor: Vector2 = (
			map_rect.position
			+ Vector2(
				normalized_point.x
					* map_rect.size.x,
				normalized_point.y
					* map_rect.size.y
			)
		)

		button.size = marker_size
		button.position = (
			marker_anchor
			- Vector2(
				marker_size.x * 0.5,
				marker_size.y
			)
		).round()
		button.pivot_offset = marker_size * 0.5
		# z_index는 -4096~4096으로 강제 제한되므로, 화면 좌표를 그대로 쓰면
		# 확대했을 때 범위를 넘어 에러가 납니다. 0~2000 사이로 눌러서 씁니다.
		button.z_index = clampi(int(marker_anchor.y), 0, 2000)

	_position_floating_city_card()
	_layout_map_details(map_rect)


func _layout_map_details(map_rect: Rect2) -> void:
	if territory_overlay != null:
		territory_overlay.position = map_rect.position
		territory_overlay.size = map_rect.size

	for entry_value: Variant in border_lines + outside_border_lines:
		var entry: Array = entry_value
		var ring: PackedVector2Array = entry[1]
		var line: Line2D = entry[2]
		var points: PackedVector2Array = PackedVector2Array()
		for ring_uv: Vector2 in ring:
			points.append(_map_uv_to_position(ring_uv, map_rect))
		line.points = points
		line.visible = true

	_layout_strategic_routes(map_rect)

	for index: int in range(WORLD_MAP_ROADS.size()):
		if index >= road_lines.size():
			break

		var road: Array = WORLD_MAP_ROADS[index]
		var from_id: String = str(road[0])
		var to_id: String = str(road[1])
		var line: Line2D = road_lines[index]
		var route_uvs: Array[Vector2] = []
		var from_uv: Vector2 = WORLD_CITY_MAP_UV[from_id]
		route_uvs.append(from_uv)

		for waypoint_value: Variant in _get_route_waypoints(from_id, to_id):
			var waypoint: Vector2 = waypoint_value
			route_uvs.append(waypoint)

		var to_uv: Vector2 = WORLD_CITY_MAP_UV[to_id]
		route_uvs.append(to_uv)
		line.points = _build_smooth_route_points(route_uvs, map_rect)
		line.visible = map_zoom >= MAP_DETAIL_ZOOM

	for city_id_value: Variant in city_labels.keys():
		var city_id: String = str(city_id_value)
		var label: Label = city_labels[city_id]
		var city_position: Vector2 = _map_uv_to_position(
			WORLD_CITY_MAP_UV[city_id],
			map_rect
		)
		label.position = (
			city_position
			+ Vector2(-63.0, 5.0)
		).round()
		label.visible = true


func _layout_strategic_routes(map_rect: Rect2) -> void:
	for entry_value: Variant in strategic_lines:
		var entry: Array = entry_value
		var from_id: String = str(entry[0])
		var to_id: String = str(entry[1])
		var dashes: Array = entry[2]

		if (
			not WORLD_CITY_MAP_UV.has(from_id)
			or not WORLD_CITY_MAP_UV.has(to_id)
		):
			for dash_value: Variant in dashes:
				var hidden_line: Line2D = dash_value
				hidden_line.visible = false
			continue

		var route_uvs: Array[Vector2] = []
		route_uvs.append(WORLD_CITY_MAP_UV[from_id])
		for waypoint_value: Variant in _get_route_waypoints(from_id, to_id):
			var waypoint: Vector2 = waypoint_value
			route_uvs.append(waypoint)
		route_uvs.append(WORLD_CITY_MAP_UV[to_id])

		var path: PackedVector2Array = _build_smooth_route_points(
			route_uvs,
			map_rect
		)
		# 점선 한 칸의 길이를 화면 기준으로 고정합니다. 개수를 고정하면
		# 짧은 노선(툴강 북안-신성은 153px)에서 조각이 3px밖에 안 되어
		# 점처럼 보입니다.
		var path_length: float = 0.0
		for point_index: int in range(path.size() - 1):
			path_length += path[point_index].distance_to(path[point_index + 1])

		var dash_pixels: float = 14.0
		var wanted_dashes: int = clampi(
			int(round(path_length / (dash_pixels * 2.0))),
			2,
			dashes.size()
		)
		var segment_count: int = wanted_dashes * 2

		for dash_index: int in range(dashes.size()):
			var line: Line2D = dashes[dash_index]
			if dash_index >= wanted_dashes:
				line.visible = false
				continue
			var start_ratio: float = float(dash_index * 2) / float(segment_count)
			var end_ratio: float = float(dash_index * 2 + 1) / float(segment_count)
			var dash_points: PackedVector2Array = _slice_polyline(
				path,
				start_ratio,
				end_ratio
			)
			line.points = dash_points
			line.visible = (
				dash_points.size() >= 2
				and map_zoom >= MAP_DETAIL_ZOOM
			)


func _slice_polyline(
	path: PackedVector2Array,
	start_ratio: float,
	end_ratio: float
) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if path.size() < 2:
		return result

	var total: float = 0.0
	for index: int in range(path.size() - 1):
		total += path[index].distance_to(path[index + 1])
	if total <= 0.0:
		return result

	var start_length: float = total * start_ratio
	var end_length: float = total * end_ratio
	var walked: float = 0.0

	for index: int in range(path.size() - 1):
		var a: Vector2 = path[index]
		var b: Vector2 = path[index + 1]
		var seg: float = a.distance_to(b)
		if seg <= 0.0:
			continue
		var seg_end: float = walked + seg

		if seg_end >= start_length and walked <= end_length:
			var from_t: float = clampf((start_length - walked) / seg, 0.0, 1.0)
			var to_t: float = clampf((end_length - walked) / seg, 0.0, 1.0)
			if result.is_empty():
				result.append(a.lerp(b, from_t))
			result.append(a.lerp(b, to_t))

		walked = seg_end
		if walked > end_length:
			break

	return result


func _map_uv_to_position(
	map_uv: Vector2,
	map_rect: Rect2
) -> Vector2:
	return map_rect.position + map_uv * map_rect.size


func _build_smooth_route_points(
	route_uvs: Array[Vector2],
	map_rect: Rect2
) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if route_uvs.size() < 2:
		return result

	var points: Array[Vector2] = []
	for route_uv: Vector2 in route_uvs:
		points.append(_map_uv_to_position(route_uv, map_rect))

	# 중간점이 없으면 직선입니다. 굳이 샘플링하지 않습니다.
	if points.size() == 2:
		result.append(points[0])
		result.append(points[1])
		return result

	const SAMPLES_PER_SEGMENT: int = 16

	# 컨트롤 포인트가 하나인 일반적인 경우: 순수 2차 베지어.
	# 기존 Catmull-Rom과 달리 컨트롤 포인트 바깥으로 튀지 않습니다.
	if points.size() == 3:
		for sample_index: int in range(SAMPLES_PER_SEGMENT + 1):
			var t: float = float(sample_index) / float(SAMPLES_PER_SEGMENT)
			result.append(_quadratic_point(points[0], points[1], points[2], t))
		return result

	# 컨트롤 포인트가 여럿인 경우(수작업 world 항로 등):
	# 이웃한 중점을 시작·끝으로 하는 2차 베지어를 이어 붙입니다.
	var last_index: int = points.size() - 1
	result.append(points[0])
	for index: int in range(1, last_index):
		var segment_start: Vector2 = (
			points[0] if index == 1
			else points[index - 1].lerp(points[index], 0.5)
		)
		var segment_end: Vector2 = (
			points[last_index] if index == last_index - 1
			else points[index].lerp(points[index + 1], 0.5)
		)
		for sample_index: int in range(1, SAMPLES_PER_SEGMENT + 1):
			var t: float = float(sample_index) / float(SAMPLES_PER_SEGMENT)
			result.append(
				_quadratic_point(segment_start, points[index], segment_end, t)
			)

	return result


func _quadratic_point(
	start_point: Vector2,
	control_point: Vector2,
	end_point: Vector2,
	t: float
) -> Vector2:
	# de Casteljau. 결과는 항상 세 점의 볼록 껍질 안에 있습니다.
	return start_point.lerp(control_point, t).lerp(
		control_point.lerp(end_point, t),
		t
	)


func _get_route_waypoints(from_id: String, to_id: String) -> Array:
	# 양방향 조회. world 배열에서 쌍이 뒤집혀 있어도 waypoint를 찾습니다.
	var forward_key: String = "%s_%s" % [from_id, to_id]
	if WORLD_ROAD_WAYPOINTS.has(forward_key):
		return WORLD_ROAD_WAYPOINTS[forward_key]

	var reverse_key: String = "%s_%s" % [to_id, from_id]
	if WORLD_ROAD_WAYPOINTS.has(reverse_key):
		var reversed_points: Array = WORLD_ROAD_WAYPOINTS[reverse_key].duplicate()
		reversed_points.reverse()
		return reversed_points

	return []


func _refresh_marker_data() -> void:
	if not is_node_ready():
		return

	var campaign_node: Node = get_tree().current_scene
	var provinces_value: Variant = campaign_node.get(
		"provinces"
	)
	var selected_value: Variant = campaign_node.get(
		"selected_province_id"
	)

	var provinces_data: Dictionary = {}

	if typeof(provinces_value) == TYPE_DICTIONARY:
		provinces_data = provinces_value

	var selected_city_id: String = str(selected_value)
	_update_territory_colors(provinces_data, selected_city_id)

	for city_id_value in marker_visuals.keys():
		var city_id: String = str(city_id_value)
		var marker: GeneralMarkerVisual = (
			marker_visuals[city_id]
		)
		var button: Button = city_buttons[city_id]

		# 캠페인 provinces에 없는 지역(중국·일본·유목 19곳)은 여기서
		# ID가 그대로 라벨이 되어버렸습니다. 한글 이름을 기본값으로 씁니다.
		var city_name: String = str(
			WORLD_CITY_NAMES.get(city_id, city_id)
		)
		var faction_name: String = ""
		var general_name: String = str(
			WORLD_DEFAULT_GENERAL_NAMES.get(
				city_id,
				"?"
			)
		)
		var troop_count: int = 0

		if provinces_data.has(city_id):
			var province: Dictionary = (
				provinces_data[city_id]
			)
			city_name = str(
				province.get("name", city_name)
			)
			faction_name = str(
				province.get("faction", "")
			)
			general_name = str(
				province.get(
					"governor",
					general_name
				)
			)
			troop_count = int(
				province.get("troops", 0)
			)

		if city_labels.has(city_id):
			var city_label: Label = city_labels[city_id]
			city_label.text = city_name

		var faction_color: Color = Color("#777777")

		if WORLD_FACTION_COLORS.has(faction_name):
			faction_color = WORLD_FACTION_COLORS[faction_name]

		var portrait_texture: Texture2D = (
			_get_portrait_texture(general_name)
		)

		var general_initial: String = "?"

		if not general_name.is_empty():
			general_initial = general_name.left(1)

		var is_selected: bool = (
			selected_city_id == city_id
		)

		marker.configure(
			portrait_texture,
			general_initial,
			faction_color,
			is_selected
		)

		button.tooltip_text = (
			"%s\n%s · %s\n병력: %d"
			% [
				city_name,
				general_name,
				faction_name,
				troop_count
			]
		)

		# z_index는 -4096~4096으로 강제 제한되므로 안전 범위 안에서만 씁니다.
		if is_selected:
			button.z_index = 2500
		elif marker.hovered_marker:
			button.z_index = 3000
		else:
			button.z_index = clampi(
				int(
					button.position.y
						+ button.size.y
				),
				0,
				2000
			)


func _update_territory_colors(
	provinces_data: Dictionary,
	selected_city_id: String
) -> void:
	if territory_material == null:
		return

	var selected_faction_name: String = ""
	if provinces_data.has(selected_city_id):
		selected_faction_name = str(
			provinces_data[selected_city_id].get("faction", "")
		)

	var signature_parts: PackedStringArray = PackedStringArray([
		selected_faction_name,
	])
	for province_id: String in Korea35Data.PROVINCE_IDS:
		var signature_owner: String = ""
		if provinces_data.has(province_id):
			signature_owner = str(
				provinces_data[province_id].get("faction", "")
			)
		signature_parts.append("%s:%s" % [province_id, signature_owner])

	var new_signature: String = "|".join(signature_parts)
	if new_signature == territory_palette_signature:
		return
	territory_palette_signature = new_signature

	var palette_image: Image = Image.create(
		WorldMapData.TERRITORY_PALETTE_SIZE,
		2,
		false,
		Image.FORMAT_RGBA8
	)
	palette_image.fill(Color.TRANSPARENT)

	for province_index: int in range(Korea35Data.PROVINCE_IDS.size()):
		var province_id: String = Korea35Data.PROVINCE_IDS[province_index]
		var owner_name: String = ""
		if provinces_data.has(province_id):
			owner_name = str(
				provinces_data[province_id].get("faction", "")
			)

		var faction_color: Color = Color("#77736b")
		if WORLD_FACTION_COLORS.has(owner_name):
			faction_color = WORLD_FACTION_COLORS[owner_name]

		var selected_owner: bool = (
			selected_faction_name != ""
			and owner_name == selected_faction_name
		)
		var fill_color: Color = faction_color
		fill_color.a = 0.30 if selected_owner else 0.025

		var border_color: Color = Color(0.14, 0.10, 0.07, 0.22)
		if selected_owner:
			border_color = faction_color.lightened(0.32)
			border_color.a = 0.94

		var palette_x: int = province_index + 1
		palette_image.set_pixel(palette_x, 0, fill_color)
		palette_image.set_pixel(palette_x, 1, border_color)

	territory_palette_texture = ImageTexture.create_from_image(palette_image)
	territory_material.set_shader_parameter(
		"territory_palette",
		territory_palette_texture
	)


func _get_portrait_texture(
	general_name: String
) -> Texture2D:
	if portrait_cache.has(general_name):
		return portrait_cache[general_name]

	var portrait_path: String = ""
	if PORTRAIT_PATHS.has(general_name):
		portrait_path = str(PORTRAIT_PATHS[general_name])
	elif ScenarioData.RULER_PORTRAIT_PATHS.has(general_name):
		portrait_path = str(
			ScenarioData.RULER_PORTRAIT_PATHS[general_name]
		)

	if portrait_path == "":
		portrait_cache[general_name] = null
		return null

	if not ResourceLoader.exists(portrait_path):
		portrait_cache[general_name] = null
		return null

	var portrait_resource: Resource = load(portrait_path)

	if portrait_resource is Texture2D:
		var portrait_texture: Texture2D = (
			portrait_resource as Texture2D
		)
		portrait_cache[general_name] = portrait_texture
		return portrait_texture

	portrait_cache[general_name] = null
	return null


func _on_marker_hover_changed(
	city_id: String,
	is_hovered: bool
) -> void:
	if not city_buttons.has(city_id):
		return

	var button: Button = city_buttons[city_id]
	var marker: GeneralMarkerVisual = (
		marker_visuals[city_id]
	)

	marker.set_hovered(is_hovered)

	if is_hovered:
		button.scale = Vector2(1.10, 1.10)
		button.z_index = 3000
	else:
		button.scale = Vector2.ONE
		_layout_city_buttons()
		_refresh_marker_data()


func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = (
			event as InputEventMouseButton
		)

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_map_zoom(
				map_zoom * MAP_ZOOM_STEP,
				mouse_event.position
			)
			accept_event()
			return

		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_map_zoom(
				map_zoom / MAP_ZOOM_STEP,
				mouse_event.position
			)
			accept_event()
			return

		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				hide_city_card()
			map_dragging = mouse_event.pressed
			map_drag_last_position = mouse_event.position
			accept_event()
			return

	if event is InputEventMouseMotion and map_dragging:
		var motion_event: InputEventMouseMotion = (
			event as InputEventMouseMotion
		)
		var movement: Vector2 = (
			motion_event.position - map_drag_last_position
		)
		map_drag_last_position = motion_event.position
		map_pan_offset += movement
		_clamp_map_pan()
		_layout_city_buttons()
		accept_event()


func _unhandled_key_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_cancel")
		and floating_city_card != null
		and floating_city_card.visible
	):
		hide_city_card()
		get_viewport().set_input_as_handled()


func _set_map_zoom(
	new_zoom: float,
	focus_position: Vector2
) -> void:
	var old_rect: Rect2 = _get_displayed_map_rect()
	if old_rect.size.x <= 0.0 or old_rect.size.y <= 0.0:
		return

	var old_zoom: float = map_zoom
	map_zoom = clampf(new_zoom, MAP_MIN_ZOOM, MAP_MAX_ZOOM)
	if is_equal_approx(old_zoom, map_zoom):
		return

	var focus_uv: Vector2 = Vector2(
		(focus_position.x - old_rect.position.x) / old_rect.size.x,
		(focus_position.y - old_rect.position.y) / old_rect.size.y
	)

	var base_rect: Rect2 = _get_base_map_rect()
	var new_size: Vector2 = base_rect.size * map_zoom
	var centered_position: Vector2 = (size - new_size) * 0.5
	map_pan_offset = (
		focus_position
		- centered_position
		- focus_uv * new_size
	)

	_clamp_map_pan()
	_layout_city_buttons()


func focus_on_province(province_id: String, target_zoom: float = 2.15) -> void:
	# 캠페인 시작 시 선택 세력의 수도를 한 번만 화면 중앙에 배치합니다.
	if not WORLD_CITY_MAP_UV.has(province_id):
		return

	map_zoom = clampf(target_zoom, MAP_MIN_ZOOM, MAP_MAX_ZOOM)
	var base_rect: Rect2 = _get_base_map_rect()
	if base_rect.size.x <= 0.0 or base_rect.size.y <= 0.0:
		return

	var displayed_size: Vector2 = base_rect.size * map_zoom
	var capital_uv: Vector2 = WORLD_CITY_MAP_UV[province_id]
	map_pan_offset = displayed_size * (Vector2(0.5, 0.5) - capital_uv)
	_clamp_map_pan()
	_layout_city_buttons()


func _clamp_map_pan() -> void:
	var base_rect: Rect2 = _get_base_map_rect()
	var displayed_size: Vector2 = base_rect.size * map_zoom
	var maximum_offset: Vector2 = Vector2(
		maxf(0.0, (displayed_size.x - size.x) * 0.5),
		maxf(0.0, (displayed_size.y - size.y) * 0.5)
	)
	map_pan_offset.x = clampf(
		map_pan_offset.x,
		-maximum_offset.x,
		maximum_offset.x
	)
	map_pan_offset.y = clampf(
		map_pan_offset.y,
		-maximum_offset.y,
		maximum_offset.y
	)


func _get_base_map_rect() -> Rect2:
	var available_size: Vector2 = size
	if available_size.x <= 0.0 or available_size.y <= 0.0:
		return Rect2()

	var texture_size: Vector2 = MAP_TEXTURE_SIZE
	if map_background.texture != null:
		texture_size = Vector2(map_background.texture.get_size())

	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2()

	var texture_scale: float = maxf(
		available_size.x / texture_size.x,
		available_size.y / texture_size.y
	)
	var displayed_size: Vector2 = texture_size * texture_scale
	var displayed_position: Vector2 = (
		available_size - displayed_size
	) * 0.5
	return Rect2(displayed_position, displayed_size)


func _get_displayed_map_rect() -> Rect2:
	var base_rect: Rect2 = _get_base_map_rect()
	if base_rect.size.x <= 0.0 or base_rect.size.y <= 0.0:
		return Rect2()

	var displayed_size: Vector2 = base_rect.size * map_zoom
	var displayed_position: Vector2 = (
		(size - displayed_size) * 0.5
		+ map_pan_offset
	)
	return Rect2(displayed_position, displayed_size)
