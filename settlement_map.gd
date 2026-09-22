extends "res://map_area.gd"
## Campaign presentation only; coordinates and commands remain in the host.
signal settlement_selected(id: String)
const ART = "res://assets/ui_handoff/"
const KOREA_DRAFT = "res://assets/map_review/korea_draft_v1/terrain_korea_overview_candidate_v1_1024x1536.png"
const KOREA_RECT = Rect2(2048, 1024, 2048, 3072)
const EAST_DETAIL = "res://assets/map_review/east_coast_detail_v1/terrain_east_coast_detail_draft_v1_1254.png"
const EAST_RECT = Rect2(3584, 2048, 512, 512)
const CASTLE_WORLD_WIDTH = 130.0
const CASTLE_MARKER_THRESHOLD = 40.0
const MIN_CASTLE_HIT_SIZE = 32.0
var east_detail: TextureRect
var east_comparison: bool = false
var korea_preview: bool = false
var prior_camera: Vector3
var campaign: Node
var terrain: TextureRect
var fortress: Texture2D
var selected: String = "dalgubeol"
var preview_source: String = ""
var flags: Dictionary = {}
var selection_layer: Node2D
var roads_layer: Node2D

class CastleButton extends Button:
	var map_view: Control
	func _has_point(point: Vector2) -> bool:
		if not Rect2(Vector2.ZERO, size).has_point(point): return false
		if not map_view.korea_preview: return true
		# Minimum-size icons overlap at overview zoom. Give the nearest icon
		# center the shared hit area, instead of whichever was added last.
		var map_point := position + point
		var distance := map_point.distance_squared_to(position + size / 2)
		for other: Button in map_view.city_buttons.values():
			if other == self or not other.visible: continue
			if other.get_rect().has_point(map_point) and map_point.distance_squared_to(other.position + other.size / 2) < distance:
				return false
		return true

func _ready() -> void:
	fortress = load(ART + "korean_fortress_demo_rgba.png")
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	super._ready()
	terrain = TextureRect.new()
	terrain.texture = load(ART + "terrain_c03_r02_coast_fix_v2_1254.png")
	terrain.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	terrain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terrain.z_index = -9
	add_child(terrain)
	east_detail = TextureRect.new()
	east_detail.texture = load(EAST_DETAIL)
	east_detail.material = preload("res://assets/map_render/east_coast_join_v1.tres")
	east_detail.use_parent_material = false
	east_detail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	east_detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	east_detail.z_index = -8
	east_detail.hide()
	add_child(east_detail)
	roads_layer = Node2D.new()
	roads_layer.z_index = -5
	add_child(roads_layer)
	roads_layer.draw.connect(_draw_live_roads)
	selection_layer = Node2D.new()
	selection_layer.z_index = 3000
	add_child(selection_layer)
	selection_layer.draw.connect(_draw_selection)
	_layout_city_buttons()

func _collect_city_buttons() -> void:
	for id: String in WORLD_CITY_MAP_UV:
		var b := CastleButton.new()
		b.map_view = self
		b.flat = true
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(b)
		var art := TextureRect.new()
		art.texture = fortress
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(art)
		b.pressed.connect(func(): settlement_selected.emit(id))
		city_buttons[id] = b
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_color_override("font_outline_color", Color("111918"))
		label.add_theme_constant_override("outline_size", 7)
		add_child(label)
		city_labels[id] = label
		var flag := Label.new()
		flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flag.add_theme_color_override("font_outline_color", Color.BLACK)
		flag.add_theme_constant_override("outline_size", 6)
		add_child(flag)
		flags[id] = flag

func anchor(id: String) -> Vector2:
	return _map_uv_to_position(WORLD_CITY_MAP_UV[id], _get_displayed_map_rect())

func _refresh_marker_data() -> void:
	if campaign == null or not is_node_ready(): return
	_update_territory_colors(campaign.provinces, selected)
	_layout_city_buttons()

func _layout_city_buttons() -> void:
	if not is_node_ready(): return
	var rect := _get_displayed_map_rect()
	map_background.position = rect.position
	map_background.size = rect.size
	_layout_map_details(rect)
	if terrain != null:
		var bounds: Rect2 = KOREA_RECT if korea_preview else Rect2(3072,2048,1024,1024)
		terrain.position = rect.position + bounds.position / MAP_TEXTURE_SIZE * rect.size
		terrain.size = bounds.size / MAP_TEXTURE_SIZE * rect.size
	map_background.visible = not korea_preview
	if east_detail != null:
		east_detail.visible = korea_preview and east_comparison
		east_detail.position = rect.position + EAST_RECT.position / MAP_TEXTURE_SIZE * rect.size
		east_detail.size = EAST_RECT.size / MAP_TEXTURE_SIZE * rect.size
	# Old borders do not match the corrected coast; accessible on the original map.
	territory_overlay.hide()
	var vectors := get_node_or_null("TerritoryVectorBorders")
	if vectors != null: vectors.hide()
	for entry: Array in border_lines + outside_border_lines: entry[2].hide()
	for i: int in range(road_lines.size()):
		road_lines[i].hide()
	if korea_preview:
		for entry: Array in strategic_lines:
			for line: Line2D in entry[2]: line.hide()
	for id: String in city_buttons:
		var p: Dictionary = campaign.provinces.get(id, {}) if campaign != null else {}
		var b: Button = city_buttons[id]
		b.visible = not p.is_empty() and (not korea_preview or KOREA_RECT.has_point(WORLD_CITY_MAP_UV[id] * MAP_TEXTURE_SIZE))
		var width := CASTLE_WORLD_WIDTH * rect.size.x / MAP_TEXTURE_SIZE.x
		# Artwork follows terrain scale; only the independent hit area has a minimum.
		b.size = Vector2.ONE * maxf(MIN_CASTLE_HIT_SIZE, width)
		b.position = anchor(id) - b.size * Vector2(0.5, 0.67)
		var art: TextureRect = b.get_child(0)
		art.size = Vector2.ONE * width
		art.position = (b.size - art.size) * Vector2(0.5, 0.67)
		art.visible = width >= CASTLE_MARKER_THRESHOLD
		var visual_width := width if art.visible else 12.0
		var label: Label = city_labels[id]
		label.visible = b.visible
		label.text = str(p.get("name", WORLD_CITY_NAMES.get(id, id)))
		var important: bool = id == selected or id in ["dalgubeol", "geumseong", "sabeol", "chupungnyeong", "daegaya"]
		if map_zoom >= 3.5 and important:
			label.text += "\n%d명" % int(p.get("troops", 0))
		label.add_theme_font_size_override("font_size", 18 if map_zoom >= 3.5 else 15)
		label.size = Vector2(160, 52)
		label.position = anchor(id) + Vector2(-80, visual_width * 0.3)
		var flag: Label = flags[id]
		flag.visible = b.visible
		flag.text = "⚑ " + str(p.get("faction", ""))
		flag.add_theme_color_override("font_color", WORLD_FACTION_COLORS.get(p.get("faction", ""), Color("d6b678")))
		flag.position = anchor(id) + Vector2(-22, -visual_width * 0.65 - (10 if not art.visible else 0))
		b.tooltip_text = "%s · %s\n병력 %d명" % [p.get("name", id), p.get("faction", ""), p.get("troops", 0)]
		if map_zoom < 2.4:
			label.visible = b.visible and (id == selected or int(p.get("troops", 0)) >= 20000)
			flag.visible = label.visible
	# Prioritize the selected castle and the focal five when labels overlap.
	var ids: Array = city_labels.keys()
	ids.sort_custom(func(a, b): return _label_priority(a) > _label_priority(b))
	var occupied: Array[Rect2] = []
	for id: String in ids:
		var text: Label = city_labels[id]
		if not text.visible: continue
		var bounds := Rect2(text.position, Vector2(160, 52 if text.text.contains("\n") else 26))
		if occupied.any(func(other): return other.intersects(bounds)):
			text.hide()
			flags[id].hide()
		else: occupied.append(bounds)
	if selection_layer != null: selection_layer.queue_redraw()
	if roads_layer != null: roads_layer.queue_redraw()

func _label_priority(id: String) -> int:
	if id == selected: return 3
	if id in ["dalgubeol", "geumseong", "sabeol", "chupungnyeong", "daegaya"]: return 2
	return 1

func _draw_live_roads() -> void:
	if campaign == null or map_zoom < 2.4: return
	for source: String in campaign.province_connections:
		for target: String in campaign.province_connections[source]:
			if source >= target or not WORLD_CITY_MAP_UV.has(source) or not WORLD_CITY_MAP_UV.has(target): continue
			if korea_preview and (not KOREA_RECT.has_point(WORLD_CITY_MAP_UV[source]*MAP_TEXTURE_SIZE) or not KOREA_RECT.has_point(WORLD_CITY_MAP_UV[target]*MAP_TEXTURE_SIZE)): continue
			roads_layer.draw_line(anchor(source), anchor(target), Color("d6b678"), 1.8, true)

func set_korea_preview(enabled: bool) -> void:
	if enabled: prior_camera = Vector3(map_zoom,map_pan_offset.x,map_pan_offset.y)
	korea_preview = enabled
	terrain.texture = load(KOREA_DRAFT if enabled else ART + "terrain_c03_r02_coast_fix_v2_1254.png")
	if not enabled:
		east_comparison = false
		map_zoom = prior_camera.x
		map_pan_offset = Vector2(prior_camera.y,prior_camera.z)
	_layout_city_buttons()

func set_east_comparison(enabled: bool) -> void:
	east_comparison = enabled and korea_preview
	_layout_city_buttons()

func frame_korea_preview() -> void:
	var base := _get_base_map_rect()
	var atlas_size: Vector2 = base.size * KOREA_RECT.size / MAP_TEXTURE_SIZE
	map_zoom = minf(size.x/atlas_size.x,size.y/atlas_size.y)*0.96
	map_pan_offset = base.size*map_zoom*(Vector2(0.5,0.5)-KOREA_RECT.get_center()/MAP_TEXTURE_SIZE)
	_clamp_map_pan(); _layout_city_buttons()

func _set_map_zoom(new_zoom: float, focus_position: Vector2) -> void:
	if not korea_preview:
		super._set_map_zoom(new_zoom,focus_position)
		return
	# Same world rectangle and focus-preserving transform; allow the tall atlas to fit.
	var old := _get_displayed_map_rect()
	if old.size.x <= 0 or old.size.y <= 0: return
	var uv := (focus_position-old.position)/old.size
	map_zoom = clampf(new_zoom,0.2,MAP_MAX_ZOOM)
	var world_size := _get_base_map_rect().size*map_zoom
	map_pan_offset = focus_position-(size-world_size)*0.5-uv*world_size
	_clamp_map_pan(); _layout_city_buttons()

func focus_region() -> void:
	focus_on_province("dalgubeol", 4.2)
	map_pan_offset.y += _get_displayed_map_rect().size.y * 0.01
	_clamp_map_pan()
	_layout_city_buttons()

func _draw_selection() -> void:
	for id: String in city_buttons:
		var b: Button = city_buttons[id]
		if not b.visible or b.size.x >= CASTLE_MARKER_THRESHOLD: continue
		var center := anchor(id)
		var diamond := PackedVector2Array([center+Vector2(0,-6),center+Vector2(6,0),center+Vector2(0,6),center+Vector2(-6,0)])
		selection_layer.draw_colored_polygon(diamond, Color("d6b678"))
		selection_layer.draw_polyline(PackedVector2Array([diamond[0],diamond[1],diamond[2],diamond[3],diamond[0]]),Color("111918"),2,true)
	if WORLD_CITY_MAP_UV.has(selected):
		var selected_width: float = CASTLE_WORLD_WIDTH * _get_displayed_map_rect().size.x / MAP_TEXTURE_SIZE.x
		selection_layer.draw_arc(anchor(selected), 12 if selected_width < CASTLE_MARKER_THRESHOLD else selected_width * 0.35, 0, TAU, 48, Color("f0d28a"), 2, true)
	if WORLD_CITY_MAP_UV.has(preview_source) and WORLD_CITY_MAP_UV.has(selected):
		selection_layer.draw_line(anchor(preview_source), anchor(selected), Color("f0d28a"), 3, true)

func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and not event.pressed: return
	super._on_map_gui_input(event)
