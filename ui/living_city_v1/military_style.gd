extends RefCounted
## Presentation only. Reuse the existing Living City art, fonts and portraits.
const City = preload("res://ui/living_city_v1/living_city_theme.gd")
const Industry = preload("res://ui/living_city_v1/industry_style.gd")

static func label(parent: Node, text: String, size: int = 23) -> Label:
	var node := Label.new(); node.text=text; node.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size",size); node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	parent.add_child(node); return node

static func section(parent: Node, title: String) -> VBoxContainer:
	var panel := PanelContainer.new(); panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style := City.panel(); style.set_content_margin_all(16); panel.add_theme_stylebox_override("panel",style)
	parent.add_child(panel); var box := VBoxContainer.new(); box.add_theme_constant_override("separation",12); panel.add_child(box)
	var heading := Industry.heading(); heading.text=title; heading.add_theme_color_override("font_color",City.INK); box.add_child(heading)
	return box

static func scroll(parent: Node) -> VBoxContainer:
	var node := ScrollContainer.new(); node.size_flags_vertical=Control.SIZE_EXPAND_FILL; node.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	node.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; node.follow_focus=true; parent.add_child(node)
	var box := VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; box.add_theme_constant_override("separation",14); node.add_child(box); return box

static func portrait(parent: Node, texture: Texture2D, size: Vector2) -> TextureRect:
	var node := TextureRect.new(); node.custom_minimum_size=size; node.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; node.texture=texture; parent.add_child(node); return node

static func texture(c: Node, id: String) -> Texture2D:
	if id.is_empty(): return null
	# Same year/person resolver and face framing as the domestic candidate cards.
	var name: String=str(c.get_officer(id).get("name",""))
	if name=="선덕여왕":
		var atlas:=AtlasTexture.new(); atlas.atlas=preload("res://assets/portraits/overlays/seondeok_queen_overlay.png"); atlas.region=Rect2(240,0,480,560); return atlas
	return c.map_area._get_portrait_texture(name)

static func card(parent: Node, c: Node, id: String, selected: bool, info: String, reason: String, callback: Callable) -> Button:
	var panel := PanelContainer.new(); panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	var style := City.Atlas.panel(City.PAPER,City.GOLD if selected else City.LINE,3 if selected else 1,3)
	style.set_content_margin_all(12); panel.add_theme_stylebox_override("panel",style); parent.add_child(panel)
	var row := HBoxContainer.new(); row.add_theme_constant_override("separation",12); panel.add_child(row)
	portrait(row,texture(c,id),Vector2(94,112))
	var box := VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(box)
	var name: String=str(c.get_officer(id).get("name","미지정"))
	var button := Button.new(); button.text=("선택 · " if selected else "")+name; button.clip_text=true; button.tooltip_text=name
	button.set_meta("officer_id",id); box.add_child(button); City.button(button,selected); button.pressed.connect(callback)
	label(box,info,21); var status := label(box,reason,20); status.add_theme_color_override("font_color",City.INK if reason.ends_with("가능") else City.RED)
	City.Decoration.attach(panel,"officer_card").select(selected)
	return button

static func wire_focus(root: Control) -> void:
	var controls: Array[Control]=[]
	_collect_focus(root,controls)
	for n: int in range(controls.size()):
		controls[n].focus_next=controls[n].get_path_to(controls[(n+1)%controls.size()])
		controls[n].focus_previous=controls[n].get_path_to(controls[(n-1+controls.size())%controls.size()])

static func _collect_focus(node: Node, controls: Array[Control]) -> void:
	if node is Control:
		if not node.is_visible_in_tree(): return
		if node.focus_mode==Control.FOCUS_ALL and not (node is BaseButton and node.disabled): controls.append(node)
	for child: Node in node.get_children(): _collect_focus(child,controls)

