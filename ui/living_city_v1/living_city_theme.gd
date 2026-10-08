extends RefCounted
## Living City: dark lacquer/bronze frame, cream work surface, gold selection.
const Atlas = preload("res://ui/light_atlas_v1/atlas_theme.gd")
const Art = preload("res://ui/living_city_v1/ornament_resources.gd")
const Decoration = preload("res://ui/living_city_v1/ornament_overlay.gd")
const TITLE_FONT = preload("res://ui/living_city_v1/assets/fonts/nanummyeongjo/title_font.res")
const PAPER = Color("eee5d2")
const INK = Color("382a1e")
const RED = Color("812a22")
const LINE = Color("b5a07b")
const DARK = Color("201e1a")
const GOLD = Color("d5b46f")
const LIGHT = Color("f4e7c9")

static func panel(dark: bool = false) -> StyleBoxFlat:
	return Atlas.panel(DARK if dark else PAPER, GOLD if dark else LINE, 2, 2)

static func make_theme() -> Theme:
	var result: Theme = Atlas.make_theme()
	result.default_font_size = 23
	result.set_color("font_color", "Label", INK)
	var line := StyleBoxLine.new()
	line.color = LINE
	line.thickness = 1
	result.set_stylebox("separator", "HSeparator", line)
	return result

static func button(control: Button, selected: bool = false, primary: bool = false) -> void:
	var dark: bool = bool(control.get_meta("dark",false))
	Atlas.apply_button(control, false, "default")
	var fill := RED if primary else (Color("caa253") if selected else (DARK if dark else Color("eee5d2")))
	var border := GOLD if selected or dark or primary else LINE
	var normal := Atlas.panel(fill,border,2 if selected or primary else 1,3)
	normal.set_content_margin_all(9)
	control.add_theme_stylebox_override("normal",normal)
	control.add_theme_stylebox_override("hover",Atlas.panel(Color("a94030") if primary else Color("d6bd86"),GOLD,2,3))
	control.add_theme_stylebox_override("pressed",Atlas.panel(Color("622119") if primary else Color("b89961"),GOLD,2,3))
	control.add_theme_stylebox_override("focus",Atlas.panel(Color.TRANSPARENT,GOLD,3,3))
	var color := LIGHT if primary or (dark and not selected) else INK
	for state: String in ["font_color","font_focus_color","font_pressed_color"]:
		control.add_theme_color_override(state,color)
	control.add_theme_color_override("font_hover_color", LIGHT if primary else INK)
	control.add_theme_color_override("icon_normal_color",color)
	control.custom_minimum_size.y = 72 if primary else 44
	if primary:
		control.add_theme_font_override("font",Atlas.BOLD_FONT)
		control.add_theme_font_size_override("font_size",30)
		control.add_theme_stylebox_override("disabled",Atlas.panel(Color("c0b49c"),LINE,2,3))
		for state: String in ["normal","hover","pressed","hover_pressed","disabled"]:
			var tint: Color={"normal":Color.WHITE,"hover":Color(1.08,1.08,1.08),"pressed":Color(0.78,0.78,0.78),"hover_pressed":Color(0.85,0.85,0.85),"disabled":Color(0.6,0.6,0.6,0.72)}[state]
			var margin: float=9.0 if state=="normal" else 12.0
			control.add_theme_stylebox_override(state,Art.style("primary",tint,Vector4(margin,margin,margin,margin)))
		var focus := Atlas.panel(Color.TRANSPARENT,LIGHT,2,3)
		focus.draw_center=false
		control.add_theme_stylebox_override("focus",focus)
		control.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
		control.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	if dark:
		var underline: Node2D=control.get_node_or_null("Ornament_nav_underline")
		if underline==null: underline=Decoration.attach(control,"nav_underline","underline")
		underline.visible=selected
		underline.modulate=Color("624018")

