extends Control
## Presentation only. The existing new-game controller owns every choice and rule.
## All IDs are opaque strings passed through without interpreting them.

signal scenario_requested(scenario_id: String)
signal faction_requested(faction_id: String)
signal mode_requested(mode_id: String)
signal difficulty_requested(difficulty_id: String)
signal start_requested(selection: Dictionary)
signal back_requested

@export var heading_font: Font

const FONT_FILE: FontFile = preload("res://ui/faction_selection_v1/assets/SamhanUISans-Medium.ttf")
const BOLD_FONT_FILE: FontFile = preload("res://ui/faction_selection_v1/assets/SamhanUISans-SemiBold.ttf")
const MAP_SHADER: Shader = preload("res://ui/faction_selection_v1/shaders/indirect_map.gdshader")
const LAYOUT_PATH := "res://ui/faction_selection_v1/layout.json"
const DeclarationCatalog = preload("res://ui/faction_declaration_v1/declaration_catalog.gd")
const DeclarationView = preload("res://ui/faction_declaration_v1/hanji_declaration.gd")
const BASE_SIZE := Vector2(1920.0, 1080.0)
const INK := Color("101b1a")
const GOLD := Color("c2a36a")
const IVORY := Color("f2e7ce")
const MUTED := Color("b4b5a8")
const RED := Color("6f261e")

var _model: Dictionary = {}
var _layout: Dictionary = {}
var _stage: Control
var _body_font: FontVariation
var _bold_font: FontVariation
var _details: ScrollContainer
var _scenario_scroll: ScrollContainer
var _faction_scroll: ScrollContainer
var _focus_controls: Dictionary = {}
var _busy := false
var _last_entity := ""
var _declaration_catalog = DeclarationCatalog.new()
var _declaration_view: Control
var _declaration_state: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	if not parsed is Dictionary:
		push_error("Faction selection: layout.json could not be read.")
		return
	_layout = parsed
	_body_font = FontVariation.new()
	_body_font.base_font = FONT_FILE
	_bold_font = FontVariation.new()
	_bold_font.base_font = BOLD_FONT_FILE
	resized.connect(_fit_stage)
	_render()


func present(view_model: Dictionary) -> void:
	_model = view_model.duplicate(true)
	_busy = bool(_model.get("busy", false))
	if is_node_ready() and not _layout.is_empty():
		_render()


func set_start_error(message: String) -> void:
	_model["start_error"] = message
	_model["busy"] = false
	_busy = false
	_render()


func current_selection() -> Dictionary:
	return {
		"scenario_id": str(_model.get("scenario_id", "")),
		"faction_id": str(_model.get("faction_id", "")),
		"mode_id": str(_model.get("mode_id", "")),
		"difficulty_id": str(_model.get("difficulty_id", ""))
	}


func _unhandled_key_input(event: InputEvent) -> void:
	if is_visible_in_tree() and not _busy and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _box(key: String) -> Rect2:
	var values: Array = _layout[key]
	return Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))


func _place(parent: Node, child: Control, rectangle: Rect2) -> void:
	parent.add_child(child)
	child.position = rectangle.position
	child.size = rectangle.size


func _style(fill: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = fill
	style_box.border_color = border
	style_box.set_border_width_all(border_width)
	style_box.set_corner_radius_all(3)
	style_box.content_margin_left = 14.0
	style_box.content_margin_right = 14.0
	style_box.content_margin_top = 8.0
	style_box.content_margin_bottom = 8.0
	return style_box


func _panel(parent: Node, rectangle: Rect2, fill: Color, border: Color = Color.TRANSPARENT) -> Panel:
	var panel := Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fill, border))
	_place(parent, panel, rectangle)
	return panel


func _label(parent: Node, text_value: String, rectangle: Rect2, font_size: int,
		font_color: Color = IVORY, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", _bold_font if bold else _body_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	_place(parent, label, rectangle)
	return label


func _heading(parent: Node, text_value: String, rectangle: Rect2, font_size: int,
		font_color: Color = IVORY) -> Label:
	var label := _label(parent, text_value, rectangle, font_size, font_color, true)
	if heading_font != null:
		label.add_theme_font_override("font", heading_font)
	return label


func _load_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value as Texture2D
	if value is String and str(value).begins_with("res://") and ResourceLoader.exists(str(value)):
		return load(str(value)) as Texture2D
	return null


func _texture(parent: Node, texture_value: Texture2D, rectangle: Rect2, cover: bool) -> TextureRect:
	var texture_rect := TextureRect.new()
	texture_rect.texture = texture_value
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED if cover else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_place(parent, texture_rect, rectangle)
	return texture_rect


func _button(parent: Node, caption: String, key: String, selected: bool,
		enabled: bool, action: Callable, font_size: int = 26) -> Button:
	var button := Button.new()
	button.text = caption
	button.disabled = not enabled or _busy
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", _bold_font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", IVORY)
	button.add_theme_color_override("font_pressed_color", IVORY)
	button.add_theme_color_override("font_focus_color", IVORY)
	button.add_theme_color_override("font_disabled_color", Color("656e68"))
	button.add_theme_stylebox_override("normal", _style(RED if selected else INK, GOLD if selected else Color("6e6247"), 2 if selected else 1))
	button.add_theme_stylebox_override("hover", _style(Color("3d3830"), GOLD, 2))
	button.add_theme_stylebox_override("pressed", _style(Color("542018"), IVORY, 2))
	button.add_theme_stylebox_override("disabled", _style(Color("111b19"), Color("39453d")))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, IVORY, 3))
	button.set_meta("focus_key", key)
	button.pressed.connect(action)
	parent.add_child(button)
	_focus_controls[key] = button
	return button


func _scroll(parent: Node, rectangle: Rect2) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_place(parent, scroll, rectangle)
	return scroll


func _render() -> void:
	if is_instance_valid(_declaration_view):
		_declaration_state = _declaration_view.capture_state()
	_declaration_view = null
	var focus_key := ""
	var old_focus: Control = get_viewport().gui_get_focus_owner()
	if is_instance_valid(old_focus) and is_ancestor_of(old_focus):
		focus_key = str(old_focus.get_meta("focus_key", ""))
	var entity_key := str(_model.get("scenario_id", "")) + "|" + str(_model.get("faction_id", ""))
	var detail_position := _details.scroll_vertical if is_instance_valid(_details) and entity_key == _last_entity else 0
	var scenario_position := _scenario_scroll.scroll_vertical if is_instance_valid(_scenario_scroll) else 0
	var faction_position := _faction_scroll.scroll_vertical if is_instance_valid(_faction_scroll) and entity_key == _last_entity else 0
	_last_entity = entity_key
	if is_instance_valid(_stage):
		remove_child(_stage)
		_stage.queue_free()
	_focus_controls.clear()
	_stage = Control.new()
	_stage.name = "DesignStage"
	_stage.size = BASE_SIZE
	_stage.clip_contents = true
	add_child(_stage)
	_panel(_stage, Rect2(Vector2.ZERO, BASE_SIZE), INK)
	var art: Dictionary = _model.get("art", {})
	var backdrop := _load_texture(art.get("background"))
	_texture(_stage, backdrop, _box("hero"), true)
	_panel(_stage, _box("hero"), Color(0.10, 0.08, 0.04, 0.11))
	_build_map(art)
	_texture(_stage, _load_texture(art.get("portrait")), _box("portrait"), false)
	_build_declaration(art, backdrop)
	_build_header()
	_build_timeline()
	_panel(_stage, _box("right"), Color("101b1a"), GOLD)
	_build_factions()
	_heading(_stage, str(_model.get("faction_name", "세력을 선택하세요")), _box("name"), 58)
	_build_details()
	_build_choices("modes", "mode_id", "플레이 방식", mode_requested)
	_build_choices("difficulty", "difficulty_id", "난이도", difficulty_requested)
	var start_caption := "준비 중…" if _busy else str(_model.get("start_label", "캠페인 시작"))
	var start_button := _button(_stage, start_caption, "start", true, _can_start(), _request_start, 32)
	start_button.position = _box("start").position
	start_button.size = _box("start").size
	var error_text := str(_model.get("start_error", ""))
	if error_text.is_empty() and not _can_start() and not _busy:
		error_text = str(_model.get("start_disabled_reason", ""))
	start_button.tooltip_text = error_text if not error_text.is_empty() else str(_model.get("start_disabled_reason", ""))
	if not error_text.is_empty():
		var notice := _label(_stage, error_text, Rect2(1404, 954, 480, 28), 20, Color("ffcc9e"))
		notice.tooltip_text = error_text
	_fit_stage()
	_details.set_deferred("scroll_vertical", detail_position)
	_scenario_scroll.set_deferred("scroll_vertical", scenario_position)
	_faction_scroll.set_deferred("scroll_vertical", faction_position)
	_restore_focus.call_deferred(focus_key)


func _fit_stage() -> void:
	if not is_instance_valid(_stage):
		return
	var factor := minf(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	_stage.scale = Vector2.ONE * factor
	_stage.position = (size - BASE_SIZE * factor) * 0.5


func _restore_focus(key: String) -> void:
	var target: Button = _focus_controls.get(key) as Button
	if is_instance_valid(target) and not target.disabled:
		target.grab_focus()


func _build_header() -> void:
	_panel(_stage, _box("header"), Color("0b1413"), GOLD)
	_heading(_stage, "삼한 660", Rect2(32, 10, 246, 62), 40)
	_label(_stage, "|", Rect2(292, 12, 30, 60), 30, GOLD)
	_heading(_stage, "새 캠페인", Rect2(340, 10, 420, 62), 36)
	var back_button := _button(_stage, "뒤로", "back", false, true, func() -> void: back_requested.emit())
	back_button.position = _box("back").position
	back_button.size = _box("back").size
	var year_label := _heading(_stage, str(_model.get("year_label", "")), _box("year"), 32, Color("3e2e1b"))
	year_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_label := _heading(_stage, str(_model.get("scenario_title", "")), _box("title"), 64, Color("302217"))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.91, 0.73, 0.7))
	title_label.add_theme_constant_override("shadow_offset_y", 2)
	if str(_model.get("art",{}).get("profile_key","")) != "632_silla":
		for heading: Label in [year_label,title_label]:
			heading.add_theme_color_override("font_color", IVORY)
			heading.add_theme_color_override("font_outline_color", Color("302217"))
			heading.add_theme_constant_override("outline_size", 4)
			heading.add_theme_color_override("font_shadow_color", Color("101b1a"))


func _build_map(art: Dictionary) -> void:
	var map_texture := _load_texture(art.get("map"))
	if map_texture == null:
		return
	var map_box := _box("map")
	var map_rect := _texture(_stage, map_texture, map_box, false)
	var map_material := ShaderMaterial.new()
	map_material.shader = MAP_SHADER
	map_rect.material = map_material
	var capital: Variant = art.get("capital_uv")
	if not capital is Vector2:
		return
	var texture_size := Vector2(map_texture.get_width(), map_texture.get_height())
	var fit := minf(map_box.size.x / texture_size.x, map_box.size.y / texture_size.y)
	var displayed_size := texture_size * fit
	var marker_center: Vector2 = map_box.position + (map_box.size - displayed_size) * 0.5 + capital * displayed_size
	var ring := _panel(_stage, Rect2(marker_center - Vector2(12, 12), Vector2(24, 24)), Color("815424"), IVORY)
	ring.name = "StartMarker"
	ring.z_index = 1
	var marker_colors := {"goguryeo": Color("3289e8"), "baekje": Color("df4545"), "silla": Color("ed912c")}
	var marker_color: Color = marker_colors.get(str(_model.get("faction_id", "")), Color("9b682d"))
	var ring_style := _style(marker_color, Color("f4d28d"), 3)
	ring_style.set_corner_radius_all(12)
	ring.add_theme_stylebox_override("panel", ring_style)
	var map_caption := _label(_stage, str(art.get("capital_label",_model.get("capital", ""))), Rect2(marker_center + Vector2(21, -21), Vector2(180, 42)), 28, IVORY, true)
	map_caption.name = "StartMarkerLabel"
	map_caption.z_index = 1
	map_caption.add_theme_color_override("font_shadow_color", Color("211d18"))
	map_caption.add_theme_constant_override("shadow_outline_size", 4)


func _build_declaration(art: Dictionary, backdrop: Texture2D) -> void:
	var entry: Dictionary = _declaration_catalog.find_declaration(str(_model.get("scenario_id", "")), str(_model.get("faction_id", "")))
	if entry.is_empty() or str(entry.get("ruler", "")) != str(_model.get("leader", "")):
		_declaration_state.clear()
		return
	var paper_box := _box("paper")
	_panel(_stage, paper_box.grow(1.0), Color("e4cda6"), Color("96744d"))
	if backdrop != null:
		var paper_texture := AtlasTexture.new()
		paper_texture.atlas = backdrop
		paper_texture.region = Rect2(0, 0, minf(440, backdrop.get_width()), minf(600, backdrop.get_height()))
		_texture(_stage, paper_texture, paper_box, true)
	_panel(_stage, paper_box, Color(0.97, 0.91, 0.79, 0.32 if str(art.get("profile_key",""))=="632_silla" else 0.80))
	_declaration_view = DeclarationView.new()
	_declaration_view.name = "HanjiDeclaration"
	_declaration_view.declaration_font = _body_font
	_place(_stage, _declaration_view, paper_box)
	_declaration_view.present_declaration(entry)
	_declaration_view.restore_state(_declaration_state)


func _build_timeline() -> void:
	_panel(_stage, _box("timeline"), Color("101b1a"), Color("77623f"))
	_label(_stage, "시대 선택", Rect2(30, 118, 156, 34), 23, GOLD)
	_scenario_scroll = _scroll(_stage, Rect2(20, 180, 188, 836))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 25)
	_scenario_scroll.add_child(column)
	for entry: Dictionary in _model.get("scenarios", []):
		var entry_id := str(entry.get("id", ""))
		var selected := entry_id == str(_model.get("scenario_id", ""))
		var button := _button(column, str(entry.get("label", "")), "scenario:" + entry_id, selected,
			bool(entry.get("enabled", false)), func() -> void: scenario_requested.emit(entry_id), 32)
		button.custom_minimum_size = Vector2(168, 110)
		button.tooltip_text = str(entry.get("reason", ""))
		var subtitle := str(entry.get("subtitle", ""))
		if selected and not subtitle.is_empty():
			var subtitle_label := Label.new()
			subtitle_label.text = subtitle
			subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			subtitle_label.add_theme_font_override("font", _body_font)
			subtitle_label.add_theme_font_size_override("font_size", 20)
			subtitle_label.add_theme_color_override("font_color", GOLD)
			column.add_child(subtitle_label)


func _build_factions() -> void:
	_faction_scroll = _scroll(_stage, _box("factions"))
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 10)
	_faction_scroll.add_child(flow)
	for entry: Dictionary in _model.get("factions", []):
		var entry_id := str(entry.get("id", ""))
		var selected := entry_id == str(_model.get("faction_id", ""))
		var button := _button(flow, str(entry.get("label", "")), "faction:" + entry_id, selected,
			bool(entry.get("enabled", false)), func() -> void: faction_requested.emit(entry_id), 25)
		button.custom_minimum_size = Vector2(148, 60)
		button.tooltip_text = "아직 오픈되지 않았습니다" if not bool(entry.get("enabled", false)) else str(entry.get("reason", ""))
		button.clip_text = true


func _detail_text(column: VBoxContainer, text_value: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", _body_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	column.add_child(label)
	return label


func _build_details() -> void:
	_details = _scroll(_stage, _box("details"))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	_details.add_child(column)
	for pair: Array in [["군주", _model.get("leader", "")], ["수도", _model.get("capital", "")], ["주요 인물", _model.get("key_people", "")]]:
		if not str(pair[1]).is_empty():
			var info := _detail_text(column, str(pair[0]) + "    " + str(pair[1]), 24, IVORY)
			if pair[0] == "주요 인물":
				info.mouse_filter = Control.MOUSE_FILTER_PASS
				info.tooltip_text = str(_model.get("key_people_detail", ""))
	var subtitle := str(_model.get("tagline", ""))
	if not subtitle.is_empty():
		_detail_text(column, subtitle, 24, GOLD)
	var description := str(_model.get("description", ""))
	if not description.is_empty():
		_detail_text(column, description, 24, MUTED)
	for entry: Dictionary in _model.get("starting_facts", []):
		_detail_text(column, str(entry.get("label", "")) + "  " + str(entry.get("value", "")), 24, MUTED)


func _build_choices(list_key: String, selected_key: String, caption: String, outgoing: Signal) -> void:
	_label(_stage, caption, _box(list_key + "_label"), 26, GOLD, true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_place(_stage, row, _box(list_key))
	for entry: Dictionary in _model.get(list_key, []):
		var entry_id := str(entry.get("id", ""))
		var selected := entry_id == str(_model.get(selected_key, ""))
		var caption_value := str(entry.get("label", "")) + ("  ✓" if selected else "")
		var button := _button(row, caption_value, list_key + ":" + entry_id, selected,
			bool(entry.get("enabled", false)), func() -> void: outgoing.emit(entry_id), 25)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 60
		button.tooltip_text = str(entry.get("reason", ""))
		button.clip_text = true


func _has_enabled_choice(entries: Array, chosen_id: String) -> bool:
	if chosen_id.is_empty():
		return false
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) == chosen_id:
			return bool(entry.get("enabled", false))
	return false


func _can_start() -> bool:
	if _busy or not bool(_model.get("can_start", false)):
		return false
	for pair: Array in [["scenarios", "scenario_id"], ["factions", "faction_id"], ["modes", "mode_id"], ["difficulty", "difficulty_id"]]:
		if not _has_enabled_choice(_model.get(pair[0], []), str(_model.get(pair[1], ""))):
			return false
	return true


func _request_start() -> void:
	if not _can_start():
		return
	var selection := current_selection()
	_busy = true
	_model["busy"] = true
	_render()
	start_requested.emit(selection)
