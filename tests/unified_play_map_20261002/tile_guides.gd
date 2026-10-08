extends SceneTree
const DIR = "res://ui/korea_layout_v1/unified_world_20261002/"
const OUT = "res://tests/unified_play_map_20261002/"
func _initialize() -> void:
	var image := Image.load_from_file(DIR+"atlas.png")
	image.resize(3300,2200,Image.INTERPOLATE_LANCZOS)
	var tiles: Array = []
	var xs := [-900,-600,-300,0,300,600,900,1200,1500,1800,2050]
	var ys := [-700,-400,-100,200,500,800,1100]
	for row in range(ys.size()):
		for col in range(xs.size()):
			var r := Rect2i(xs[col],ys[row],350,350)
			var land := 0
			for y in range(0,350,6):
				for x in range(0,350,6):
					var native := Vector2i(r.position+Vector2i(x,y))
					if Rect2i(0,0,1000,1254).has_point(native): continue
					var c := image.get_pixel(native.x+900,native.y+700)
					if not (c.b>c.r+0.025 and c.g>c.r+0.02): land += 1
			if land < 40: continue
			var id := "tile_%02d_%02d" % [row,col]
			image.get_region(Rect2i(r.position+Vector2i(900,700),r.size)).save_png(OUT+id+"_guide.png")
			tiles.append({"id":id,"path":id+".png","rect":[r.position.x,r.position.y,350,350],"fade":[350-(xs[col]-xs[col-1]) if col>0 else 0,50 if row>0 else 0]})
	var sites := {}
	var pixels := {"steppe_sijie":[100,80],"steppe_duolange":[220,65],"steppe_huihe":[350,70],"steppe_pugu":[490,100],"steppe_bayegu":[640,120],"steppe_adie":[230,175],"steppe_qibi":[400,210],"steppe_tongluo":[580,205],"steppe_hun":[120,285],"changan":[150,670],"luoyang":[255,665],"shandong":[310,490],"emishi_aguta":[1380,490],"koshi":[1330,580],"kibi":[1135,718],"naniwa":[1245,735],"asuka":[1267,765],"tsukushi":[1010,790],"hayato":[997,854]}
	for id: String in pixels:
		var p: Array = pixels[id]
		sites[id] = [float(p[0])/1536.0*3300.0-900.0,float(p[1])/1024.0*2200.0-700.0]
	var file := FileAccess.open(DIR+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"bounds":[-900,-700,3300,2200],"atlas":"atlas.png","tiles":tiles,"sites":sites,"coordinate_system":"existing play atlas native pixels; original 35 sites unchanged; external presentation only"},"\t"))
	print("UNIFIED DETAIL GUIDES: ",tiles.size())
	quit()