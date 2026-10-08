extends Control
## One play-map coordinate space. Detail tiles are loaded only near the camera.
const DIR = "res://ui/korea_layout_v1/unified_world_20261002/"
const BOUNDS := Rect2(-900, -700, 3300, 2200)
var atlas: TextureRect
var korea: TextureRect
var bohai: TextureRect
const BOHAI_RECT := Rect2(-650,-100,1000,1000)
var bohai_details: Array[TextureRect] = []
const BOHAI_DETAILS = [Rect2(300,300,350,350),Rect2(220,520,350,350)]
var tiles: Array[TextureRect] = []
var regions: Array[Rect2] = []
var paths: Array[String] = []
var active_tiles: int = 0

func _view() -> TextureRect:
	var view := TextureRect.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(view)
	return view

func _texture(path: String) -> Texture2D:
	var resource: Texture2D = load(path)
	if resource == null: return null
	var pixels := resource.get_image()
	if pixels.is_compressed(): pixels.decompress()
	if not pixels.has_mipmaps(): pixels.generate_mipmaps()
	return ImageTexture.create_from_image(pixels)

func configure(original: Texture2D) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	atlas = _view()
	atlas.texture = _texture(DIR + "atlas.png")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR + "manifest.json"))
	for tile: Dictionary in manifest.tiles:
		var view := _view()
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://ui/korea_layout_v1/unified_world_20261002/tile.gdshader")
		mat.set_shader_parameter("fade_native", Vector2(tile.fade[0],tile.fade[1]))
		view.material = mat
		tiles.append(view)
		regions.append(Rect2(tile.rect[0],tile.rect[1],tile.rect[2],tile.rect[3]))
		paths.append(DIR + str(tile.path))
	bohai = _view()
	bohai.texture = _texture("res://ui/korea_layout_v1/bohai_20261002/bohai.png")
	var bohai_material := ShaderMaterial.new()
	bohai_material.shader = preload("res://ui/korea_layout_v1/bohai_20261002/join.gdshader")
	bohai_material.set_shader_parameter("southern_join",_texture("res://ui/korea_layout_v1/bohai_20261002/bohai_join.png"))
	bohai.material = bohai_material
	for i in range(BOHAI_DETAILS.size()):
		var detail := TextureRect.new()
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		detail.texture = _texture("res://ui/korea_layout_v1/bohai_20261002/"+["dalian","yantai"][i]+".png")
		var detail_material := ShaderMaterial.new()
		detail_material.shader = preload("res://ui/korea_layout_v1/bohai_20261002/detail.gdshader")
		detail_material.set_shader_parameter("base_map",bohai.texture)
		var r: Rect2 = BOHAI_DETAILS[i]
		detail_material.set_shader_parameter("source_rect",Vector4(r.position.x,r.position.y,r.size.x,r.size.y))
		detail.material = detail_material
		bohai.add_child(detail)
		bohai_details.append(detail)
	korea = _view()
	korea.texture = original
	var mask := ShaderMaterial.new()
	mask.shader = preload("res://ui/korea_layout_v1/unified_world_20261002/korea.gdshader")
	korea.material = mask

func sync(original_rect: Rect2, density: float) -> void:
	if atlas == null: return
	var scale_value := original_rect.size / 1254.0
	atlas.position = original_rect.position + BOUNDS.position * scale_value
	atlas.size = BOUNDS.size * scale_value
	korea.position = original_rect.position
	korea.size = original_rect.size
	bohai.position = original_rect.position + BOHAI_RECT.position * scale_value
	bohai.size = BOHAI_RECT.size * scale_value
	for i in range(bohai_details.size()):
		bohai_details[i].position = BOHAI_DETAILS[i].position * scale_value
		bohai_details[i].size = BOHAI_DETAILS[i].size * scale_value
		bohai_details[i].material.set_shader_parameter("detail_weight",smoothstep(1.0,2.0,density))
	active_tiles = 0
	var weight := smoothstep(0.8, 1.5, density)
	var viewport_rect := Rect2(Vector2.ZERO, size)
	for i in range(tiles.size()):
		var view := tiles[i]
		view.position = original_rect.position + regions[i].position * scale_value
		view.size = regions[i].size * scale_value
		view.visible = weight > 0.0 and viewport_rect.intersects(Rect2(view.position, view.size))
		if view.visible:
			if view.texture == null: view.texture = _texture(paths[i])
			view.material.set_shader_parameter("detail_weight", weight)
			active_tiles += 1
		elif view.texture != null:
			# Avoid retaining the entire detailed world in video memory.
			view.texture = null
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("073047"))
