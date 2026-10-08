extends SceneTree
func _initialize() -> void:
	var source := Image.load_from_file("res://ui/korea_layout_v1/bohai_20261002/bohai.png")
	for item in [["dalian",Rect2(300,300,350,350)],["yantai",Rect2(220,520,350,350)]]:
		var r: Rect2 = item[1]
		var pixels := Rect2i(r.position*Vector2(source.get_size())/1000.0,r.size*Vector2(source.get_size())/1000.0)
		source.get_region(pixels).save_png("res://tests/bohai_20261002/"+item[0]+"_guide.png")
	quit()
