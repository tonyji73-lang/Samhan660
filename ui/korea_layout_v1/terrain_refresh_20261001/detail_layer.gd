extends Control
## Display-only detail; original geography, city layout and gameplay are untouched.
const DIR = "res://ui/korea_layout_v1/terrain_refresh_20261001/"
var suppressed: bool = false
var fine_enabled: bool = true
var weight: float = 0.0
var tiles: Array[TextureRect] = []
var regions: Array[Rect2] = []

func configure(original: Texture2D) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_pixels := original.get_image()
	if base_pixels.is_compressed(): base_pixels.decompress()
	base_pixels.generate_mipmaps()
	var base_texture := ImageTexture.create_from_image(base_pixels)
	for row: Array in [["northwest",0,0],["northeast",604,0],["southwest",0,604],["southeast",604,604]]:
		var view := TextureRect.new()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var texture: Texture2D = load(DIR + str(row[0]) + ".png")
		var pixels := texture.get_image()
		if pixels.is_compressed(): pixels.decompress()
		pixels.generate_mipmaps()
		view.texture = ImageTexture.create_from_image(pixels)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://ui/korea_layout_v1/terrain_refresh_20261001/detail.gdshader")
		mat.set_shader_parameter("original_map", base_texture)
		mat.set_shader_parameter("source_rect", Vector4(row[1],row[2],650,650))
		view.material = mat
		add_child(view)
		tiles.append(view)
		regions.append(Rect2(row[1],row[2],650,650))
	# Smaller native regions provide 3.58 texels/native pixel at close play zoom.
	# These are texture-detail inputs, never replacement coastlines or terrain masks.
	for row: Array in [["northwest",0,0],["north",300,0],["northeast",600,0],["west",300,300],["east",600,300],["southwest",300,600],["southeast",600,600],["south",300,900],["south_coast",600,900]]:
		var view := TextureRect.new()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var texture: Texture2D = load("res://ui/korea_layout_v1/play_detail_20261002/" + str(row[0]) + ".png")
		var pixels := texture.get_image()
		if pixels.is_compressed(): pixels.decompress()
		pixels.generate_mipmaps()
		view.texture = ImageTexture.create_from_image(pixels)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://ui/korea_layout_v1/terrain_refresh_20261001/detail.gdshader")
		mat.set_shader_parameter("original_map", base_texture)
		mat.set_shader_parameter("source_rect", Vector4(row[1],row[2],350,350))
		mat.set_shader_parameter("detail_radius", 5.0)
		mat.set_shader_parameter("fine_art", true)
		view.material = mat
		add_child(view)
		tiles.append(view)
		regions.append(Rect2(row[1],row[2],350,350))

func sync(world: Rect2, density: float, allowed: bool) -> void:
	weight = smoothstep(1.25,2.1,density) if allowed and not suppressed else 0.0
	for i in range(tiles.size()):
		var view := tiles[i]
		var tile_weight := weight
		if i >= 4:
			tile_weight *= smoothstep(2.0,3.0,density) if fine_enabled else 0.0
		view.position = world.position + regions[i].position * world.size / 1254.0
		view.size = regions[i].size * world.size / 1254.0
		view.visible = tile_weight > 0.0 and Rect2(Vector2.ZERO,size).intersects(Rect2(view.position,view.size))
		view.material.set_shader_parameter("detail_weight",tile_weight)
