extends SceneTree
const OUT = "res://tests/map_detail_20261006/"
func _initialize() -> void:
	var base := Image.load_from_file("res://ui/korea_layout_v1/bohai_20261002/bohai.png")
	var south := Image.load_from_file("res://ui/korea_layout_v1/bohai_20261002/bohai_join.png")
	# Reference preparation: reproduce the existing shader's southern join.
	for y in range(base.get_height()):
		var weight := smoothstep(0.76,0.80,float(y)/float(base.get_height()))
		if weight <= 0: continue
		for x in range(base.get_width()):
			base.set_pixel(x,y,base.get_pixel(x,y).lerp(south.get_pixel(x,y),weight))
	var entries: Array = []
	for p: Vector2i in [Vector2i(0,0),Vector2i(325,0),Vector2i(650,0),Vector2i(0,325),Vector2i(325,325),Vector2i(0,650),Vector2i(325,650)]:
		var id := "bohai_%d_%d" % [p.x,p.y]
		base.get_region(Rect2i(Vector2(p)*1.254,Vector2(350,350)*1.254)).save_png(OUT+id+".png")
		entries.append({"id":id,"rect":[p.x,p.y,350,350],"layer":"bohai"})
	var atlas := Image.load_from_file("res://ui/korea_layout_v1/unified_world_20261002/atlas.png")
	for y in [800,1100]:
		var id := "sea_0_%d" % y
		atlas.get_region(Rect2i(Vector2(900,y+700)*Vector2(atlas.get_size())/Vector2(3300,2200),Vector2(350,350)*Vector2(atlas.get_size())/Vector2(3300,2200))).save_png(OUT+id+".png")
		entries.append({"id":id,"rect":[0,y,350,350],"layer":"world"})
	var f := FileAccess.open(OUT+"manifest.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(entries,"\t"))
	print("GUIDES ",entries.size())
	quit()
