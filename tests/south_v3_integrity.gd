extends SceneTree
var checks:=0
var failures:=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize() -> void:
	var terrain=preload("res://ui/korea_layout_v1/full_r3_v1/terrain_layers.gd").new();terrain.configure()
	var script=preload("res://ui/korea_layout_v1/south_v3/integration/south_v3_layer.gd")
	var layer=script.new();layer.configure(terrain)
	check(layer.approved and terrain.errors.is_empty(),"source integrity and registered inland")
	var mask: Image=(load("res://ui/korea_layout_v1/south_v3/assets/open_sea_keep_mask.png") as Texture2D).get_image()
	if mask.is_compressed():mask.decompress()
	for box: Rect2 in [Rect2(686.69,797.5046,24.62,24.62),Rect2(734.69,808.5046,24.62,24.62),Rect2(643,836.26,22,22)]:
		var valid:=true
		for y in range(floori(box.position.y),ceili(box.end.y)):
			for x in range(floori(box.position.x),ceili(box.end.x)):
				if mask.get_pixel(x-560,y-740).r<0.999:valid=false
		check(valid,"sea render mask preserves whole castle rectangle")
	check(mask.get_pixel(290,220).r<0.01,"far sea mask returns original")
	for point: Vector2 in [Vector2(654,851),Vector2(640,840),Vector2(805,820),Vector2(700,930),Vector2(560,800)]:
		check(layer.coverage_at(point)==0,"unapproved river/coast/castle has zero coverage")
	var entry: Dictionary=terrain.approvals.tiles.south_continuous_v3
	for field: String in ["sha256","mesh_sha256","shader_sha256","sea_mask_sha256"]:
		var prior: String=entry[field];entry[field]="controlled-invalid"
		var invalid=script.new();invalid.configure(terrain)
		invalid.sync(Rect2(0,0,1254,1254),10,true)
		check(not invalid.approved and invalid.weight==0,"changed "+field+" cannot inherit approval")
		invalid.free();entry[field]=prior
	check(terrain.approved(terrain.tiles.filter(func(t):return t.id=="detail_3_1")[0]),"Jeju approval independent")
	layer.free()
	print("SOUTH V3 INTEGRITY ",checks," checks ",failures," failures")
	quit(0 if failures==0 else 1)
