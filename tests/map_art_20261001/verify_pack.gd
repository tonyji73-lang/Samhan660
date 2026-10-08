extends SceneTree
func _initialize() -> void:
	var failures := 0
	var dir := "res://ui/korea_layout_v1/terrain_refresh_20261001/"
	for name: String in ["northwest","northeast","southwest","southeast","east_asia"]:
		var resource = load(dir+name+".png")
		if not resource is Texture2D:
			failures += 1
			push_error("Missing packed map " + name)
		else: print("PACKED MAP ",name," ",resource.get_size())
	for path: String in ["res://map_area.gd","res://ui/korea_layout_v1/approved_korea_map.gd",dir+"detail_layer.gd",dir+"detail.gdshader",dir+"world_registration.gdshader"]:
		if load(path) == null: failures += 1
	print("PACK MAP LOAD: 10 checks, ",failures," failures")
	quit(0 if failures == 0 else 1)
