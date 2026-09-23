extends SceneTree
func sample(image: Image,p: Vector2,candidate: bool) -> Color:
	var q: Vector2=(p-Vector2(560,740))*Vector2(1346.0/300.0,1168.0/260.0) if candidate else p
	return image.get_pixel(clampi(floori(q.x),0,image.get_width()-1),clampi(floori(q.y),0,image.get_height()-1))

func river_runs(image: Image,y: float,candidate: bool) -> Array:
	var runs: Array=[];var start: float=-1
	for i in range(161):
		var x: float=610+i*0.25;var c:=sample(image,Vector2(x,y),candidate)
		var water: bool=c.b>c.r*1.12 and c.g>c.r*1.06 and c.b>c.g*0.95
		if water and start<0:start=x
		if not water and start>=0:
			if x-start>=1:runs.append([start,x])
			start=-1
	return runs

func _initialize() -> void:
	const OUT="res://tests/art_review/south_v2/"
	DirAccess.make_dir_recursive_absolute(OUT)
	var base:=Image.load_from_file("res://ui/korea_layout_v1/assets/korea_approved_1254.png")
	var crop:=base.get_region(Rect2i(560,740,300,260))
	crop.save_png(OUT+"approved-native.png")
	crop.resize(1346,1168,Image.INTERPOLATE_NEAREST)
	crop.save_png(OUT+"approved-comparison.png")
	var candidate:=Image.load_from_file("res://ui/korea_layout_v1/south_v2/assets/south_continuous_v2.png")
	candidate.save_png(OUT+"v2-comparison.png")
	var measurements: Array=[]
	for y: float in [740.25,800,820,840,850,860]:
		measurements.append({"native_y":y,"approved_water_color_runs":river_runs(base,y,false),"v2_water_color_runs":river_runs(candidate,y,true)})
	var file:=FileAccess.open(OUT+"new_image_measurements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"method":"Same native transects x=610..650, water-color intervals. Approximate raster diagnostic only; NOT a land mask, verified feature correspondence or topology approval. Reference image has 1 native pixel resolution; quarter-pixel sampling is not quarter-pixel accuracy.","sha256":FileAccess.get_sha256("res://ui/korea_layout_v1/south_v2/assets/south_continuous_v2.png"),"rows":measurements},"\t"));file.close()
	print("SOUTH V2 diagnostic crops: identical extent, 1346x1168 output; approved enlargement is not new art")
	quit()
