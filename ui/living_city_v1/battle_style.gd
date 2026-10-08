extends RefCounted
const UI=preload("res://ui/living_city_v1/military_style.gd")
const Flag=preload("res://ui/living_city_v1/faction_flag.gd")
const Map=preload("res://world_map_data.gd")
static func frame(host: Control,title: String) -> VBoxContainer:
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); host.mouse_filter=Control.MOUSE_FILTER_STOP; host.theme=UI.City.make_theme()
	var shade:=ColorRect.new(); shade.color=Color(0,0,0,0.8); host.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel:=PanelContainer.new(); host.add_child(panel); panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.set_anchor(SIDE_LEFT,0.035,true); panel.set_anchor(SIDE_RIGHT,0.965,true); panel.set_anchor(SIDE_TOP,0.03,true); panel.set_anchor(SIDE_BOTTOM,0.97,true)
	var style:=UI.City.panel(true); style.set_content_margin_all(24); panel.add_theme_stylebox_override("panel",style); UI.Industry.frame(panel)
	var box:=VBoxContainer.new(); box.add_theme_constant_override("separation",12); panel.add_child(box)
	var heading:=UI.Industry.heading(); heading.text=title; box.add_child(heading); return box
static func button(parent: Node,text: String,action: Callable,primary: bool=false) -> Button:
	var b:=Button.new(); b.text=text; b.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; parent.add_child(b); UI.City.button(b,false,primary); b.pressed.connect(action); return b
static func side(parent: Node,c: Node,faction: String,officer: String,title: String) -> void:
	var row:=HBoxContainer.new(); parent.add_child(row)
	var flag:=Flag.new(); flag.color=Map.FACTION_COLORS.get(faction,Color.GRAY); flag.tooltip_text="지도 세력색의 게임용 깃발"; row.add_child(flag)
	UI.portrait(row,UI.texture(c,officer),Vector2(90,100))
	UI.label(row,title+"\n"+faction+" · "+str(c.get_officer(officer).get("name","기록된 지휘관 없음")),25)
static func clear(node: Node) -> void:
	for child: Node in node.get_children(): node.remove_child(child); child.queue_free()
