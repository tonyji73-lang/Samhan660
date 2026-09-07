extends Control

signal next_requested
signal skip_requested
signal auto_changed(enabled: bool)
signal menu_requested

var background: TextureRect
var title_label: Label
var body_label: Label
var speaker_label: Label
var left_portrait: TextureRect
var right_portrait: TextureRect
var versus_label: Label
var next_button: Button
var skip_button: Button
var auto_button: CheckButton
var elapsed: float = 0.0
var full_text: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	background = TextureRect.new()
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.025, 0.035, 0.16)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	left_portrait = _portrait(0.06, 0.32)
	right_portrait = _portrait(0.68, 0.94)
	versus_label = _label(38)
	versus_label.add_theme_color_override("font_outline_color", Color("241c16"))
	versus_label.add_theme_constant_override("outline_size", 6)
	versus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	versus_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	versus_label.anchor_top = 0.48
	versus_label.anchor_bottom = 0.69
	add_child(versus_label)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.anchor_top = 0.75
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.035, 0.03, 0.95)
	style.border_color = Color("bca471")
	style.border_width_top = 2
	style.content_margin_left = 40
	style.content_margin_right = 40
	style.content_margin_top = 12
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	title_label = _label(27)
	column.add_child(title_label)
	speaker_label = _label(21)
	speaker_label.add_theme_color_override("font_color", Color("dfbf7d"))
	column.add_child(speaker_label)
	body_label = _label(23)
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body_label)
	var controls := HBoxContainer.new()
	column.add_child(controls)
	var menu := Button.new()
	menu.text = "메뉴 / Esc"
	menu.pressed.connect(func(): menu_requested.emit())
	controls.add_child(menu)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(spacer)
	auto_button = CheckButton.new()
	auto_button.text = "자동 진행"
	auto_button.toggled.connect(func(enabled: bool): auto_changed.emit(enabled))
	controls.add_child(auto_button)
	skip_button = Button.new()
	skip_button.text = "건너뛰기"
	skip_button.pressed.connect(func(): skip_requested.emit())
	controls.add_child(skip_button)
	next_button = Button.new()
	next_button.text = "다음"
	next_button.pressed.connect(func(): next_requested.emit())
	controls.add_child(next_button)
	for button: Control in controls.get_children():
		button.add_theme_font_size_override("font_size", 21)
		button.custom_minimum_size.y = 42
	hide()


func _label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("f5ead4"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _portrait(left: float, right: float) -> TextureRect:
	var portrait := TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.anchor_left = left
	portrait.anchor_right = right
	portrait.anchor_top = 0.17
	portrait.anchor_bottom = 0.72
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	return portrait


func show_step(step: Dictionary, catalog: Dictionary) -> void:
	var mode: String = str(step.get("mode", "illustrated"))
	background.visible = mode != "map"
	background.texture = _texture(str(catalog.get("asset_root", "")), str(step.get("background", "")))
	left_portrait.texture = _texture(str(catalog.get("portrait_root", "")), str(step.get("left_portrait", step.get("portrait", ""))))
	right_portrait.texture = _texture(str(catalog.get("portrait_root", "")), str(step.get("right_portrait", "")))
	left_portrait.visible = left_portrait.texture != null
	right_portrait.visible = right_portrait.texture != null
	title_label.text = str(step.get("title", "전황" if mode == "map" else ""))
	speaker_label.text = str(step.get("speaker", ""))
	speaker_label.visible = not speaker_label.text.is_empty()
	versus_label.visible = mode == "battle_vs"
	versus_label.text = "%s  %s명     대     %s  %s명" % [step.get("left_name", ""), step.get("left_troops", ""), step.get("right_name", ""), step.get("right_troops", "")]
	full_text = str(step.get("text", ""))
	for result: Dictionary in step.get("results", []):
		var result_text: String = "%s  %s" % [result.get("label", ""), result.get("value", "")]
		var amount: String = str(result.get("amount", ""))
		if result.has("zero_text") and amount.is_valid_float() and amount.to_float() == 0.0:
			result_text = str(result.zero_text)
		full_text += result_text + "\n"
	body_label.text = full_text.strip_edges()
	body_label.visible_characters = 0
	elapsed = 0.0
	show()
	next_button.grab_focus()


func _texture(root_path: String, file: String) -> Texture2D:
	if file.is_empty():
		return null
	var path: String = file if file.begins_with("res://") else root_path + file
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func tick(delta: float) -> void:
	elapsed += delta
	body_label.visible_characters = mini(body_label.text.length(), int(elapsed * 45.0))


func complete_text() -> bool:
	if body_label.visible_characters < body_label.text.length():
		body_label.visible_characters = body_label.text.length()
		elapsed = float(body_label.text.length()) / 45.0
		return true
	return false
