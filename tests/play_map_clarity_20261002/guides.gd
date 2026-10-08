extends SceneTree
func _initialize() -> void:
	var source := Image.load_from_file("res://ui/korea_layout_v1/assets/korea_approved_1254.png")
	var rows := [["northwest",0,0],["north",300,0],["northeast",600,0],["west",300,300],["east",600,300],["southwest",300,600],["southeast",600,600],["south",300,900],["south_coast",600,900]]
	for row: Array in rows:
		source.get_region(Rect2i(row[1],row[2],350,350)).save_png("res://tests/play_map_clarity_20261002/guide_"+row[0]+".png")
	quit()