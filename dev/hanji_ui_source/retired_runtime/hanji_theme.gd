extends RefCounted
const Atlas = preload("res://ui/light_atlas_v1/atlas_theme.gd")
const PAPER = Color("f2ecde")
const INK = Color("302a23")
const RED = Color("8d3027")
const LINE = Color("b9ab90")
static func make_theme() -> Theme:
	var result: Theme = Atlas.make_theme()
	result.default_font_size = 24
	result.set_color("font_color", "Label", INK)
	var line := StyleBoxLine.new()
	line.color = LINE
	line.thickness = 1
	result.set_stylebox("separator", "HSeparator", line)
	return result
static func button(control: Button, selected: bool = false, primary: bool = false) -> void:
	Atlas.apply_button(control, selected, "tab" if not primary else "primary")
	if primary:
		control.add_theme_stylebox_override("normal", Atlas.panel(RED, RED, 0, 0))
	elif selected:
		var style := Atlas.panel(Color.TRANSPARENT, RED, 0, 0)
		style.border_width_bottom = 3
		control.add_theme_stylebox_override("normal", style)
		control.add_theme_color_override("font_color", RED)
	control.custom_minimum_size.y = 52
