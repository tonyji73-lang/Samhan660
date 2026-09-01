extends Control

const WorldMapData = preload("res://world_map_data.gd")


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
const WORLD_CITY_MAP_UV: Dictionary = WorldMapData.PROVINCE_MAP_UV
const WORLD_CITY_NAMES: Dictionary = WorldMapData.PROVINCE_NAMES
const WORLD_MAP_ROADS: Array = WorldMapData.MAP_ROADS
const WORLD_ROAD_WAYPOINTS: Dictionary = WorldMapData.ROAD_WAYPOINTS
const WORLD_CITY_BUTTON_NAMES: Dictionary = WorldMapData.CITY_BUTTON_NAMES
const WORLD_DEFAULT_GENERAL_NAMES: Dictionary = WorldMapData.DEFAULT_GENERAL_NAMES

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
var city_labels: Dictionary = {}
var map_zoom: float = MAP_MIN_ZOOM
var map_pan_offset: Vector2 = Vector2.ZERO
var map_dragging: bool = false
var map_drag_last_position: Vector2 = Vector2.ZERO
var refresh_elapsed: float = 0.0


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
	resized.connect(_layout_city_buttons)
	gui_input.connect(_on_map_gui_input)
	call_deferred("_layout_city_buttons")
	call_deferred("_refresh_marker_data")


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
	map_background.material = null
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
		label.z_index = 5000
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

	var marker_size: Vector2 = (
		REFERENCE_MARKER_SIZE * ui_scale
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
		button.z_index = int(marker_anchor.y)

	_layout_map_details(map_rect)


func _layout_map_details(map_rect: Rect2) -> void:
	if territory_overlay != null:
		territory_overlay.position = map_rect.position
		territory_overlay.size = map_rect.size

	for index: int in range(WORLD_MAP_ROADS.size()):
		if index >= road_lines.size():
			break

		var road: Array = WORLD_MAP_ROADS[index]
		var from_id: String = str(road[0])
		var to_id: String = str(road[1])
		var line: Line2D = road_lines[index]
		var route_uvs: Array[Vector2] = []
		var route_key: String = "%s_%s" % [from_id, to_id]
		var from_uv: Vector2 = WORLD_CITY_MAP_UV[from_id]
		route_uvs.append(from_uv)

		if WORLD_ROAD_WAYPOINTS.has(route_key):
			for waypoint_value: Variant in WORLD_ROAD_WAYPOINTS[route_key]:
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
		label.visible = map_zoom >= MAP_DETAIL_ZOOM


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

	var extended: Array[Vector2] = []
	extended.append(route_uvs[0])
	for route_uv: Vector2 in route_uvs:
		extended.append(route_uv)
	extended.append(route_uvs[route_uvs.size() - 1])

	const SAMPLES_PER_SEGMENT: int = 14
	for segment_index: int in range(extended.size() - 3):
		var p0: Vector2 = extended[segment_index]
		var p1: Vector2 = extended[segment_index + 1]
		var p2: Vector2 = extended[segment_index + 2]
		var p3: Vector2 = extended[segment_index + 3]

		for sample_index: int in range(SAMPLES_PER_SEGMENT):
			var t: float = float(sample_index) / float(SAMPLES_PER_SEGMENT)
			var t2: float = t * t
			var t3: float = t2 * t
			var route_uv: Vector2 = 0.5 * (
				2.0 * p1
				+ (-p0 + p2) * t
				+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
			)
			result.append(_map_uv_to_position(route_uv, map_rect))

	result.append(
		_map_uv_to_position(
			route_uvs[route_uvs.size() - 1],
			map_rect
		)
	)
	return result


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

		var city_name: String = city_id
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
				province.get("name", city_id)
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

		if is_selected:
			button.z_index = 10000
		elif marker.hovered_marker:
			button.z_index = 20000
		else:
			button.z_index = int(
				button.position.y
					+ button.size.y
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
	for province_id: String in WorldMapData.PROVINCE_IDS:
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

	for province_index: int in range(WorldMapData.PROVINCE_IDS.size()):
		var province_id: String = WorldMapData.PROVINCE_IDS[province_index]
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

	if not PORTRAIT_PATHS.has(general_name):
		portrait_cache[general_name] = null
		return null

	var portrait_path: String = str(
		PORTRAIT_PATHS[general_name]
	)

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
		button.z_index = 20000
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
