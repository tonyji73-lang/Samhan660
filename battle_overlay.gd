extends Control
class_name BattleOverlay

# 삼한660 전술 전투 1차 버전
# - 자유 좌표 이동
# - 부대당 행동력 2
# - 보병/궁병/기병 상성
# - 평지/숲/언덕/성곽 지형
# - 사기, 장수 특성, 퇴각, 캠페인 잔존 병력 반환

signal battle_finished(result: Dictionary)

enum BattlePhase {
	PLAYER_TURN,
	AI_TURN,
	BATTLE_OVER,
}

const DEFAULT_FIELD_SIZE: Vector2 = Vector2(840.0, 520.0)
const TERRAIN_COLS: int = 12
const TERRAIN_ROWS: int = 8
const MAX_BATTLE_TURNS: int = 18
const ACTION_POINTS_PER_TURN: int = 2
const UNIT_MARKER_SIZE: float = 62.0
const UNIT_CLICK_RADIUS: float = 42.0
const UNIT_COLLISION_RADIUS: float = 62.0
const MOVE_ANIMATION_SPEED: float = 360.0

const TERRAIN_PLAIN: String = "plain"
const TERRAIN_FOREST: String = "forest"
const TERRAIN_HILL: String = "hill"

const TERRAIN_LABELS: Dictionary = {
	TERRAIN_PLAIN: "평지",
	TERRAIN_FOREST: "숲",
	TERRAIN_HILL: "언덕",
}
const TERRAIN_ATTACK_MODIFIER: Dictionary = {
	TERRAIN_PLAIN: 1.0,
	TERRAIN_FOREST: 0.90,
	TERRAIN_HILL: 1.03,
}
const TERRAIN_DEFENSE_MODIFIER: Dictionary = {
	TERRAIN_PLAIN: 1.0,
	TERRAIN_FOREST: 1.16,
	TERRAIN_HILL: 1.28,
}
const TERRAIN_MOVE_MODIFIER: Dictionary = {
	TERRAIN_PLAIN: 1.0,
	TERRAIN_FOREST: 0.78,
	TERRAIN_HILL: 0.84,
}
const TERRAIN_COLORS: Dictionary = {
	TERRAIN_FOREST: Color("#243b27"),
	TERRAIN_HILL: Color("#70583a"),
}

const TROOP_INFANTRY: String = "infantry"
const TROOP_ARCHER: String = "archer"
const TROOP_CAVALRY: String = "cavalry"

const TROOP_LABELS: Dictionary = {
	TROOP_INFANTRY: "보병",
	TROOP_ARCHER: "궁병",
	TROOP_CAVALRY: "기병",
}
const TROOP_MOVE_RANGE: Dictionary = {
	TROOP_INFANTRY: 150.0,
	TROOP_ARCHER: 135.0,
	TROOP_CAVALRY: 195.0,
}
const TROOP_ATTACK_RANGE: Dictionary = {
	TROOP_INFANTRY: 88.0,
	TROOP_ARCHER: 175.0,
	TROOP_CAVALRY: 96.0,
}

# 보병은 기병, 기병은 궁병, 궁병은 보병에 강합니다.
const TROOP_COUNTER_BONUS: float = 1.18
const TROOP_COUNTER_PENALTY: float = 0.87

const GENERAL_TRAITS: Dictionary = {
	"김유신": {
		"label": "노장의 관록",
		"min_morale": 40,
	},
	"계백": {
		"label": "황산벌의 결의",
		"desperation_threshold": 0.30,
		"desperation_bonus": 0.30,
	},
	"연개소문": {
		"label": "대막리지의 위엄",
		"aura_radius": 155.0,
		"aura_morale": 5,
	},
	"흑치상지": {
		"label": "귀순의 명수",
		"surrender_bonus": 0.15,
	},
}

const PORTRAIT_MASK_SHADER_CODE: String = """
shader_type canvas_item;

void fragment() {
	vec4 portrait_color = texture(TEXTURE, UV);
	float distance_from_center = distance(UV, vec2(0.5));
	float circle_mask = 1.0 - smoothstep(0.46, 0.50, distance_from_center);
	COLOR = vec4(
		portrait_color.rgb,
		portrait_color.a * circle_mask
	);
}
"""


class TerrainCanvas:
	extends Control

	var terrain_data: Dictionary = {}
	var terrain_seed: int = 1
	var battle_ref: Node = null
	var terrain_cols: int = 12
	var terrain_rows: int = 8
	var terrain_plain: String = "plain"
	var terrain_colors: Dictionary = {
		"forest": Color("#243b27"),
		"hill": Color("#70583a"),
	}


	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#48543a"))

		# 전장을 가로지르는 흙길입니다.
		var road_points: PackedVector2Array = PackedVector2Array([
			Vector2(0.0, size.y * 0.58),
			Vector2(size.x * 0.23, size.y * 0.52),
			Vector2(size.x * 0.48, size.y * 0.60),
			Vector2(size.x * 0.72, size.y * 0.46),
			Vector2(size.x, size.y * 0.51),
		])
		draw_polyline(road_points, Color("#8a7049"), 34.0, true)
		draw_polyline(road_points, Color("#b39a67"), 20.0, true)

		var cell_width: float = size.x / float(terrain_cols)
		var cell_height: float = size.y / float(terrain_rows)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()

		for row in range(terrain_rows):
			for col in range(terrain_cols):
				var cell: Vector2i = Vector2i(col, row)
				var terrain: String = str(
					terrain_data.get(cell, terrain_plain)
				)

				if not terrain_colors.has(terrain):
					continue

				rng.seed = hash("%d:%d:%d" % [terrain_seed, col, row])
				var center: Vector2 = Vector2(
					(float(col) + 0.5) * cell_width,
					(float(row) + 0.5) * cell_height
				)
				center += Vector2(
					(rng.randf() - 0.5) * cell_width * 0.45,
					(rng.randf() - 0.5) * cell_height * 0.45
				)
				var radius: float = minf(cell_width, cell_height) * (
					0.74 + rng.randf() * 0.28
				)
				var color: Color = terrain_colors[terrain]
				color.a = 0.88
				draw_circle(center, radius, color)

		# 오른쪽은 수비측 성곽 방어구역입니다.
		var fortress_rect: Rect2 = Rect2(
			Vector2(size.x * 0.76, 12.0),
			Vector2(size.x * 0.22, size.y - 24.0)
		)
		draw_rect(fortress_rect, Color(0.28, 0.22, 0.15, 0.34))
		draw_dashed_line(
			Vector2(size.x * 0.76, 12.0),
			Vector2(size.x * 0.76, size.y - 12.0),
			Color("#d0b982"),
			3.0,
			10.0
		)


	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return

		var mouse_event: InputEventMouseButton = (
			event as InputEventMouseButton
		)
		if not mouse_event.pressed:
			return
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if battle_ref != null and battle_ref.has_method("_on_field_clicked"):
			battle_ref.call("_on_field_clicked", mouse_event.position)


class RangeRing:
	extends Control

	var radius: float = 100.0
	var ring_color: Color = Color(0.95, 0.80, 0.20, 0.11)
	var edge_color: Color = Color(0.95, 0.80, 0.20, 0.48)


	func _draw() -> void:
		var center: Vector2 = size * 0.5
		draw_circle(center, radius, ring_color)
		draw_arc(center, radius, 0.0, TAU, 64, edge_color, 2.0, true)


var phase: int = BattlePhase.PLAYER_TURN
var turn_number: int = 1
var input_locked: bool = false
var battle_was_retreat: bool = false

var attacker_faction: String = ""
var defender_faction: String = ""
var province_name: String = ""
var fortress_value: int = 0
var battle_seed: int = 1
var attacker_color: Color = Color("#d2a43b")
var defender_color: Color = Color("#a64035")

var terrain_grid: Dictionary = {}
var units: Array[Dictionary] = []
var next_unit_id: int = 0
var selected_unit_id: int = -1
var attackable_unit_ids: Array[int] = []

var initial_attacker_troops: int = 0
var initial_defender_troops: int = 0
var battlefield_size: Vector2 = DEFAULT_FIELD_SIZE

var battle_field_container: Control
var unit_layer: Control
var unit_nodes: Dictionary = {}
var highlight_nodes: Array[Node] = []

var info_label: Label
var log_label: Label
var end_turn_button: Button
var retreat_button: Button
var turn_label: Label
var battle_log_lines: Array[String] = []


func setup_battle(data: Dictionary) -> void:
	attacker_faction = str(data.get("attacker_faction", "공격군"))
	defender_faction = str(data.get("defender_faction", "수비군"))
	province_name = str(data.get("province_name", "전장"))
	fortress_value = clampi(int(data.get("fortress", 0)), 0, 100)
	battle_seed = int(data.get("battle_seed", 1))
	attacker_color = _to_color(
		data.get("attacker_color", Color("#d2a43b")),
		Color("#d2a43b")
	)
	defender_color = _to_color(
		data.get("defender_color", Color("#a64035")),
		Color("#a64035")
	)

	_calculate_battlefield_size()
	_build_ui()
	_generate_terrain()
	_render_terrain()
	_spawn_units(data.get("attacker_units", []), "attacker")
	_spawn_units(data.get("defender_units", []), "defender")

	initial_attacker_troops = _sum_troops("attacker")
	initial_defender_troops = _sum_troops("defender")

	_append_log(
		"%s군이 %s의 %s군을 공격합니다."
		% [attacker_faction, province_name, defender_faction]
	)
	_append_log("부대를 누른 뒤 이동 지점이나 적 부대를 누르세요.")
	_start_player_turn()


func _calculate_battlefield_size() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	battlefield_size = Vector2(
		clampf(viewport_size.x - 400.0, 620.0, 1480.0),
		clampf(viewport_size.y - 160.0, 440.0, 820.0)
	)


func _to_color(value: Variant, fallback: Color) -> Color:
	if typeof(value) == TYPE_COLOR:
		return value
	if typeof(value) == TYPE_STRING and str(value) != "":
		return Color(str(value))
	return fallback


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 500

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color("#10100f")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var outer_margin: MarginContainer = MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 16)
	outer_margin.add_theme_constant_override("margin_top", 12)
	outer_margin.add_theme_constant_override("margin_right", 16)
	outer_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(outer_margin)

	var root_vbox: VBoxContainer = VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	outer_margin.add_child(root_vbox)

	var top_bar: HBoxContainer = HBoxContainer.new()
	top_bar.custom_minimum_size = Vector2(0.0, 44.0)
	top_bar.add_theme_constant_override("separation", 18)
	root_vbox.add_child(top_bar)

	var title_label: Label = Label.new()
	title_label.text = "%s 공방전 · %s 대 %s" % [
		province_name,
		attacker_faction,
		defender_faction,
	]
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 22)
	title_label.add_theme_color_override("font_color", Color("#f0dba3"))
	top_bar.add_child(title_label)

	turn_label = Label.new()
	turn_label.custom_minimum_size = Vector2(170.0, 0.0)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	turn_label.add_theme_font_size_override("font_size", 16)
	turn_label.add_theme_color_override("font_color", Color("#e2b84f"))
	top_bar.add_child(turn_label)

	var content_row: HBoxContainer = HBoxContainer.new()
	content_row.add_theme_constant_override("separation", 14)
	content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(content_row)

	var field_center: CenterContainer = CenterContainer.new()
	field_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_row.add_child(field_center)

	battle_field_container = Control.new()
	battle_field_container.custom_minimum_size = battlefield_size
	battle_field_container.size = battlefield_size
	field_center.add_child(battle_field_container)

	var side_panel: PanelContainer = PanelContainer.new()
	side_panel.custom_minimum_size = Vector2(292.0, 0.0)
	var side_style: StyleBoxFlat = StyleBoxFlat.new()
	side_style.bg_color = Color(0.10, 0.09, 0.07, 0.98)
	side_style.border_color = Color("#9f854f")
	side_style.set_border_width_all(2)
	side_style.set_content_margin_all(14.0)
	side_panel.add_theme_stylebox_override("panel", side_style)
	content_row.add_child(side_panel)

	var side_vbox: VBoxContainer = VBoxContainer.new()
	side_vbox.add_theme_constant_override("separation", 9)
	side_panel.add_child(side_vbox)

	info_label = Label.new()
	info_label.text = "아군 부대를 선택하세요."
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(0.0, 128.0)
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", Color("#e2d4b4"))
	side_vbox.add_child(info_label)

	var divider: HSeparator = HSeparator.new()
	side_vbox.add_child(divider)

	var log_scroll: ScrollContainer = ScrollContainer.new()
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.custom_minimum_size = Vector2(0.0, 210.0)
	side_vbox.add_child(log_scroll)

	log_label = Label.new()
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("font_size", 12)
	log_label.add_theme_color_override("font_color", Color("#bfb195"))
	log_scroll.add_child(log_label)

	end_turn_button = Button.new()
	end_turn_button.text = "턴 종료"
	end_turn_button.custom_minimum_size = Vector2(0.0, 42.0)
	end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	side_vbox.add_child(end_turn_button)

	retreat_button = Button.new()
	retreat_button.text = "퇴각"
	retreat_button.custom_minimum_size = Vector2(0.0, 38.0)
	retreat_button.pressed.connect(_on_retreat_button_pressed)
	side_vbox.add_child(retreat_button)

	var help_label: Label = Label.new()
	help_label.text = "보병>기병 · 기병>궁병 · 궁병>보병\n숲·언덕은 수비에 유리합니다."
	help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_label.add_theme_font_size_override("font_size", 11)
	help_label.add_theme_color_override("font_color", Color("#9f947e"))
	side_vbox.add_child(help_label)


func _generate_terrain() -> void:
	terrain_grid.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = battle_seed

	for row in range(TERRAIN_ROWS):
		for col in range(TERRAIN_COLS):
			var roll: float = rng.randf()
			var terrain: String = TERRAIN_PLAIN
			if roll < 0.14:
				terrain = TERRAIN_HILL
			elif roll < 0.36:
				terrain = TERRAIN_FOREST
			terrain_grid[Vector2i(col, row)] = terrain


func _render_terrain() -> void:
	var terrain_canvas: TerrainCanvas = TerrainCanvas.new()
	terrain_canvas.name = "TerrainCanvas"
	terrain_canvas.size = battlefield_size
	terrain_canvas.custom_minimum_size = battlefield_size
	terrain_canvas.mouse_filter = Control.MOUSE_FILTER_STOP
	terrain_canvas.terrain_data = terrain_grid
	terrain_canvas.terrain_seed = battle_seed
	terrain_canvas.battle_ref = self
	battle_field_container.add_child(terrain_canvas)

	unit_layer = Control.new()
	unit_layer.name = "UnitLayer"
	unit_layer.size = battlefield_size
	unit_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battle_field_container.add_child(unit_layer)


func _get_terrain_at_position(position: Vector2) -> String:
	var cell_width: float = battlefield_size.x / float(TERRAIN_COLS)
	var cell_height: float = battlefield_size.y / float(TERRAIN_ROWS)
	var cell: Vector2i = Vector2i(
		clampi(int(position.x / cell_width), 0, TERRAIN_COLS - 1),
		clampi(int(position.y / cell_height), 0, TERRAIN_ROWS - 1)
	)
	return str(terrain_grid.get(cell, TERRAIN_PLAIN))


func _spawn_units(unit_data_list: Array, side: String) -> void:
	var count: int = unit_data_list.size()
	if count <= 0:
		return

	var start_x: float = battlefield_size.x * (
		0.12 if side == "attacker" else 0.88
	)
	for i in range(count):
		var unit_data: Dictionary = unit_data_list[i]
		var y: float = (
			battlefield_size.y * float(i + 1) / float(count + 1)
		)
		var start_position: Vector2 = Vector2(start_x, y)
		var troop_count: int = maxi(1, int(unit_data.get("troops", 1000)))
		var unit: Dictionary = {
			"id": next_unit_id,
			"name": str(unit_data.get("name", "지휘관")),
			"side": side,
			"faction": (
				attacker_faction if side == "attacker" else defender_faction
			),
			"troops": troop_count,
			"max_troops": troop_count,
			"leadership": int(unit_data.get("leadership", 50)),
			"war": int(unit_data.get("war", 50)),
			"intelligence": int(unit_data.get("intelligence", 50)),
			"politics": int(unit_data.get("politics", 50)),
			"troop_type": str(unit_data.get("troop_type", TROOP_INFANTRY)),
			"portrait_texture": unit_data.get("portrait_texture", null),
			"morale": 100,
			"position": start_position,
			"action_points": ACTION_POINTS_PER_TURN,
			"alive": true,
		}
		next_unit_id += 1
		units.append(unit)
		_create_unit_visual(unit)


func _create_unit_visual(unit: Dictionary) -> void:
	var visual: Control = Control.new()
	visual.name = "Unit_%d" % int(unit["id"])
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.size = Vector2(UNIT_MARKER_SIZE + 8.0, UNIT_MARKER_SIZE + 42.0)

	var ring_panel: Panel = Panel.new()
	ring_panel.name = "Ring"
	ring_panel.position = Vector2(4.0, 0.0)
	ring_panel.size = Vector2(UNIT_MARKER_SIZE, UNIT_MARKER_SIZE)
	ring_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring_style: StyleBoxFlat = StyleBoxFlat.new()
	ring_style.bg_color = Color("#191816")
	ring_style.border_color = _get_side_color(str(unit["side"]))
	ring_style.set_border_width_all(5)
	ring_style.set_corner_radius_all(int(UNIT_MARKER_SIZE * 0.5))
	ring_panel.add_theme_stylebox_override("panel", ring_style)
	visual.add_child(ring_panel)

	var portrait_texture: Texture2D = null
	var texture_value: Variant = unit.get("portrait_texture", null)
	if texture_value is Texture2D:
		portrait_texture = texture_value as Texture2D

	var portrait_rect: TextureRect = TextureRect.new()
	portrait_rect.name = "Portrait"
	portrait_rect.position = Vector2(5.0, 5.0)
	portrait_rect.size = Vector2(UNIT_MARKER_SIZE - 10.0, UNIT_MARKER_SIZE - 10.0)
	portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_rect.texture = portrait_texture
	portrait_rect.visible = portrait_texture != null
	var mask_shader: Shader = Shader.new()
	mask_shader.code = PORTRAIT_MASK_SHADER_CODE
	var mask_material: ShaderMaterial = ShaderMaterial.new()
	mask_material.shader = mask_shader
	portrait_rect.material = mask_material
	ring_panel.add_child(portrait_rect)

	var initials_label: Label = Label.new()
	initials_label.name = "Initials"
	initials_label.text = str(unit["name"]).left(1)
	initials_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	initials_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initials_label.add_theme_font_size_override("font_size", 22)
	initials_label.add_theme_color_override("font_color", Color.WHITE)
	initials_label.visible = portrait_texture == null
	ring_panel.add_child(initials_label)

	var bar_bg: ColorRect = ColorRect.new()
	bar_bg.name = "TroopsBarBg"
	bar_bg.position = Vector2(4.0, UNIT_MARKER_SIZE + 5.0)
	bar_bg.size = Vector2(UNIT_MARKER_SIZE, 8.0)
	bar_bg.color = Color(0.0, 0.0, 0.0, 0.82)
	visual.add_child(bar_bg)

	var bar_fill: ColorRect = ColorRect.new()
	bar_fill.name = "TroopsBarFill"
	bar_fill.position = Vector2(5.0, UNIT_MARKER_SIZE + 6.0)
	bar_fill.size = Vector2(UNIT_MARKER_SIZE - 2.0, 6.0)
	bar_fill.color = Color("#74c85a")
	visual.add_child(bar_fill)

	var troops_label: Label = Label.new()
	troops_label.name = "TroopsLabel"
	troops_label.position = Vector2(0.0, UNIT_MARKER_SIZE + 16.0)
	troops_label.size = Vector2(visual.size.x, 20.0)
	troops_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	troops_label.add_theme_font_size_override("font_size", 12)
	troops_label.add_theme_color_override("font_color", Color("#f3ead4"))
	troops_label.add_theme_color_override("font_outline_color", Color("#111111"))
	troops_label.add_theme_constant_override("outline_size", 3)
	visual.add_child(troops_label)

	unit_layer.add_child(visual)
	unit_nodes[int(unit["id"])] = visual
	_update_unit_visual(unit)


func _update_unit_visual(unit: Dictionary) -> void:
	var unit_id: int = int(unit["id"])
	if not unit_nodes.has(unit_id):
		return

	var visual: Control = unit_nodes[unit_id]
	visual.visible = bool(unit["alive"])
	if not unit["alive"]:
		return

	visual.position = unit["position"] - Vector2(
		visual.size.x * 0.5,
		UNIT_MARKER_SIZE * 0.5
	)

	var troops_label: Label = visual.get_node("TroopsLabel") as Label
	troops_label.text = "%s %d" % [
		TROOP_LABELS.get(unit["troop_type"], "보병"),
		int(unit["troops"]),
	]

	var troops_ratio: float = clampf(
		float(unit["troops"]) / maxf(1.0, float(unit["max_troops"])),
		0.0,
		1.0
	)
	var morale_ratio: float = clampf(float(unit["morale"]) / 100.0, 0.0, 1.0)
	var bar_bg: ColorRect = visual.get_node("TroopsBarBg") as ColorRect
	var bar_fill: ColorRect = visual.get_node("TroopsBarFill") as ColorRect
	bar_fill.size.x = (bar_bg.size.x - 2.0) * troops_ratio
	if morale_ratio > 0.50:
		bar_fill.color = Color("#74c85a")
	elif morale_ratio > 0.25:
		bar_fill.color = Color("#d2ae3f")
	else:
		bar_fill.color = Color("#c24b3e")

	var ring_panel: Panel = visual.get_node("Ring") as Panel
	var ring_style: StyleBoxFlat = (
		ring_panel.get_theme_stylebox("panel") as StyleBoxFlat
	)
	if ring_style != null:
		if unit_id == selected_unit_id:
			ring_style.border_color = Color("#fff0a3")
		elif attackable_unit_ids.has(unit_id):
			ring_style.border_color = Color("#ff5d4c")
		else:
			ring_style.border_color = _get_side_color(str(unit["side"]))


func _get_side_color(side: String) -> Color:
	return attacker_color if side == "attacker" else defender_color


func _refresh_all_unit_visuals() -> void:
	for unit in units:
		_update_unit_visual(unit)


func _get_unit_by_id(unit_id: int) -> Dictionary:
	for unit in units:
		if int(unit["id"]) == unit_id:
			return unit
	return {}


func _get_unit_near(point: Vector2) -> Dictionary:
	var closest: Dictionary = {}
	var closest_distance: float = UNIT_CLICK_RADIUS
	for unit in units:
		if not unit["alive"]:
			continue
		var distance: float = unit["position"].distance_to(point)
		if distance <= closest_distance:
			closest_distance = distance
			closest = unit
	return closest


func _get_attack_range(unit: Dictionary) -> float:
	return float(TROOP_ATTACK_RANGE.get(unit["troop_type"], 88.0))


func _get_move_range(unit: Dictionary, target: Vector2) -> float:
	var base_range: float = float(
		TROOP_MOVE_RANGE.get(unit["troop_type"], 150.0)
	)
	var terrain: String = _get_terrain_at_position(target)
	return base_range * float(TERRAIN_MOVE_MODIFIER.get(terrain, 1.0))


func _get_enemies_in_range(unit: Dictionary) -> Array[int]:
	var result: Array[int] = []
	var attack_range: float = _get_attack_range(unit)
	for other in units:
		if not other["alive"] or other["side"] == unit["side"]:
			continue
		if unit["position"].distance_to(other["position"]) <= attack_range:
			result.append(int(other["id"]))
	return result


func _select_unit(unit_id: int) -> void:
	var unit: Dictionary = _get_unit_by_id(unit_id)
	if unit.is_empty():
		return
	selected_unit_id = unit_id
	attackable_unit_ids = _get_enemies_in_range(unit)
	_apply_move_highlight(unit)
	_update_info_panel(unit)
	_refresh_all_unit_visuals()


func _deselect_unit() -> void:
	selected_unit_id = -1
	attackable_unit_ids.clear()
	_clear_highlights()
	_update_info_panel({})
	_refresh_all_unit_visuals()


func _clear_highlights() -> void:
	for node in highlight_nodes:
		if is_instance_valid(node):
			node.queue_free()
	highlight_nodes.clear()


func _apply_move_highlight(unit: Dictionary) -> void:
	_clear_highlights()
	var max_radius: float = float(
		TROOP_MOVE_RANGE.get(unit["troop_type"], 150.0)
	)
	var ring: RangeRing = RangeRing.new()
	ring.radius = max_radius
	ring.size = Vector2.ONE * max_radius * 2.0
	ring.position = unit["position"] - ring.size * 0.5
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = -5
	unit_layer.add_child(ring)
	highlight_nodes.append(ring)


func _update_info_panel(unit: Dictionary) -> void:
	if unit.is_empty():
		info_label.text = "아군 부대를 선택하세요.\n\n행동력 2로 이동 후 공격하거나 두 번 이동할 수 있습니다."
		return

	var trait_data: Dictionary = GENERAL_TRAITS.get(str(unit["name"]), {})
	var trait_line: String = "없음"
	if trait_data.has("label"):
		trait_line = str(trait_data["label"])
	var terrain: String = _get_terrain_at_position(unit["position"])
	info_label.text = (
		"[%s] %s\n병종: %s · 지형: %s\n"
		+ "병력: %d / %d\n사기: %d · 행동력: %d\n"
		+ "통솔 %d · 무력 %d · 지략 %d\n특성: %s"
	) % [
		unit["faction"],
		unit["name"],
		TROOP_LABELS.get(unit["troop_type"], "보병"),
		TERRAIN_LABELS.get(terrain, "평지"),
		int(unit["troops"]),
		int(unit["max_troops"]),
		int(unit["morale"]),
		int(unit["action_points"]),
		int(unit["leadership"]),
		int(unit["war"]),
		int(unit["intelligence"]),
		trait_line,
	]


func _on_field_clicked(local_pos: Vector2) -> void:
	if phase != BattlePhase.PLAYER_TURN or input_locked:
		return

	var clicked_unit: Dictionary = _get_unit_near(local_pos)
	if selected_unit_id == -1:
		if clicked_unit.is_empty():
			return
		if clicked_unit["side"] != "attacker":
			return
		if int(clicked_unit["action_points"]) <= 0:
			return
		_select_unit(int(clicked_unit["id"]))
		return

	var selected_unit: Dictionary = _get_unit_by_id(selected_unit_id)
	if selected_unit.is_empty():
		_deselect_unit()
		return

	if not clicked_unit.is_empty():
		if int(clicked_unit["id"]) == selected_unit_id:
			_deselect_unit()
			return
		if clicked_unit["side"] == "attacker":
			if int(clicked_unit["action_points"]) > 0:
				_select_unit(int(clicked_unit["id"]))
			return

		var distance: float = selected_unit["position"].distance_to(
			clicked_unit["position"]
		)
		if distance <= _get_attack_range(selected_unit):
			_perform_attack(selected_unit, clicked_unit)
			_deselect_unit()
			if _check_battle_end():
				return
			_maybe_end_player_turn()
		else:
			_try_player_move(selected_unit, clicked_unit["position"])
		return

	_try_player_move(selected_unit, local_pos)


func _try_player_move(unit: Dictionary, target_point: Vector2) -> void:
	if int(unit["action_points"]) <= 0:
		return
	var target: Vector2 = _clamp_move_target(unit, target_point)
	if target.distance_to(unit["position"]) < 3.0:
		_deselect_unit()
		return
	_run_player_move(unit, target)


func _run_player_move(unit: Dictionary, target: Vector2) -> void:
	input_locked = true
	unit["action_points"] = maxi(0, int(unit["action_points"]) - 1)
	_clear_highlights()
	await _animate_unit_move(unit, target)
	input_locked = false
	_deselect_unit()
	_maybe_end_player_turn()


func _animate_unit_move(unit: Dictionary, target: Vector2) -> void:
	var unit_id: int = int(unit["id"])
	if not unit_nodes.has(unit_id):
		unit["position"] = target
		return

	var visual: Control = unit_nodes[unit_id]
	var start: Vector2 = unit["position"]
	var duration: float = maxf(
		0.10,
		start.distance_to(target) / MOVE_ANIMATION_SPEED
	)
	var final_visual_position: Vector2 = target - Vector2(
		visual.size.x * 0.5,
		UNIT_MARKER_SIZE * 0.5
	)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(visual, "position", final_visual_position, duration)
	await tween.finished
	unit["position"] = target
	_update_unit_visual(unit)


func _clamp_move_target(unit: Dictionary, target_point: Vector2) -> Vector2:
	var from: Vector2 = unit["position"]
	var target: Vector2 = Vector2(
		clampf(target_point.x, 34.0, battlefield_size.x - 34.0),
		clampf(target_point.y, 34.0, battlefield_size.y - 48.0)
	)
	var offset: Vector2 = target - from
	var distance: float = offset.length()
	var allowed_range: float = _get_move_range(unit, target)
	if distance > allowed_range:
		offset = offset.normalized() * allowed_range
		target = from + offset
		distance = allowed_range
	if distance < 1.0:
		return from

	var direction: Vector2 = offset.normalized()
	var safe_distance: float = distance
	for other in units:
		if not other["alive"] or int(other["id"]) == int(unit["id"]):
			continue
		var to_other: Vector2 = other["position"] - from
		var projection: float = to_other.dot(direction)
		if projection <= 0.0 or projection > distance:
			continue
		var closest_point: Vector2 = from + direction * projection
		var lateral: float = closest_point.distance_to(other["position"])
		if lateral < UNIT_COLLISION_RADIUS:
			var back_off: float = sqrt(maxf(
				0.0,
				UNIT_COLLISION_RADIUS * UNIT_COLLISION_RADIUS - lateral * lateral
			))
			safe_distance = minf(
				safe_distance,
				maxf(0.0, projection - back_off)
			)
	return from + direction * safe_distance


func _get_counter_modifier(attacker_type: String, defender_type: String) -> float:
	if (
		(attacker_type == TROOP_INFANTRY and defender_type == TROOP_CAVALRY)
		or (attacker_type == TROOP_CAVALRY and defender_type == TROOP_ARCHER)
		or (attacker_type == TROOP_ARCHER and defender_type == TROOP_INFANTRY)
	):
		return TROOP_COUNTER_BONUS
	if (
		(defender_type == TROOP_INFANTRY and attacker_type == TROOP_CAVALRY)
		or (defender_type == TROOP_CAVALRY and attacker_type == TROOP_ARCHER)
		or (defender_type == TROOP_ARCHER and attacker_type == TROOP_INFANTRY)
	):
		return TROOP_COUNTER_PENALTY
	return 1.0


func _is_in_fortress_zone(unit: Dictionary) -> bool:
	return (
		unit["side"] == "defender"
		and float(unit["position"].x) >= battlefield_size.x * 0.76
	)


func _get_general_trait(unit: Dictionary) -> Dictionary:
	return GENERAL_TRAITS.get(str(unit["name"]), {})


func _apply_power_trait(unit: Dictionary, power: float) -> float:
	var trait_data: Dictionary = _get_general_trait(unit)
	if not trait_data.has("desperation_threshold"):
		return power
	var troops_ratio: float = float(unit["troops"]) / maxf(
		1.0,
		float(unit["max_troops"])
	)
	if troops_ratio > float(trait_data["desperation_threshold"]):
		return power
	return power * (1.0 + float(trait_data.get("desperation_bonus", 0.0)))


func _apply_morale_floor(unit: Dictionary) -> void:
	var trait_data: Dictionary = _get_general_trait(unit)
	if trait_data.has("min_morale"):
		unit["morale"] = maxi(
			int(unit["morale"]),
			int(trait_data["min_morale"])
		)


func _apply_aura_effects(side: String) -> void:
	for unit in units:
		if not unit["alive"] or unit["side"] != side:
			continue
		var trait_data: Dictionary = _get_general_trait(unit)
		if not trait_data.has("aura_radius"):
			continue
		for other in units:
			if not other["alive"] or other["side"] != side:
				continue
			if int(other["id"]) == int(unit["id"]):
				continue
			if unit["position"].distance_to(other["position"]) > float(
				trait_data["aura_radius"]
			):
				continue
			other["morale"] = mini(
				100,
				int(other["morale"]) + int(
					trait_data.get("aura_morale", 0)
				)
			)
			_update_unit_visual(other)


func _perform_attack(attacker: Dictionary, defender: Dictionary) -> void:
	if int(attacker["action_points"]) <= 0:
		return
	attacker["action_points"] = maxi(
		0,
		int(attacker["action_points"]) - 1
	)

	var attacker_terrain: String = _get_terrain_at_position(attacker["position"])
	var defender_terrain: String = _get_terrain_at_position(defender["position"])
	var fortress_bonus: float = 0.0
	if _is_in_fortress_zone(defender):
		fortress_bonus = float(fortress_value) / 260.0

	var counter_modifier: float = _get_counter_modifier(
		str(attacker["troop_type"]),
		str(defender["troop_type"])
	)
	var attacker_power: float = (
		float(attacker["troops"])
		* (1.0 + float(attacker["leadership"]) / 115.0)
		* float(TERRAIN_ATTACK_MODIFIER.get(attacker_terrain, 1.0))
		* maxf(0.25, float(attacker["morale"]) / 100.0)
		* counter_modifier
	)
	attacker_power = _apply_power_trait(attacker, attacker_power)

	var defender_power: float = (
		float(defender["troops"])
		* (
			1.0
			+ float(defender["leadership"]) / 115.0
			+ fortress_bonus
		)
		* float(TERRAIN_DEFENSE_MODIFIER.get(defender_terrain, 1.0))
		* maxf(0.25, float(defender["morale"]) / 100.0)
	)
	defender_power = _apply_power_trait(defender, defender_power)

	var power_ratio: float = attacker_power / maxf(1.0, defender_power)
	var defender_loss_rate: float = clampf(0.12 * power_ratio, 0.04, 0.38)
	var attacker_loss_rate: float = clampf(0.10 / power_ratio, 0.02, 0.28)
	if attacker["troop_type"] == TROOP_ARCHER:
		attacker_loss_rate *= 0.72

	var defender_losses: int = mini(
		int(defender["troops"]),
		maxi(1, int(float(defender["troops"]) * defender_loss_rate))
	)
	var attacker_losses: int = mini(
		int(attacker["troops"]),
		maxi(0, int(float(attacker["troops"]) * attacker_loss_rate))
	)
	attacker["troops"] = int(attacker["troops"]) - attacker_losses
	defender["troops"] = int(defender["troops"]) - defender_losses
	defender["morale"] = maxi(
		0,
		int(defender["morale"]) - int(defender_loss_rate * 80.0)
	)
	attacker["morale"] = maxi(
		0,
		int(attacker["morale"]) - int(attacker_loss_rate * 42.0)
	)
	if power_ratio > 1.35:
		attacker["morale"] = mini(100, int(attacker["morale"]) + 5)
	_apply_morale_floor(attacker)
	_apply_morale_floor(defender)

	_append_log(
		"%s의 %s 공격 → %s: 아군 -%d, 적군 -%d"
		% [
			attacker["name"],
			TROOP_LABELS.get(attacker["troop_type"], "보병"),
			defender["name"],
			attacker_losses,
			defender_losses,
		]
	)
	_show_damage_text(defender["position"], defender_losses)

	if int(defender["troops"]) <= 0 or int(defender["morale"]) <= 0:
		_rout_unit(defender)
	else:
		_update_unit_visual(defender)
	if int(attacker["troops"]) <= 0 or int(attacker["morale"]) <= 0:
		_rout_unit(attacker)
	else:
		_update_unit_visual(attacker)


func _show_damage_text(position: Vector2, losses: int) -> void:
	var damage_label: Label = Label.new()
	damage_label.text = "-%d" % losses
	damage_label.position = position - Vector2(36.0, 54.0)
	damage_label.size = Vector2(72.0, 28.0)
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.add_theme_font_size_override("font_size", 18)
	damage_label.add_theme_color_override("font_color", Color("#ff7463"))
	damage_label.add_theme_color_override("font_outline_color", Color("#111111"))
	damage_label.add_theme_constant_override("outline_size", 4)
	damage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	unit_layer.add_child(damage_label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		damage_label,
		"position:y",
		damage_label.position.y - 28.0,
		0.55
	)
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(Callable(damage_label, "queue_free"))


func _rout_unit(unit: Dictionary) -> void:
	unit["alive"] = false
	unit["action_points"] = 0
	_append_log("%s 부대가 사기를 잃고 패주했습니다." % str(unit["name"]))
	_update_unit_visual(unit)


func _start_player_turn() -> void:
	phase = BattlePhase.PLAYER_TURN
	input_locked = false
	for unit in units:
		if unit["alive"] and unit["side"] == "attacker":
			unit["action_points"] = ACTION_POINTS_PER_TURN
	_apply_aura_effects("attacker")
	_deselect_unit()
	turn_label.text = "%d턴 · 아군 차례" % turn_number
	end_turn_button.disabled = false
	retreat_button.disabled = false
	_append_log("— %d턴 아군 차례 —" % turn_number)


func _maybe_end_player_turn() -> void:
	for unit in units:
		if (
			unit["alive"]
			and unit["side"] == "attacker"
			and int(unit["action_points"]) > 0
		):
			return
	_end_player_turn()


func _on_end_turn_button_pressed() -> void:
	if phase == BattlePhase.PLAYER_TURN and not input_locked:
		_end_player_turn()


func _end_player_turn() -> void:
	if phase != BattlePhase.PLAYER_TURN:
		return
	_deselect_unit()
	end_turn_button.disabled = true
	retreat_button.disabled = true
	if _check_battle_end():
		return
	phase = BattlePhase.AI_TURN
	input_locked = true
	turn_label.text = "%d턴 · 적 차례" % turn_number
	_append_log("— %d턴 적 차례 —" % turn_number)
	await get_tree().create_timer(0.35).timeout
	await _run_ai_turn()


func _run_ai_turn() -> void:
	for unit in units:
		if unit["alive"] and unit["side"] == "defender":
			unit["action_points"] = ACTION_POINTS_PER_TURN
	_apply_aura_effects("defender")

	for unit in units:
		if unit["alive"] and unit["side"] == "defender":
			await _run_ai_unit_turn(unit)
			if _check_battle_end():
				return

	turn_number += 1
	if turn_number > MAX_BATTLE_TURNS:
		_force_end_by_attrition()
		return
	_start_player_turn()


func _run_ai_unit_turn(ai_unit: Dictionary) -> void:
	while ai_unit["alive"] and int(ai_unit["action_points"]) > 0:
		var target: Dictionary = _find_best_ai_target(ai_unit)
		if target.is_empty():
			ai_unit["action_points"] = 0
			return

		var distance: float = ai_unit["position"].distance_to(target["position"])
		if distance <= _get_attack_range(ai_unit):
			_perform_attack(ai_unit, target)
			await get_tree().create_timer(0.34).timeout
			if _check_battle_end():
				return
			continue

		var new_position: Vector2 = _clamp_move_target(
			ai_unit,
			target["position"]
		)
		if new_position.distance_to(ai_unit["position"]) < 3.0:
			ai_unit["action_points"] = 0
			return
		ai_unit["action_points"] = maxi(
			0,
			int(ai_unit["action_points"]) - 1
		)
		await _animate_unit_move(ai_unit, new_position)
		await get_tree().create_timer(0.16).timeout


func _find_best_ai_target(unit: Dictionary) -> Dictionary:
	var best_target: Dictionary = {}
	var best_score: float = INF
	for other in units:
		if not other["alive"] or other["side"] == unit["side"]:
			continue
		var distance: float = unit["position"].distance_to(other["position"])
		var counter: float = _get_counter_modifier(
			str(unit["troop_type"]),
			str(other["troop_type"])
		)
		var score: float = distance + float(other["troops"]) * 0.004
		if counter > 1.0:
			score -= 65.0
		if score < best_score:
			best_score = score
			best_target = other
	return best_target


func _on_retreat_button_pressed() -> void:
	if phase != BattlePhase.PLAYER_TURN or input_locked:
		return
	battle_was_retreat = true
	_append_log("공격군이 퇴각을 명령했습니다.")
	_end_battle("defender")


func _check_battle_end() -> bool:
	var attacker_alive: bool = false
	var defender_alive: bool = false
	for unit in units:
		if not unit["alive"]:
			continue
		if unit["side"] == "attacker":
			attacker_alive = true
		else:
			defender_alive = true
	if not attacker_alive:
		_end_battle("defender")
		return true
	if not defender_alive:
		_end_battle("attacker")
		return true
	return false


func _force_end_by_attrition() -> void:
	var attacker_total: int = _sum_troops("attacker")
	var defender_total: int = _sum_troops("defender")
	var winner: String = "defender"
	if attacker_total > int(float(defender_total) * 1.15):
		winner = "attacker"
	_append_log("%d턴이 지나 소모전 판정에 들어갑니다." % MAX_BATTLE_TURNS)
	_end_battle(winner)


func _sum_troops(side: String) -> int:
	var total: int = 0
	for unit in units:
		if unit["alive"] and unit["side"] == side:
			total += maxi(0, int(unit["troops"]))
	return total


func _get_surrender_bonus(side: String) -> float:
	for unit in units:
		if not unit["alive"] or unit["side"] != side:
			continue
		var trait_data: Dictionary = _get_general_trait(unit)
		if trait_data.has("surrender_bonus"):
			return float(trait_data["surrender_bonus"])
	return 0.0


func _get_best_surviving_commander(side: String) -> String:
	var best_name: String = ""
	var best_leadership: int = -1
	for unit in units:
		if not unit["alive"] or unit["side"] != side:
			continue
		if int(unit["leadership"]) > best_leadership:
			best_leadership = int(unit["leadership"])
			best_name = str(unit["name"])
	return best_name


func _end_battle(winner: String) -> void:
	if phase == BattlePhase.BATTLE_OVER:
		return
	phase = BattlePhase.BATTLE_OVER
	input_locked = true
	_deselect_unit()
	end_turn_button.disabled = true
	retreat_button.disabled = true
	var winner_faction: String = (
		attacker_faction if winner == "attacker" else defender_faction
	)
	_append_log("전투 종료: %s 승리" % winner_faction)
	_show_result_panel(winner)


func _show_result_panel(winner: String) -> void:
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0.0, 0.0, 0.0, 0.70)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 50
	add_child(overlay)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.025, 0.98)
	style.border_color = Color("#d5b867")
	style.set_border_width_all(3)
	style.set_content_margin_all(28.0)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var winner_faction: String = (
		attacker_faction if winner == "attacker" else defender_faction
	)
	var title: Label = Label.new()
	title.text = "전투 종료 · %s 승리" % winner_faction
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#f0dba3"))
	vbox.add_child(title)

	var summary: Label = Label.new()
	summary.text = (
		"%s: %d → %d\n%s: %d → %d"
		% [
			attacker_faction,
			initial_attacker_troops,
			_sum_troops("attacker"),
			defender_faction,
			initial_defender_troops,
			_sum_troops("defender"),
		]
	)
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 16)
	summary.add_theme_color_override("font_color", Color("#ded0ad"))
	vbox.add_child(summary)

	var confirm_button: Button = Button.new()
	confirm_button.text = "캠페인으로 돌아가기"
	confirm_button.custom_minimum_size = Vector2(230.0, 46.0)
	confirm_button.pressed.connect(_on_result_confirmed.bind(winner))
	vbox.add_child(confirm_button)


func _on_result_confirmed(winner: String) -> void:
	var result: Dictionary = {
		"winner": winner,
		"retreated": battle_was_retreat,
		"attacker_initial": initial_attacker_troops,
		"defender_initial": initial_defender_troops,
		"attacker_survivors": _sum_troops("attacker"),
		"defender_survivors": _sum_troops("defender"),
		"attacker_commander_name": _get_best_surviving_commander("attacker"),
		"defender_commander_name": _get_best_surviving_commander("defender"),
		"attacker_surrender_bonus": _get_surrender_bonus("attacker"),
		"defender_surrender_bonus": _get_surrender_bonus("defender"),
	}
	battle_finished.emit(result)
	queue_free()


func _append_log(text: String) -> void:
	battle_log_lines.append(text)
	if battle_log_lines.size() > 44:
		battle_log_lines = battle_log_lines.slice(
			battle_log_lines.size() - 44,
			battle_log_lines.size()
		)
	if log_label != null:
		log_label.text = "\n".join(battle_log_lines)
