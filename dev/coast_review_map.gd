extends "res://map_area.gd"
signal anchor_selected(id: String)
const ASSETS="res://assets/map_review/coast_fix_v2/"
const TILE=Rect2(3072,2048,1024,1024)
var tile: TextureRect
var before: Texture2D
var after: Texture2D
var fortress: Texture2D
var selected: String="geumgwan"
var corrected: bool=true
var show_mask: bool=false
var show_castles: bool=true
var show_routes: bool=true
var mask_image: Image
var anchor_layer: Node2D

func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	before=load(ASSETS+"terrain_c03_r02_before_1254.png")
	after=load(ASSETS+"terrain_c03_r02_coast_fix_v2_1254.png")
	fortress=load(ASSETS+"korean_fortress_demo_rgba.png")
	super._ready()
	tile=TextureRect.new(); tile.texture=after; tile.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; tile.mouse_filter=Control.MOUSE_FILTER_IGNORE; tile.z_index=-9; add_child(tile)
	mask_image=load(WorldMapData.TERRITORY_ID_MAP_PATH).get_image()
	var palette:=Image.create(64,2,false,Image.FORMAT_RGBA8); palette.fill(Color.TRANSPARENT)
	for n: int in range(1,64):
		var color:=Color.from_hsv(fmod(n*0.618,1),0.75,0.95,0.48)
		palette.set_pixel(n,0,color); palette.set_pixel(n,1,Color(1,0.2,0.7,0.9))
	territory_material.set_shader_parameter("territory_palette",ImageTexture.create_from_image(palette))
	anchor_layer=Node2D.new(); anchor_layer.z_index=3000; add_child(anchor_layer); anchor_layer.draw.connect(_draw_anchors)
	_layout_city_buttons()

func _collect_city_buttons() -> void:
	for id: String in WORLD_CITY_MAP_UV:
		var b:=Button.new(); b.flat=true; b.mouse_filter=Control.MOUSE_FILTER_STOP; b.tooltip_text=WORLD_CITY_NAMES.get(id,id); add_child(b)
		var art:=TextureRect.new(); art.texture=fortress; art.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); art.mouse_filter=Control.MOUSE_FILTER_IGNORE; b.add_child(art)
		b.pressed.connect(func(): selected=id; anchor_selected.emit(id); anchor_layer.queue_redraw())
		city_buttons[id]=b
		var label:=Label.new(); label.text=WORLD_CITY_NAMES.get(id,id); label.mouse_filter=Control.MOUSE_FILTER_IGNORE; label.add_theme_font_size_override("font_size",15); label.add_theme_color_override("font_outline_color",Color.BLACK); label.add_theme_constant_override("outline_size",4); add_child(label); city_labels[id]=label

func _refresh_marker_data() -> void:
	pass # No campaign, save, personnel or faction state is created in this viewer.

func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and not event.pressed: return
	super._on_map_gui_input(event)

func anchor(id: String) -> Vector2:
	return _map_uv_to_position(WORLD_CITY_MAP_UV[id],_get_displayed_map_rect())

func mask_id(id: String) -> int:
	var pixel: Vector2i=Vector2i(WORLD_CITY_MAP_UV[id]*Vector2(mask_image.get_size()))
	return roundi(mask_image.get_pixelv(pixel).a*255)

func _layout_city_buttons() -> void:
	if not is_node_ready(): return
	var rect: Rect2=_get_displayed_map_rect()
	map_background.position=rect.position; map_background.size=rect.size
	_layout_map_details(rect)
	if tile!=null:
		tile.position=rect.position+TILE.position/WorldMapData.MAP_TEXTURE_SIZE*rect.size
		tile.size=TILE.size/WorldMapData.MAP_TEXTURE_SIZE*rect.size
		tile.texture=after if corrected else before
	territory_overlay.visible=show_mask
	var vectors: Node=get_node_or_null("TerritoryVectorBorders")
	if vectors!=null: vectors.visible=show_mask
	for entry: Array in border_lines+outside_border_lines: entry[2].visible=show_mask
	for line: Line2D in road_lines: line.visible=show_routes and map_zoom>=MAP_DETAIL_ZOOM
	for entry: Array in strategic_lines:
		for line: Line2D in entry[2]: line.visible=show_routes and line.visible
	for id: String in city_buttons:
		var b: Button=city_buttons[id]
		var width: float=clampf(100.0*rect.size.x/6144.0,18,110)
		b.size=Vector2.ONE*width
		# The center of the fortress ground plane is the fixed city anchor.
		b.position=anchor(id)-b.size*Vector2(0.5,0.65)
		b.visible=show_castles
		city_labels[id].position=anchor(id)+Vector2(-38,width*0.4)
	queue_redraw()
	if anchor_layer!=null: anchor_layer.queue_redraw()

func _draw() -> void:
	if tile==null: return
	draw_rect(Rect2(tile.position,tile.size),Color(1,0.75,0.3),false,2)

func _draw_anchors() -> void:
	for id: String in city_buttons:
		var p: Vector2=anchor(id)
		anchor_layer.draw_circle(p,3,Color.YELLOW if id==selected else Color.WHITE)
		if id==selected: anchor_layer.draw_arc(p,14,0,TAU,32,Color.YELLOW,2,true)

func frame_tile() -> void:
	map_zoom=clampf(minf(size.x/1250,size.y/1250)*6144/_get_base_map_rect().size.x,MAP_MIN_ZOOM,MAP_MAX_ZOOM)
	var rect: Rect2=_get_base_map_rect(); var uv: Vector2=TILE.get_center()/WorldMapData.MAP_TEXTURE_SIZE
	map_pan_offset=rect.size*map_zoom*(Vector2(0.5,0.5)-uv)
	_clamp_map_pan(); _layout_city_buttons()
