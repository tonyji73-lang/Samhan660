extends SceneTree
const ROOT="res://ui/korea_layout_v1/full_r3_v1/"
const OUT="res://tests/art_review/south_r3_v1/"
const TILE=Rect2(600,600,354,354)

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var base:=Image.load_from_file("res://ui/korea_layout_v1/assets/korea_approved_1254.png")
	var candidate:=Image.load_from_file(ROOT+"assets/detail/detail_2_2.png")
	var crop:=base.get_region(Rect2i(TILE));crop.resize(1254,1254,Image.INTERPOLATE_NEAREST)
	crop.save_png(OUT+"tile-approved.png");candidate.save_png(OUT+"tile-candidate.png")
	for pair: Array in [["approved",crop],["candidate",candidate]]:
		var grid: Image=pair[1].duplicate()
		for value in range(600,955,25):
			var pixel:=roundi((value-600)*1254.0/354.0)
			grid.fill_rect(Rect2i(pixel,0,1,1254),Color(1,0.3,0.3,1))
			grid.fill_rect(Rect2i(0,pixel,1254,1),Color(1,0.3,0.3,1))
		grid.save_png(OUT+"tile-"+pair[0]+"-grid.png")
	print("SOUTH exported exact [600,600,354,354] at 1254 square; approved nearest display enlargement only")
	quit()
