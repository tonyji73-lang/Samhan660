extends RefCounted
## Scoped decoration: retain inherited body fonts, control metrics and command wiring.
const City = preload("res://ui/living_city_v1/living_city_theme.gd")

static func frame(panel: PanelContainer) -> void:
	City.Decoration.attach(panel, "work_panel")

static func heading() -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", City.TITLE_FONT)
	label.add_theme_font_size_override("font_size", 30)
	label.add_theme_color_override("font_color", City.GOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

static func primary(button: Button) -> void:
	var original_font := button.get_theme_font("font")
	var original_size := button.get_theme_font_size("font_size")
	var minimum := button.custom_minimum_size
	var margins: Dictionary = {}
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := button.get_theme_stylebox(state)
		margins[state] = Vector4(style.get_content_margin(SIDE_LEFT), style.get_content_margin(SIDE_RIGHT), style.get_content_margin(SIDE_TOP), style.get_content_margin(SIDE_BOTTOM))
	City.button(button, false, true)
	button.add_theme_font_override("font", original_font)
	button.add_theme_font_size_override("font_size", original_size)
	button.custom_minimum_size = minimum
	for state: String in margins:
		var style := button.get_theme_stylebox(state)
		var values: Vector4 = margins[state]
		style.content_margin_left = values.x
		style.content_margin_right = values.y
		style.content_margin_top = values.z
		style.content_margin_bottom = values.w
