extends RefCounted
## Draw-only helper. Call draw_on() from the host's _draw(), after terrain,
## before territory overlays, support routes, settlement sprites and labels.
## The caller owns this object for as long as its mesh is being drawn.
## This helper never reads/writes campaign state or save slots.

var last_error: String = ""
var _mesh: ArrayMesh
var _texture: Texture2D
var _base_size := Vector2(1254.0, 1254.0)
var _native_rect := Rect2(512.0, 544.0, 264.0, 176.0)


func configure(mesh_json_path: String, detail_texture_path: String) -> bool:
	_mesh = null
	_texture = null
	last_error = ""
	var file := FileAccess.open(mesh_json_path, FileAccess.READ)
	if file == null:
		return _fail("Cannot open display mesh: " + mesh_json_path)
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return _fail("Display mesh is not a JSON object")
	var config: Dictionary = parsed
	if int(config.get("schema", 0)) != 1:
		return _fail("Unsupported display mesh schema")
	var columns := int(config.get("grid_columns", 0))
	var rows := int(config.get("grid_rows", 0))
	var step := float(config.get("grid_step_native_px", 0.0))
	var samples: Array = config.get("vertices", [])
	var rectangle: Array = config.get("native_rect_xywh", [])
	var base_dimensions: Array = config.get("approved_base_size", [])
	if columns < 2 or rows < 2 or step <= 0.0 or samples.size() != columns * rows:
		return _fail("Invalid display mesh dimensions")
	if rectangle.size() != 4 or base_dimensions.size() != 2:
		return _fail("Missing display mesh placement")
	_base_size = Vector2(float(base_dimensions[0]), float(base_dimensions[1]))
	_native_rect = Rect2(float(rectangle[0]), float(rectangle[1]), float(rectangle[2]), float(rectangle[3]))
	if _base_size.x <= 0.0 or _base_size.y <= 0.0 or _native_rect.size.x <= 0.0 or _native_rect.size.y <= 0.0:
		return _fail("Non-positive display mesh placement")
	if not is_equal_approx(float(columns - 1) * step, _native_rect.size.x) or not is_equal_approx(float(rows - 1) * step, _native_rect.size.y):
		return _fail("Grid does not cover the placement rectangle")
	if not ResourceLoader.exists(detail_texture_path):
		return _fail("Missing detail texture: " + detail_texture_path)
	_texture = load(detail_texture_path) as Texture2D
	if _texture == null or _texture.get_width() != 1536 or _texture.get_height() != 1024:
		return _fail("Expected the unchanged 1536 x 1024 candidate texture")

	var positions := PackedVector2Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for row in range(rows):
		for column in range(columns):
			var index := row * columns + column
			var entry: Variant = samples[index]
			if not entry is Array or entry.size() != 6:
				return _fail("Malformed display mesh vertex")
			for component in entry:
				if not (component is float or component is int) or not is_finite(float(component)):
					return _fail("Non-numeric display mesh component")
			var uv := Vector2(float(entry[0]), float(entry[1]))
			if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
				return _fail("UV outside candidate texture")
			positions.append(Vector2(float(column) * step, float(row) * step))
			uvs.append(uv)
			colors.append(Color(clampf(float(entry[2]), 0.0, 1.0), clampf(float(entry[3]), 0.0, 1.0), clampf(float(entry[4]), 0.0, 1.0), clampf(float(entry[5]), 0.0, 1.0)))
	for row in range(rows - 1):
		for column in range(columns - 1):
			var top_left := row * columns + column
			var top_right := top_left + 1
			var bottom_left := top_left + columns
			var bottom_right := bottom_left + 1
			if (uvs[top_right] - uvs[top_left]).cross(uvs[bottom_left] - uvs[top_left]) <= 0.0:
				return _fail("Folded UV triangle")
			if (uvs[bottom_right] - uvs[top_right]).cross(uvs[bottom_left] - uvs[top_right]) <= 0.0:
				return _fail("Folded UV triangle")
			indices.append_array(PackedInt32Array([top_left, top_right, bottom_left, top_right, bottom_right, bottom_left]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return true


func draw_on(host: CanvasItem, displayed_base_rect: Rect2, opacity: float = 1.0) -> void:
	if _mesh == null or _texture == null or opacity <= 0.0 or displayed_base_rect.size.x <= 0.0 or displayed_base_rect.size.y <= 0.0:
		return
	var native_to_local := displayed_base_rect.size / _base_size
	var origin := displayed_base_rect.position + _native_rect.position * native_to_local
	var transform := Transform2D(Vector2(native_to_local.x, 0.0), Vector2(0.0, native_to_local.y), origin)
	host.draw_mesh(_mesh, _texture, transform, Color(1.0, 1.0, 1.0, clampf(opacity, 0.0, 1.0)))


func is_ready() -> bool:
	return _mesh != null and _texture != null


func _fail(message: String) -> bool:
	last_error = message
	_mesh = null
	_texture = null
	return false
