extends SceneTree
func _initialize() -> void:
	var image := Image.create(1536,1024,false,Image.FORMAT_RGB8)
	image.fill(Color("536b52"))
	var korea := Image.load_from_file("res://ui/korea_layout_v1/assets/korea_approved_1254.png")
	korea.resize(584,584,Image.INTERPOLATE_LANCZOS)
	image.blit_rect(korea,Rect2i(0,0,584,584),Vector2i(419,326))
	image.save_png("res://tests/unified_play_map_20261002/outpaint_guide.png")
	quit()