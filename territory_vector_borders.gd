extends Node

# Samhan660 experimental B-mode territory border renderer.
# - Existing territory mask still provides region fill.
# - Existing baked G-channel border is ignored.
# - Borders are regenerated as contours from alpha(region ID) transitions
#   and drawn as constant-width, anti-aliased Line2D nodes.

const TARGET_OVERLAY_NAME: String = "LandTerritoryOverlay"
const VECTOR_LAYER_NAME: String = "TerritoryVectorBorders"
const SAMPLE_WIDTH: int = 1536
const RDP_EPSILON_SOURCE_PIXELS: float = 2.5
const CHAIKIN_ITERATIONS: int = 1
const CHAIKIN_RATIO: float = 0.20
const CACHE_FORMAT_VERSION: int = 1
const CACHE_ALGORITHM_VERSION: String = "b3-marching-rdp-chaikin-1"
const CONTOUR_CACHE_PATH: String = "user://territory_b3_contours.cache"

const BORDER_WIDTH: float = 1.6
const BORDER_COLOR: Color = Color(0.93, 0.88, 0.74, 0.50)
const BORDER_Z_INDEX: int = -7

const FILL_ONLY_SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

uniform sampler2D territory_palette : source_color, filter_nearest, repeat_disable;

void fragment() {
	ivec2 mask_size = textureSize(TEXTURE, 0);
	ivec2 mask_pixel = ivec2(
		clamp(UV, vec2(0.0), vec2(0.999999)) * vec2(mask_size)
	);

	vec4 territory_data = texelFetch(TEXTURE, mask_pixel, 0);

	if (territory_data.a < 0.001) {
		COLOR = vec4(0.0);
	} else {
		float region_index = floor(territory_data.a * 255.0 + 0.5);
		float palette_u = (region_index + 0.5) / 64.0;
		COLOR = texture(
			territory_palette,
			vec2(palette_u, 0.25)
		);
	}
}
"""


class TerritoryVectorLayer:
	extends Control

	var source_overlay: TextureRect
	var contours_uv: Array[PackedVector2Array] = []
	var contour_lines: Array[Line2D] = []
	var last_size: Vector2 = Vector2(-1.0, -1.0)

	func setup(
		overlay: TextureRect,
		new_contours_uv: Array[PackedVector2Array]
	) -> void:
		source_overlay = overlay
		contours_uv = new_contours_uv

		name = VECTOR_LAYER_NAME
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		z_index = BORDER_Z_INDEX
		set_anchors_preset(Control.PRESET_TOP_LEFT)

		_sync_to_overlay(true)

	func _process(_delta: float) -> void:
		if not is_instance_valid(source_overlay):
			queue_free()
			return

		_sync_to_overlay(false)

	func _sync_to_overlay(force_rebuild: bool) -> void:
		if source_overlay == null:
			return

		position = source_overlay.position

		if force_rebuild or size != source_overlay.size:
			size = source_overlay.size
			_rebuild_lines()

	func _rebuild_lines() -> void:
		if size == last_size and not contour_lines.is_empty():
			return

		last_size = size

		if contour_lines.size() != contours_uv.size():
			for old_line: Line2D in contour_lines:
				old_line.queue_free()
			contour_lines.clear()

			for contour_uv: PackedVector2Array in contours_uv:
				var line: Line2D = Line2D.new()
				line.width = BORDER_WIDTH
				line.default_color = BORDER_COLOR
				line.antialiased = true
				line.joint_mode = Line2D.LINE_JOINT_ROUND
				line.begin_cap_mode = Line2D.LINE_CAP_ROUND
				line.end_cap_mode = Line2D.LINE_CAP_ROUND
				line.closed = (
					contour_uv.size() > 2
					and contour_uv[0].is_equal_approx(contour_uv[-1])
				)
				add_child(line)
				contour_lines.append(line)

		for contour_index: int in range(contours_uv.size()):
			var contour_uv: PackedVector2Array = contours_uv[contour_index]
			var point_count: int = contour_uv.size()
			if contour_lines[contour_index].closed:
				point_count -= 1

			var points_px: PackedVector2Array = PackedVector2Array()
			points_px.resize(point_count)
			for point_index: int in range(point_count):
				var uv: Vector2 = contour_uv[point_index]
				points_px[point_index] = Vector2(
					uv.x * size.x,
					uv.y * size.y
				)
			contour_lines[contour_index].points = points_px


var current_overlay: TextureRect = null
var vector_layer: TerritoryVectorLayer = null

var cached_texture_rid: RID = RID()
var cached_mask_signature: String = ""
var cached_contours_uv: Array[PackedVector2Array] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if is_instance_valid(current_overlay):
		return

	current_overlay = null
	vector_layer = null

	var scene: Node = get_tree().current_scene
	if scene == null:
		return

	var candidate: Node = scene.find_child(
		TARGET_OVERLAY_NAME,
		true,
		false
	)

	if candidate is TextureRect:
		_attach_to_overlay(candidate as TextureRect)


func _attach_to_overlay(overlay: TextureRect) -> void:
	if overlay.texture == null:
		return

	current_overlay = overlay

	_switch_overlay_to_fill_only(overlay)

	var texture_rid: RID = overlay.texture.get_rid()

	if cached_contours_uv.is_empty() or texture_rid != cached_texture_rid:
		cached_texture_rid = texture_rid
		cached_mask_signature = _get_mask_signature(overlay.texture)
		cached_contours_uv = _load_contour_cache(cached_mask_signature)
		if cached_contours_uv.is_empty():
			cached_contours_uv = _build_contours(overlay.texture)
			if not cached_contours_uv.is_empty():
				_save_contour_cache(cached_mask_signature, cached_contours_uv)

	var parent_node: Node = overlay.get_parent()
	if parent_node == null:
		return

	var old_layer: Node = parent_node.get_node_or_null(
		VECTOR_LAYER_NAME
	)

	if old_layer != null:
		old_layer.queue_free()

	vector_layer = TerritoryVectorLayer.new()
	parent_node.add_child(vector_layer)

	vector_layer.setup(
		overlay,
		cached_contours_uv
	)


func _switch_overlay_to_fill_only(
	overlay: TextureRect
) -> void:
	if not overlay.material is ShaderMaterial:
		return

	var material: ShaderMaterial = (
		overlay.material as ShaderMaterial
	)

	var old_palette: Variant = (
		material.get_shader_parameter(
			"territory_palette"
		)
	)

	var fill_shader: Shader = Shader.new()
	fill_shader.code = FILL_ONLY_SHADER_CODE
	material.shader = fill_shader

	if old_palette != null:
		material.set_shader_parameter(
			"territory_palette",
			old_palette
		)


func _get_mask_signature(texture: Texture2D) -> String:
	var mask_hash: String = ""
	var resource_path: String = texture.resource_path
	if resource_path != "" and FileAccess.file_exists(resource_path):
		mask_hash = _sha256(FileAccess.get_file_as_bytes(resource_path))

	if mask_hash == "":
		var image: Image = texture.get_image()
		if image != null and not image.is_empty():
			mask_hash = _sha256(image.get_data())

	return "%s|%s|%d|%.3f|%d|%.3f" % [
		CACHE_ALGORITHM_VERSION,
		mask_hash,
		SAMPLE_WIDTH,
		RDP_EPSILON_SOURCE_PIXELS,
		CHAIKIN_ITERATIONS,
		CHAIKIN_RATIO,
	]


func _sha256(bytes: PackedByteArray) -> String:
	var hashing: HashingContext = HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing.update(bytes) != OK:
		return ""
	return hashing.finish().hex_encode()


func _load_contour_cache(signature: String) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if signature == "" or not FileAccess.file_exists(CONTOUR_CACHE_PATH):
		return result

	var cache_file: FileAccess = FileAccess.open(CONTOUR_CACHE_PATH, FileAccess.READ)
	if cache_file == null:
		return result

	var cache_value: Variant = cache_file.get_var(false)
	if typeof(cache_value) != TYPE_DICTIONARY:
		return result

	var cache: Dictionary = cache_value
	if int(cache.get("format_version", 0)) != CACHE_FORMAT_VERSION:
		return result
	if str(cache.get("signature", "")) != signature:
		return result

	var contours_value: Variant = cache.get("contours", [])
	if typeof(contours_value) != TYPE_ARRAY:
		return result

	for contour_value: Variant in contours_value:
		if contour_value is PackedVector2Array and contour_value.size() >= 2:
			result.append(contour_value)
	return result


func _save_contour_cache(
	signature: String,
	contours: Array[PackedVector2Array]
) -> void:
	if signature == "" or contours.is_empty():
		return

	var cache_file: FileAccess = FileAccess.open(CONTOUR_CACHE_PATH, FileAccess.WRITE)
	if cache_file == null:
		push_warning("영토 contour 캐시 파일을 만들 수 없습니다: %s" % CONTOUR_CACHE_PATH)
		return

	cache_file.store_var({
		"format_version": CACHE_FORMAT_VERSION,
		"signature": signature,
		"contours": contours,
	}, false)


func _build_contours(
	texture: Texture2D
) -> Array[PackedVector2Array]:
	var source_image: Image = texture.get_image()

	if source_image == null or source_image.is_empty():
		push_warning(
			"영토 마스크 이미지를 읽을 수 없어 벡터 경계를 만들지 못했습니다."
		)
		return []

	var sample_image: Image = source_image.duplicate()

	var source_width: int = sample_image.get_width()
	var source_height: int = sample_image.get_height()

	if source_width <= 0 or source_height <= 0:
		return []

	var sample_width: int = mini(
		SAMPLE_WIDTH,
		source_width
	)

	var sample_height: int = maxi(
		1,
		int(
			round(
				float(source_height)
				* float(sample_width)
				/ float(source_width)
			)
		)
	)

	if (
		sample_width != source_width
		or sample_height != source_height
	):
		sample_image.resize(
			sample_width,
			sample_height,
			Image.INTERPOLATE_NEAREST
		)

	var region_rows: Array[PackedByteArray] = []
	for y: int in range(sample_height):
		var row: PackedByteArray = PackedByteArray()
		row.resize(sample_width)
		for x: int in range(sample_width):
			row[x] = _region_id(sample_image.get_pixel(x, y).a)
		region_rows.append(row)

	# Marching Squares is evaluated for every label present in a cell. The
	# resulting segment key is direction-independent, so a boundary emitted by
	# both neighbouring regions is retained only once.
	var unique_segments: Dictionary = {}
	for y: int in range(-1, sample_height):
		for x: int in range(-1, sample_width):
			var top_left: int = _sample_region(region_rows, x, y)
			var top_right: int = _sample_region(region_rows, x + 1, y)
			var bottom_right: int = _sample_region(region_rows, x + 1, y + 1)
			var bottom_left: int = _sample_region(region_rows, x, y + 1)
			var cell_regions: Array[int] = []
			for region_id: int in [top_left, top_right, bottom_right, bottom_left]:
				if region_id > 0 and not cell_regions.has(region_id):
					cell_regions.append(region_id)

			for region_id: int in cell_regions:
				var case_index: int = 0
				if top_left == region_id:
					case_index |= 1
				if top_right == region_id:
					case_index |= 2
				if bottom_right == region_id:
					case_index |= 4
				if bottom_left == region_id:
					case_index |= 8
				_append_marching_case(unique_segments, case_index, x, y)

	var edges: Array = []
	var adjacency: Dictionary = {}
	for segment_value: Variant in unique_segments.values():
		var segment: Array = segment_value
		_append_edge(edges, adjacency, segment[0], segment[1])

	var sample_contours: Array[PackedVector2Array] = (
		_join_edges_into_contours(edges, adjacency)
	)
	var epsilon: float = (
		RDP_EPSILON_SOURCE_PIXELS
		* float(sample_width)
		/ float(source_width)
	)
	var result: Array[PackedVector2Array] = []
	for contour: PackedVector2Array in sample_contours:
		var closed: bool = _is_closed(contour)
		var simplified: PackedVector2Array = _rdp_contour(contour, epsilon, closed)
		var smoothed: PackedVector2Array = simplified
		for _iteration: int in range(CHAIKIN_ITERATIONS):
			smoothed = _chaikin(smoothed, closed)
		result.append(_to_uv(smoothed, sample_width, sample_height))

	return result


func _region_id(
	alpha_value: float
) -> int:
	return clampi(
		int(round(alpha_value * 255.0)),
		0,
		255
	)


func _sample_region(rows: Array[PackedByteArray], x: int, y: int) -> int:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].size():
		return 0
	return int(rows[y][x])


func _append_marching_case(
	segments: Dictionary,
	case_index: int,
	x: int,
	y: int
) -> void:
	if case_index == 0 or case_index == 15:
		return

	# Coordinates are stored at twice the sample resolution. Odd coordinates
	# are the half-pixel intersections between neighbouring pixel centres.
	var top: Vector2i = Vector2i(x * 2 + 1, y * 2)
	var right: Vector2i = Vector2i(x * 2 + 2, y * 2 + 1)
	var bottom: Vector2i = Vector2i(x * 2 + 1, y * 2 + 2)
	var left: Vector2i = Vector2i(x * 2, y * 2 + 1)

	match case_index:
		1, 14:
			_store_unique_segment(segments, left, top)
		2, 13:
			_store_unique_segment(segments, top, right)
		3, 12:
			_store_unique_segment(segments, left, right)
		4, 11:
			_store_unique_segment(segments, right, bottom)
		6, 9:
			_store_unique_segment(segments, top, bottom)
		7, 8:
			_store_unique_segment(segments, left, bottom)
		5:
			_store_unique_segment(segments, left, top)
			_store_unique_segment(segments, right, bottom)
		10:
			_store_unique_segment(segments, top, right)
			_store_unique_segment(segments, bottom, left)


func _store_unique_segment(
	segments: Dictionary,
	start: Vector2i,
	end: Vector2i
) -> void:
	var first: Vector2i = start
	var second: Vector2i = end
	if first.x > second.x or (first.x == second.x and first.y > second.y):
		first = end
		second = start
	segments[Vector4i(first.x, first.y, second.x, second.y)] = [first, second]


func _append_edge(
	edges: Array,
	adjacency: Dictionary,
	start: Vector2i,
	end: Vector2i
) -> void:
	var edge_index: int = edges.size()
	edges.append([start, end])

	for vertex: Vector2i in [start, end]:
		if not adjacency.has(vertex):
			adjacency[vertex] = []
		adjacency[vertex].append(edge_index)


func _join_edges_into_contours(
	edges: Array,
	adjacency: Dictionary
) -> Array[PackedVector2Array]:
	var contours: Array[PackedVector2Array] = []
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(edges.size())

	# Start open contours at endpoints and junctions. Stopping again at a
	# junction prevents unrelated borders from being connected across it.
	for edge_index: int in range(edges.size()):
		var edge: Array = edges[edge_index]
		var start: Vector2i = edge[0]
		var end: Vector2i = edge[1]
		if adjacency[start].size() == 2 and adjacency[end].size() == 2:
			continue
		var start_vertex: Vector2i = (
			start if adjacency[start].size() != 2 else end
		)
		var points: PackedVector2Array = _trace_contour(
			edge_index, start_vertex, edges, adjacency, visited
		)
		if points.size() >= 2:
			contours.append(points)

	# The remaining edges are closed loops whose vertices all have degree 2.
	for edge_index: int in range(edges.size()):
		if visited[edge_index] != 0:
			continue
		var points: PackedVector2Array = _trace_contour(
			edge_index, edges[edge_index][0], edges, adjacency, visited
		)
		if points.size() >= 2:
			contours.append(points)

	return contours


func _trace_contour(
	start_edge_index: int,
	start_vertex: Vector2i,
	edges: Array,
	adjacency: Dictionary,
	visited: PackedByteArray
) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array([Vector2(start_vertex) * 0.5])
	var current_vertex: Vector2i = start_vertex
	var edge_index: int = start_edge_index

	while edge_index >= 0 and visited[edge_index] == 0:
		visited[edge_index] = 1
		var edge: Array = edges[edge_index]
		current_vertex = edge[1] if edge[0] == current_vertex else edge[0]
		points.append(Vector2(current_vertex) * 0.5)

		if current_vertex != start_vertex and adjacency[current_vertex].size() != 2:
			break

		edge_index = -1
		for candidate_value: Variant in adjacency[current_vertex]:
			var candidate: int = int(candidate_value)
			if visited[candidate] == 0:
				edge_index = candidate
				break

	return points


func _is_closed(points: PackedVector2Array) -> bool:
	return points.size() > 2 and points[0].is_equal_approx(points[-1])


func _rdp_contour(
	points: PackedVector2Array,
	epsilon: float,
	closed: bool
) -> PackedVector2Array:
	if points.size() < 4:
		return points
	if not closed:
		return _rdp_open(points, epsilon)

	var ring: PackedVector2Array = points.duplicate()
	ring.resize(ring.size() - 1)
	if ring.size() < 4:
		return points

	# Split a ring at two well-separated vertices, simplify both arcs, then
	# close it explicitly. This avoids the identical-endpoint RDP degeneracy.
	var split_index: int = 1
	var greatest_distance: float = -1.0
	for index: int in range(1, ring.size()):
		var distance: float = ring[0].distance_squared_to(ring[index])
		if distance > greatest_distance:
			greatest_distance = distance
			split_index = index

	var first_arc: PackedVector2Array = ring.slice(0, split_index + 1)
	var second_arc: PackedVector2Array = PackedVector2Array()
	for index: int in range(split_index, ring.size()):
		second_arc.append(ring[index])
	second_arc.append(ring[0])

	var first_simple: PackedVector2Array = _rdp_open(first_arc, epsilon)
	var second_simple: PackedVector2Array = _rdp_open(second_arc, epsilon)
	var result: PackedVector2Array = first_simple.duplicate()
	for index: int in range(1, second_simple.size()):
		result.append(second_simple[index])

	# Never collapse a small island below a drawable closed polygon.
	if result.size() < 4:
		return points
	result[-1] = result[0]
	return result


func _rdp_open(points: PackedVector2Array, epsilon: float) -> PackedVector2Array:
	if points.size() <= 2:
		return points

	var first: Vector2 = points[0]
	var last: Vector2 = points[-1]
	var furthest_index: int = -1
	var furthest_distance: float = 0.0
	for index: int in range(1, points.size() - 1):
		var distance: float = _point_segment_distance(points[index], first, last)
		if distance > furthest_distance:
			furthest_distance = distance
			furthest_index = index

	if furthest_index < 0 or furthest_distance <= epsilon:
		return PackedVector2Array([first, last])

	var left: PackedVector2Array = _rdp_open(
		points.slice(0, furthest_index + 1), epsilon
	)
	var right: PackedVector2Array = _rdp_open(
		points.slice(furthest_index, points.size()), epsilon
	)
	left.resize(left.size() - 1)
	left.append_array(right)
	return left


func _point_segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment: Vector2 = end - start
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.000001:
		return point.distance_to(start)
	var ratio: float = clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * ratio)


func _chaikin(points: PackedVector2Array, closed: bool) -> PackedVector2Array:
	if points.size() < 3:
		return points

	var source: PackedVector2Array = points.duplicate()
	if closed:
		source.resize(source.size() - 1)
		if source.size() < 3:
			return points

	var result: PackedVector2Array = PackedVector2Array()
	if not closed:
		result.append(source[0])

	var segment_count: int = source.size() if closed else source.size() - 1
	for index: int in range(segment_count):
		var start: Vector2 = source[index]
		var end: Vector2 = source[(index + 1) % source.size()]
		result.append(start.lerp(end, CHAIKIN_RATIO))
		result.append(start.lerp(end, 1.0 - CHAIKIN_RATIO))

	if closed:
		result.append(result[0])
	else:
		result.append(source[-1])
	return result


func _to_uv(
	points: PackedVector2Array,
	sample_width: int,
	sample_height: int
) -> PackedVector2Array:
	var contour_uv: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		contour_uv.append(Vector2(
			(point.x + 0.5) / float(sample_width),
			(point.y + 0.5) / float(sample_height)
		))
	return contour_uv
