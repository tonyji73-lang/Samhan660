extends SceneTree
## Reproducible cache-independent resources; original PNG/font bytes stay intact.
func _initialize() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://dev/living_city_ui_v1_3_art_source/asset_manifest.json"))
	var destination := "res://ui/living_city_v1/assets/ornaments/v1_3/generated/"
	DirAccess.make_dir_recursive_absolute(destination)
	for key: String in manifest.assets:
		var item: Dictionary=manifest.assets[key]
		var pixels := Image.load_from_file("res://"+str(item.file))
		assert(pixels.get_size()==Vector2i(item.source_size[0],item.source_size[1]))
		var tex := ImageTexture.create_from_image(pixels)
		assert(ResourceSaver.save(tex,destination+key+".res",ResourceSaver.FLAG_COMPRESS)==OK)
	var font := FontFile.new()
	font.data=FileAccess.get_file_as_bytes("res://ui/living_city_v1/assets/fonts/nanummyeongjo/NanumMyeongjo-ExtraBold.ttf")
	assert(font.has_char(0xAD6D))
	assert(ResourceSaver.save(font,"res://ui/living_city_v1/assets/fonts/nanummyeongjo/title_font.res",ResourceSaver.FLAG_COMPRESS)==OK)
	print("PORTABLE RESOURCES: 6 original-pixel textures and 1 font saved")
	quit()
