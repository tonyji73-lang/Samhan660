extends Control
## Presentation only. Province IDs are the bridge to the existing campaign.
## Never use the coordinates below for movement costs, economy, saves or AI.

signal settlement_selected(province_id: String)

const RESOURCE_DIR: String = "res://ui/korea_layout_v1/"
const MAP_ZOOM_STEP: float = 1.2
const MIN_ZOOM: float = 0.8
const MAX_ZOOM: float = 12.0
const DETAIL_THRESHOLD: float = 18.0
const SPRITE_PIVOT: Vector2 = Vector2(0.5, 0.67)
const DETAIL_DIR = RESOURCE_DIR + "central_east/"
var detail_comparison: bool = false
const CorrectedDetail = preload("res://ui/korea_layout_v1/central_east/integration/central_east_display_layer.gd")
var corrected_comparison: bool = false
var _corrected_detail = CorrectedDetail.new()
var r3_comparison: bool = false
var _r3_fill = CorrectedDetail.new()
var _detail_manifest: Dictionary = {}
var _detail_texture: Texture2D
var _detail_rect := Rect2(512,544,264,176)
var _detail_registration_valid: bool = false
var _detail_hash: String = ""

@export var map_label_font: Font
@export_range(11, 24) var map_label_size: int = 14

# Compatibility with the supplied settlement_overlay.gd. Its latest PC version
# must still be inspected before changing its preload or adding this view.
var campaign: Node
var selected: String = "dalgubeol":
	set(value):
		selected = value
		queue_redraw()
var preview_source: String = "":
	set(value):
		preview_source = value
		queue_redraw()
var map_zoom: float = 1.0
var map_pan_offset: Vector2 = Vector2.ZERO
var input_locked: bool = false
var selection_layer: Node2D = null

var faction_colors: Dictionary = {
	"신라": Color("ead188"), "백제": Color("da7565"),
	"고구려": Color("91b4d5"), "탐라": Color("c3a5d9"),
	"당": Color("d0cebd"), "백제부흥군": Color("da7565"),
	"고구려부흥군": Color("91b4d5"),
}

var _layout: Dictionary = {}
var _sites: Dictionary = {}
var _ids: Array[String] = []
var _live: Dictionary = {}
var _unknown_live_ids: Array[String] = []
var _terrain: Texture2D
var _fortress: Texture2D
var _image_size: Vector2 = Vector2(1254, 1254)
var _layout_ok: bool = false
var _terrain_polygons: Dictionary = {}
var _route_ids: Array[String] = []
var _held: bool = false
var _dragged: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _press_pan: Vector2 = Vector2.ZERO
var _last_fit_scale: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_layout_ok = _load_approved_layout()
	if _layout_ok:
		_terrain = _texture_with_mipmaps(RESOURCE_DIR + "assets/korea_approved_1254.png")
		_fortress = _texture_with_mipmaps(RESOURCE_DIR + "assets/korean_fortress_original.png")
		_layout_ok = _terrain != null and _fortress != null
		if _layout_ok:
			_layout_ok = _terrain.get_size().is_equal_approx(_image_size)
	if not _layout_ok:
		push_error("Approved Korea map: layout or approved assets could not be loaded.")
	_refresh_marker_data()
	_load_detail_candidate()
	_last_fit_scale = _fit_scale()
	queue_redraw()

func _load_detail_candidate() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DETAIL_DIR+"data/central_east_detail_manifest.json"))
	if not data is Dictionary: return
	_detail_manifest = data
	if data.get("approved_base_sha256", "") != FileAccess.get_sha256(RESOURCE_DIR+"assets/korea_approved_1254.png"): return
	var bounds: Array = data.get("native_rect_xywh", [])
	if bounds.size()!=4: return
	if not Rect2(float(bounds[0]),float(bounds[1]),float(bounds[2]),float(bounds[3])).is_equal_approx(_detail_rect): return
	_detail_texture = _texture_with_mipmaps(DETAIL_DIR+str(data.detail_texture))
	_detail_hash = FileAccess.get_sha256(DETAIL_DIR+str(data.detail_texture))
	if _detail_texture == null: return
	_detail_registration_valid = _detail_texture.get_size() == Vector2(float(data.detail_size[0]),float(data.detail_size[1]))
	if not _corrected_detail.configure(DETAIL_DIR+"data/central_east_display_mesh.json", DETAIL_DIR+str(data.detail_texture)):
		push_error(_corrected_detail.last_error)
	else:
		# Share the unchanged native texture and existing runtime mipmap policy.
		_corrected_detail._texture = _detail_texture
	if not _r3_fill.configure(DETAIL_DIR+"data/central_east_r3_fill_mesh.json", DETAIL_DIR+"assets/central_east_detail_r3.png"):
		push_error(_r3_fill.last_error)
	else:
		_r3_fill._texture = _texture_with_mipmaps(DETAIL_DIR+"assets/central_east_detail_r3.png")

func detail_auto_allowed() -> bool:
	# Replacing a file or toggling one flag alone cannot approve an unregistered candidate.
	return _detail_registration_valid and bool(_detail_manifest.get("production_auto_switch_allowed",false)) and _detail_manifest.get("status","")=="registered" and _detail_manifest.get("registered_detail_sha256","")==_detail_hash

func detail_weight() -> float:
	if not _detail_registration_valid: return 0.0
	if detail_comparison: return 1.0
	return smoothstep(1.5,2.0,terrain_pixel_scale()) if detail_auto_allowed() else 0.0

func terrain_pixel_scale() -> float:
	var pixel_transform := get_viewport().get_final_transform()*get_global_transform_with_canvas()
	return _fit_scale()*map_zoom*pixel_transform.x.length()

func detail_diagnostics() -> Dictionary:
	var detail_scale: float=terrain_pixel_scale()*264.0/1536.0
	return {"base_size":_terrain.get_size(),"detail_size":_detail_texture.get_size() if _detail_texture else Vector2.ZERO,"base_screen_pixels_per_texel":terrain_pixel_scale(),"detail_screen_pixels_per_texel":detail_scale,"higher_density_needed":detail_scale>1.25,"weight":detail_weight(),"auto_allowed":detail_auto_allowed()}

func set_detail_comparison(enabled: bool) -> void:
	r3_comparison=false
	corrected_comparison=false
	detail_comparison=enabled and _detail_registration_valid
	queue_redraw()

func set_corrected_comparison(enabled: bool) -> void:
	r3_comparison=false
	detail_comparison=false
	corrected_comparison=enabled and _detail_registration_valid and _corrected_detail.is_ready()
	queue_redraw()

func set_r3_comparison(enabled: bool) -> void:
	set_corrected_comparison(true)
	r3_comparison=enabled and corrected_comparison and _r3_fill.is_ready()
	queue_redraw()

func focus_detail() -> void:
	map_zoom=5.0
	map_pan_offset=Vector2.ZERO
	map_pan_offset=size*0.5-map_to_local(_detail_rect.get_center())
	_layout_city_buttons()

func _load_approved_layout() -> bool:
	var parser := JSON.new()
	var parse_error: Error = parser.parse(
		FileAccess.get_file_as_string(RESOURCE_DIR + "data/castle_layout_v1.json")
	)
	if parse_error != OK or not (parser.data is Dictionary):
		return false
	var candidate: Dictionary = parser.data
	var rows: Variant = candidate.get("points", null)
	var image_dimensions: Variant = candidate.get("image_size", null)
	if not (rows is Array) or rows.size() != 35:
		return false
	if not (image_dimensions is Array) or image_dimensions.size() != 2:
		return false
	var dimensions := Vector2(float(image_dimensions[0]), float(image_dimensions[1]))
	if not dimensions.is_equal_approx(Vector2(1254, 1254)):
		return false
	var points_by_id: Dictionary = {}
	var ordered_ids: Array[String] = []
	for entry: Variant in rows:
		if not (entry is Dictionary):
			return false
		var province_id: String = str(entry.get("id", ""))
		var xy: Variant = entry.get("render_xy", null)
		if province_id.is_empty() or points_by_id.has(province_id):
			return false
		if not (xy is Array) or xy.size() != 2:
			return false
		var point := Vector2(float(xy[0]), float(xy[1]))
		var sprite_width: float = float(entry.get("sprite_width_native", 0.0))
		if not point.is_finite() or not Rect2(Vector2.ZERO, dimensions).has_point(point):
			return false
		if not is_finite(sprite_width) or sprite_width <= 0.0:
			return false
		points_by_id[province_id] = entry.duplicate(true)
		ordered_ids.append(province_id)
	_layout = candidate.duplicate(true)
	_sites = points_by_id
	_ids = ordered_ids
	_image_size = dimensions
	return true


func _texture_with_mipmaps(resource_path: String) -> Texture2D:
	var resource_texture: Texture2D = load(resource_path) as Texture2D
	if resource_texture == null:
		return null
	var pixels: Image = resource_texture.get_image()
	if pixels == null or pixels.is_empty():
		return resource_texture
	if pixels.is_compressed() and pixels.decompress() != OK:
		return resource_texture
	if not pixels.has_mipmaps() and pixels.generate_mipmaps() != OK:
		return resource_texture
	return ImageTexture.create_from_image(pixels)


func set_live_provinces(provinces: Dictionary) -> void:
	# Copy only display scalars: there is no reference into mutable campaign state.
	_live.clear()
	_unknown_live_ids.clear()
	for raw_id: Variant in provinces:
		var province_id: String = str(raw_id)
		if not _sites.has(province_id):
			_unknown_live_ids.append(province_id)
			continue
		var province: Variant = provinces[raw_id]
		if not (province is Dictionary):
			continue
		_live[province_id] = {
			"name": str(province.get("name", _sites[province_id]["name"])),
			"faction": str(province.get("faction", "")),
			"troops": int(province.get("troops", 0)),
		}
	queue_redraw()


func _refresh_marker_data() -> void:
	if is_instance_valid(campaign):
		var provinces: Variant = campaign.get("provinces")
		if provinces is Dictionary:
			set_live_provinces(provinces)
	queue_redraw()


func has_site_id(province_id: String) -> bool:
	return _sites.has(province_id)


func get_layout_points() -> Array:
	return _layout.get("points", []).duplicate(true)


func get_visible_ids() -> Array[String]:
	var result: Array[String] = []
	for province_id: String in _ids:
		if _live.has(province_id):
			result.append(province_id)
	return result


func get_live_summary(province_id: String) -> Dictionary:
	return _live.get(province_id, {}).duplicate(true)


func get_layout_status() -> Dictionary:
	return {
		"ready": _layout_ok, "registered_ids": _ids.size(),
		"live_ids": _live.size(), "territory_polygons": _terrain_polygons.size(),
		"unmapped_live_ids": _unknown_live_ids.duplicate(),
		"terrain_sha256": str(_layout.get("terrain_sha256", "")),
	}


func _fit_scale() -> float:
	return maxf(0.0001, minf(size.x / _image_size.x, size.y / _image_size.y))


func _get_displayed_map_rect() -> Rect2:
	var displayed_size: Vector2 = _image_size * _fit_scale() * map_zoom
	return Rect2((size - displayed_size) * 0.5 + map_pan_offset, displayed_size)


func map_to_local(native_point: Vector2) -> Vector2:
	var image_rect: Rect2 = _get_displayed_map_rect()
	return image_rect.position + native_point / _image_size * image_rect.size


func local_to_map(local_point: Vector2) -> Vector2:
	var image_rect: Rect2 = _get_displayed_map_rect()
	return (local_point - image_rect.position) / image_rect.size * _image_size


func anchor(province_id: String) -> Vector2:
	if not has_site_id(province_id):
		return Vector2.ZERO
	var xy: Array = _sites[province_id]["render_xy"]
	return map_to_local(Vector2(float(xy[0]), float(xy[1])))


func _set_map_zoom(requested_zoom: float, focus_local: Vector2) -> void:
	var focal_point: Vector2 = local_to_map(focus_local)
	map_zoom = clampf(requested_zoom, MIN_ZOOM, MAX_ZOOM)
	map_pan_offset += focus_local - map_to_local(focal_point)
	_layout_city_buttons()


func focus_on_province(province_id: String, requested_zoom: float = 4.2) -> void:
	if not has_site_id(province_id):
		return
	map_zoom = clampf(requested_zoom, MIN_ZOOM, MAX_ZOOM)
	map_pan_offset = Vector2.ZERO
	map_pan_offset = size * 0.5 - anchor(province_id)
	_layout_city_buttons()


func focus_region() -> void:
	focus_on_province("dalgubeol", 4.2)


func fit_all() -> void:
	map_zoom = 1.0
	map_pan_offset = Vector2.ZERO
	_layout_city_buttons()


func _layout_city_buttons() -> void:
	# Name retained for older host callers; there are no overlapping Button nodes.
	map_zoom = clampf(map_zoom, MIN_ZOOM, MAX_ZOOM)
	var surplus: Vector2 = (_image_size * _fit_scale() * map_zoom - size) * 0.5
	map_pan_offset.x = clampf(map_pan_offset.x, -maxf(0.0, surplus.x), maxf(0.0, surplus.x))
	map_pan_offset.y = clampf(map_pan_offset.y, -maxf(0.0, surplus.y), maxf(0.0, surplus.y))
	queue_redraw()


func get_view_state() -> Dictionary:
	var center_native: Vector2 = local_to_map(size * 0.5)
	return {"selected": selected, "zoom": map_zoom, "center_native": [center_native.x, center_native.y]}


func restore_view_state(view_state: Dictionary) -> void:
	var center_value: Variant = view_state.get("center_native", null)
	if not (center_value is Array) or center_value.size() != 2:
		return
	var native_point := Vector2(float(center_value[0]), float(center_value[1]))
	if not native_point.is_finite():
		return
	map_zoom = clampf(float(view_state.get("zoom", 1.0)), MIN_ZOOM, MAX_ZOOM)
	map_pan_offset = Vector2.ZERO
	map_pan_offset = size * 0.5 - map_to_local(native_point)
	var restored_selection: String = str(view_state.get("selected", selected))
	if has_site_id(restored_selection):
		selected = restored_selection
	_layout_city_buttons()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		var current_fit: float = _fit_scale()
		if _last_fit_scale > 0.0:
			map_pan_offset *= current_fit / _last_fit_scale
		_last_fit_scale = current_fit
		_layout_city_buttons()
	elif what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_held = false


func _sprite_width(province_id: String) -> float:
	return float(_sites[province_id]["sprite_width_native"]) * _fit_scale() * map_zoom


func pick_id_at(local_point: Vector2, minimum_radius: float = 16.0) -> String:
	var best_id: String = ""
	var best_distance: float = INF
	var viewport_rect := Rect2(Vector2.ZERO, size)
	if not viewport_rect.has_point(local_point):
		return best_id
	for province_id: String in _ids:
		if not _live.has(province_id):
			continue
		var center: Vector2 = anchor(province_id)
		if not viewport_rect.has_point(center):
			continue
		var width_value: float = _sprite_width(province_id)
		var detail: bool = not bool(_sites[province_id]["marker_only"]) and width_value >= DETAIL_THRESHOLD
		var radius: float = maxf(minimum_radius, width_value * 0.55 if detail else 0.0)
		var distance: float = center.distance_to(local_point)
		if distance <= radius and distance < best_distance:
			best_id = province_id
			best_distance = distance
	return best_id


func _gui_input(event: InputEvent) -> void:
	if input_locked:
		_held = false
		return
	if not _layout_ok:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var multiplier: float = MAP_ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / MAP_ZOOM_STEP
			_set_map_zoom(map_zoom * multiplier, event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_held = true
				_dragged = false
				_press_position = event.position
				_press_pan = map_pan_offset
			else:
				if _held and not _dragged:
					var province_id: String = pick_id_at(event.position)
					if not province_id.is_empty():
						selected = province_id
						settlement_selected.emit(province_id)
				_held = false
			accept_event()
	elif event is InputEventMouseMotion and _held:
		var drag_delta: Vector2 = event.position - _press_position
		_dragged = _dragged or drag_delta.length() > 4.0
		if _dragged:
			map_pan_offset = _press_pan + drag_delta
			_layout_city_buttons()
		accept_event()


func set_route_ids(province_ids: Array[String]) -> bool:
	_route_ids.clear()
	for province_id: String in province_ids:
		if not has_site_id(province_id) or not _live.has(province_id):
			preview_source = ""
			queue_redraw()
			return false
	_route_ids = province_ids.duplicate()
	queue_redraw()
	return true


func clear_route() -> void:
	_route_ids.clear()
	preview_source = ""
	queue_redraw()


func set_territory_geometry(polygons: Dictionary, terrain_sha256: String) -> bool:
	# Only explicitly supplied native-image geometry is accepted. The old world
	# mask and the review's water-color heuristic are never loaded here.
	if terrain_sha256 != str(_layout.get("terrain_sha256", "")):
		return false
	var accepted: Dictionary = {}
	for raw_id: Variant in polygons:
		var province_id: String = str(raw_id)
		if not has_site_id(province_id) or not (polygons[raw_id] is PackedVector2Array):
			return false
		var polygon: PackedVector2Array = polygons[raw_id]
		if polygon.size() < 3:
			return false
		for vertex: Vector2 in polygon:
			if not vertex.is_finite() or not Rect2(Vector2.ZERO, _image_size).has_point(vertex):
				return false
		var xy: Array = _sites[province_id]["render_xy"]
		if not Geometry2D.is_point_in_polygon(Vector2(float(xy[0]), float(xy[1])), polygon):
			return false
		if Geometry2D.triangulate_polygon(polygon).is_empty():
			return false
		accepted[province_id] = polygon.duplicate()
	_terrain_polygons = accepted
	queue_redraw()
	return true


func _faction_color(province_id: String) -> Color:
	return faction_colors.get(str(_live[province_id]["faction"]), Color("bdb49c"))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("073047"))
	if not _layout_ok:
		return
	draw_texture_rect(_terrain, _get_displayed_map_rect(), false)
	var weight: float = detail_weight()
	if corrected_comparison:
		if r3_comparison:
			_r3_fill.draw_on(self, _get_displayed_map_rect())
		_corrected_detail.draw_on(self, _get_displayed_map_rect())
	elif weight>0.0:
		var world := _get_displayed_map_rect()
		draw_texture_rect(_detail_texture,Rect2(world.position+_detail_rect.position/_image_size*world.size,_detail_rect.size/_image_size*world.size),false,Color(1,1,1,weight))
	_draw_territories()
	_draw_support_route()
	var rendered: Array[Dictionary] = []
	var area := Rect2(Vector2.ZERO, size)
	for province_id: String in _ids:
		if not _live.has(province_id):
			continue
		var position_value: Vector2 = anchor(province_id)
		var width_value: float = _sprite_width(province_id)
		var is_detail: bool = not bool(_sites[province_id]["marker_only"]) and width_value >= DETAIL_THRESHOLD
		var body := Rect2(position_value - Vector2.ONE * 7.0, Vector2.ONE * 14.0)
		if is_detail:
			body = Rect2(position_value - SPRITE_PIVOT * width_value, Vector2.ONE * width_value)
		if not area.intersects(body):
			continue
		_draw_site(province_id, position_value, width_value, is_detail)
		rendered.append({"id": province_id, "position": position_value, "width": width_value, "detail": is_detail, "body": body})
	_draw_labels(rendered)


func _draw_site(province_id: String, center: Vector2, width_value: float, detail: bool) -> void:
	var color_value: Color = _faction_color(province_id)
	if detail:
		draw_texture_rect(_fortress, Rect2(center - SPRITE_PIVOT * width_value, Vector2.ONE * width_value), false)
		var flag_top: Vector2 = center + Vector2(0.3, -0.7) * width_value
		draw_line(flag_top, flag_top + Vector2(0, width_value * 0.3), Color("152020"), 1.5)
		draw_rect(Rect2(flag_top, Vector2(maxf(5, width_value * 0.19), maxf(3, width_value * 0.11))), color_value)
	elif bool(_sites[province_id]["marker_only"]):
		var diamond := PackedVector2Array([center + Vector2(0, -4), center + Vector2(4, 0), center + Vector2(0, 4), center + Vector2(-4, 0)])
		draw_colored_polygon(diamond, Color("172529"))
		diamond.append(diamond[0])
		draw_polyline(diamond, color_value, 1.5, true)
	else:
		draw_circle(center, 4.2, color_value)
		draw_arc(center, 4.2, 0, TAU, 24, Color("101c22"), 1.5, true)
		if str(_sites[province_id]["tier"]) == "capital":
			draw_arc(center, 7, 0, TAU, 24, color_value, 1.2, true)
	if province_id == selected:
		var outline := PackedVector2Array()
		var radius_x: float = maxf(9, width_value * 0.53 if detail else 9.0)
		var radius_y: float = maxf(6, width_value * 0.23 if detail else 6.0)
		for step: int in range(49):
			var angle: float = TAU * float(step) / 48.0
			outline.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))
		draw_polyline(outline, Color("fff4df"), 4.0, true)
		draw_polyline(outline, Color("e87523"), 2.2, true)


func _priority(province_id: String) -> int:
	if province_id == selected:
		return 100
	match str(_sites[province_id]["tier"]):
		"capital": return 40
		"major": return 20
		"standard": return 10
	return 0


func _draw_labels(rendered: Array[Dictionary]) -> void:
	var label_font: Font = map_label_font if map_label_font != null else get_theme_default_font()
	if label_font == null:
		return
	var ordered: Array[Dictionary] = rendered.duplicate()
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return _priority(str(left["id"])) > _priority(str(right["id"])))
	var occupied: Array[Rect2] = []
	var available := Rect2(Vector2.ONE * 3, size - Vector2.ONE * 6)
	for item: Dictionary in ordered:
		var province_id: String = str(item["id"])
		var caption: String = str(_live[province_id]["name"])
		var center: Vector2 = item["position"]
		var width_value: float = float(item["width"])
		var detail: bool = bool(item["detail"])
		var text_size: Vector2 = label_font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, map_label_size) + Vector2(12, 6)
		var below: float = width_value * 0.35 + 3 if detail else 10.0
		var side: float = maxf(width_value * 0.55, 10)
		var positions: Array[Vector2] = [center + Vector2(-text_size.x * 0.5, below), center + Vector2(side, -text_size.y * 0.5), center + Vector2(-text_size.x - side, -text_size.y * 0.5), center + Vector2(-text_size.x * 0.5, -(width_value * 0.72 if detail else 12.0) - text_size.y)]
		for candidate: Vector2 in positions:
			var bounds := Rect2(candidate, text_size)
			if not available.encloses(bounds):
				continue
			var blocked: bool = false
			for previous: Rect2 in occupied:
				if bounds.grow(3).intersects(previous):
					blocked = true
					break
			for other: Dictionary in rendered:
				if str(other["id"]) != province_id and bounds.grow(2).intersects(other["body"]):
					blocked = true
					break
			if blocked:
				continue
			occupied.append(bounds)
			var is_selected: bool = province_id == selected
			draw_rect(bounds, Color(0.18, 0.15, 0.075, 0.9) if is_selected else Color(0.05, 0.1, 0.11, 0.81))
			var baseline: Vector2 = candidate + Vector2(6, 3 + label_font.get_ascent(map_label_size))
			draw_string(label_font, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, map_label_size, Color("ffe3a0") if is_selected else Color("f5ecd7"))
			break


func _draw_support_route() -> void:
	var route: Array[String] = _route_ids.duplicate()
	if route.is_empty() and not preview_source.is_empty():
		route.assign([preview_source, selected])
	if route.size() < 2:
		return
	for province_id: String in route:
		if not has_site_id(province_id) or not _live.has(province_id):
			return
	for index: int in range(route.size() - 1):
		draw_line(anchor(route[index]), anchor(route[index + 1]), Color("fff4df"), 5.8, true)
		draw_line(anchor(route[index]), anchor(route[index + 1]), Color("e87523"), 3.4, true)


func _draw_territories() -> void:
	for raw_id: Variant in _terrain_polygons:
		var province_id: String = str(raw_id)
		if not _live.has(province_id):
			continue
		var transformed := PackedVector2Array()
		for native_point: Vector2 in _terrain_polygons[raw_id]:
			transformed.append(map_to_local(native_point))
		var color_value: Color = _faction_color(province_id)
		color_value.a = 0.12
		draw_colored_polygon(transformed, color_value)
		transformed.append(transformed[0])
		color_value.a = 0.5
		draw_polyline(transformed, color_value, 1.0, true)
