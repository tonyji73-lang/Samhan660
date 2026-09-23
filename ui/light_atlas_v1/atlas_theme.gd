extends RefCounted
## Scoped to the faction chooser and settlement view; never a global game theme.

const PAPER := Color("f4f0e6")
const SURFACE := Color("fcfaf5")
const INK := Color("173035")
const MUTED := Color("5c6968")
const LINE := Color("d3cdbf")
const ACCENT := Color("bf4d13")
const HOVER := Color("a9400e")
const PRESSED := Color("8e350a")
const DISABLED := Color("e6e1d7")
const WHITE := Color("ffffff")
const FONT: FontFile = preload("res://ui/faction_selection_v1/assets/SamhanUISans-Medium.ttf")
const BOLD_FONT: FontFile = preload("res://ui/faction_selection_v1/assets/SamhanUISans-SemiBold.ttf")
const ICON_ROOT := "res://ui/light_atlas_v1/icons/"


static func panel(fill: Color = SURFACE, border: Color = LINE, width: int = 1, radius: int = 6) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(radius)
	result.set_content_margin_all(12)
	return result


static func icon(name: String) -> Texture2D:
	return load(ICON_ROOT + name + ".svg") as Texture2D


static func apply_button(button: Button, selected: bool = false, kind: String = "default") -> void:
	var primary := kind == "primary" or (selected and kind != "tab")
	var normal := panel(ACCENT if primary else SURFACE)
	var hover := panel(HOVER if primary else Color("eee5d5"))
	var pressed := panel(PRESSED if primary else Color("e8d7bb"))
	if kind == "tab":
		for style: StyleBoxFlat in [normal, hover, pressed]:
			style.set_border_width_all(0)
			style.set_corner_radius_all(0)
		normal.bg_color = Color.TRANSPARENT
		if selected:
			normal.border_color = ACCENT
			normal.border_width_bottom = 3
	var focus := panel(Color.TRANSPARENT, INK, 2)
	var disabled_style := panel(DISABLED, LINE)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_stylebox_override("focus", focus)
	var normal_color := WHITE if primary else (ACCENT if selected else INK)
	for item: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(item, normal_color)
	for item: String in ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		button.add_theme_color_override(item, normal_color)
	button.add_theme_color_override("font_disabled_color", Color("7b807a"))
	button.add_theme_color_override("icon_disabled_color", Color("7b807a"))
	button.add_theme_font_override("font", BOLD_FONT)
	button.add_theme_constant_override("h_separation", 10)
	button.add_theme_constant_override("icon_max_width", 24)
	button.expand_icon = true
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 22
	result.set_color("font_color", "Label", INK)
	result.set_color("default_color", "RichTextLabel", INK)
	result.set_stylebox("panel", "PanelContainer", panel())
	result.set_stylebox("panel", "PopupMenu", panel(SURFACE))
	result.set_stylebox("hover", "PopupMenu", panel(Color("eee5d5"), Color.TRANSPARENT, 0))
	result.set_color("font_color", "PopupMenu", INK)
	result.set_color("font_hover_color", "PopupMenu", INK)
	result.set_color("font_disabled_color", "PopupMenu", MUTED)
	result.set_stylebox("panel", "TooltipPanel", panel(SURFACE, INK))
	result.set_color("font_color", "TooltipLabel", INK)
	result.set_font_size("font_size", "TooltipLabel", 20)
	for type_name: String in ["Button", "OptionButton"]:
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var fill := DISABLED if state == "disabled" else Color("eee5d5") if state != "normal" else SURFACE
			result.set_stylebox(state, type_name, panel(fill))
		result.set_stylebox("focus", type_name, panel(Color.TRANSPARENT, INK, 2))
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			result.set_color(state, type_name, INK)
		result.set_color("font_disabled_color", type_name, MUTED)
	result.set_constant("modulate_arrow", "OptionButton", 1)
	for type_name: String in ["VScrollBar", "HScrollBar"]:
		result.set_stylebox("scroll", type_name, panel(PAPER, Color.TRANSPARENT, 0, 3))
		for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
			var grabber := panel(Color("a8ada4"), Color.TRANSPARENT, 0, 3)
			grabber.set_content_margin_all(6)
			result.set_stylebox(state, type_name, grabber)
	return result
