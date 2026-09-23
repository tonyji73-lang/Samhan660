extends Node2D

# Only presentation transforms/overlays are changed; map source coordinates and
# ownership are read-only. Named cinematic targets are resolved from the catalog.
var campaign: Node
var map: Control
var targets: Dictionary = {}
var saved_zoom: float
var saved_pan: Vector2
var saved_card: String = ""
var running: bool = false
var effects: Array = []
var route: Array[Vector2] = []
var elapsed: float = 0.0
var camera_tween: Tween
var animation_paused: bool = false
var world_regions: Dictionary = {}
var atlas: bool = false
var saved_view: Dictionary = {}


func setup(host: Node, definitions: Dictionary) -> void:
	campaign = host
	map = host.map_area
	if host.get("settlement_overlay") != null:
		map = host.settlement_overlay.map
		atlas = true
	targets = definitions
	z_index = 50


func begin() -> void:
	if running:
		return
	running = true
	world_regions = campaign.WorldMapData.get_scenario_provinces(campaign.year)
	saved_zoom = map.map_zoom
	saved_pan = map.map_pan_offset
	campaign.map_area.cutscene_input_locked = true
	if atlas:
		saved_view = map.get_view_state()
		map.input_locked = true
	else:
		saved_card = map.floating_city_card_province_id
		map.map_dragging = false
		map.hide_city_card()


func finish() -> void:
	clear_step()
	if not running:
		return
	running = false
	map.map_zoom = saved_zoom
	map.map_pan_offset = saved_pan
	if not atlas: map._clamp_map_pan()
	map._layout_city_buttons()
	campaign.map_area.cutscene_input_locked = false
	if atlas: map.input_locked = false
	if not saved_card.is_empty() and campaign.provinces.has(saved_card):
		campaign.select_province(saved_card)


func clear_step() -> void:
	if camera_tween != null:
		camera_tween.kill()
		camera_tween = null
	animation_paused = false
	set_process(true)
	effects.clear()
	route.clear()
	queue_redraw()


func city_ids(target: String) -> Array:
	if has_city(target):
		return [target]
	return targets.get(target, {}).get("cities", []).filter(func(id):return has_city(str(id)))

func has_city(id: String) -> bool:
	return map.has_site_id(id) if atlas else map.WORLD_CITY_MAP_UV.has(id)

func city_uv(id: String) -> Vector2:
	if atlas:
		var xy: Array = map._sites[id].render_xy
		return Vector2(float(xy[0]),float(xy[1])) / map._image_size
	return map.WORLD_CITY_MAP_UV[id]

func point(uv: Vector2, rect: Rect2) -> Vector2:
	return rect.position + uv * rect.size if atlas else map._map_uv_to_position(uv,rect)


func play_step(step: Dictionary) -> void:
	clear_step()
	elapsed = 0.0
	effects = step.get("map_effects", []).duplicate(true)
	var camera: Dictionary = step.get("camera", {})
	var destination: Array = city_ids(str(camera.get("target", camera.get("to", ""))))
	if destination.is_empty():
		return
	var source: Array = city_ids(str(camera.get("from", "")))
	if str(camera.get("action", "")) == "pan_route" and not source.is_empty():
		map.focus_on_province(str(source[0]), 2.15)
		route = [city_uv(str(source[0])), city_uv(str(destination[0]))]
	var start_zoom: float = map.map_zoom
	var start_pan: Vector2 = map.map_pan_offset
	map.focus_on_province(str(destination[0]), 2.5)
	var end_zoom: float = map.map_zoom
	var end_pan: Vector2 = map.map_pan_offset
	map.map_zoom = start_zoom
	map.map_pan_offset = start_pan
	map._layout_city_buttons()
	camera_tween = create_tween()
	camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	camera_tween.tween_method(func(weight: float):
		map.map_zoom = lerpf(start_zoom, end_zoom, weight)
		map.map_pan_offset = start_pan.lerp(end_pan, weight)
		if not atlas: map._clamp_map_pan()
		map._layout_city_buttons()
	, 0.0, 1.0, maxf(0.01, float(camera.get("duration", 2.0))))
	camera_tween.finished.connect(func(): camera_tween = null)


func _process(delta: float) -> void:
	if running:
		elapsed += delta
		queue_redraw()


func set_paused(value: bool) -> void:
	if animation_paused == value:
		return
	animation_paused = value
	set_process(not value)
	if camera_tween != null and camera_tween.is_valid():
		if value:
			camera_tween.pause()
		else:
			camera_tween.play()


func _draw() -> void:
	if not running:
		return
	var rect: Rect2 = map._get_displayed_map_rect()
	if route.size() == 2:
		draw_line(point(route[0], rect), point(route[1], rect), Color("e5c481"), 5.0, true)
	for effect: Dictionary in effects:
		var count: int = maxi(1, int(effect.get("count", 2)))
		if elapsed > float(count):
			continue
		var color := Color(0.95, 0.2, 0.14, 0.35 + 0.65 * absf(sin(elapsed * PI)))
		var action: String = str(effect.get("action", ""))
		var ids: Array = city_ids(str(effect.get("target", "")))
		var faction_id: String = str(effect.get("faction", effect.get("from_faction", "")))
		var faction: String = str(campaign.FACTION_ID_TO_NAME.get(faction_id, faction_id))
		if action in ["pulse_faction", "pulse_border"]:
			# Approved atlas has no registered territory polygons yet. Do not reuse world-mask geometry.
			var borders: Array = [] if atlas else map.border_lines + map.outside_border_lines
			for entry: Array in borders:
				var region: String = str(entry[0])
				var region_owner: String = str(campaign.provinces.get(region, world_regions.get(region, {})).get("faction", ""))
				if region_owner != faction:
					continue
				var points := PackedVector2Array()
				for uv: Vector2 in entry[1]:
					points.append(point(uv, rect))
				if points.size() > 2:
					points.append(points[0])
					draw_polyline(points, color, 5.0, true)
			if action == "pulse_faction" or atlas:
				for city: String in campaign.provinces:
					if campaign.provinces[city].get("faction", "") == faction:
						ids.append(city)
		for id: String in ids:
			if has_city(id):
				var position_on_map: Vector2 = point(city_uv(id), rect)
				draw_arc(position_on_map, 28.0 + 16.0 * fmod(elapsed, 1.0), 0, TAU, 48, color, 6.0, true)
