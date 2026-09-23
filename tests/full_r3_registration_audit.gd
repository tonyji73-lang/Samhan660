extends SceneTree
const DIR="res://ui/korea_layout_v1/full_r3_v1/"
var images: Dictionary={}
var base: Image
var jeju: Dictionary={}
func registered_pixel(p: Vector2) -> Color:
	var cell: Vector2=(p-Vector2(470,1048))/2.0
	var x:=clampi(floori(cell.x),0,60);var y:=clampi(floori(cell.y),0,49)
	var f:=cell-Vector2(x,y);var i:=y*62+x
	var a: Array=jeju.vertices[i];var b: Array=jeju.vertices[i+1];var c: Array=jeju.vertices[i+62];var d: Array=jeju.vertices[i+63]
	var uv: Vector2
	if f.x+f.y<=1:uv=Vector2(a[2],a[3])*(1-f.x-f.y)+Vector2(b[2],b[3])*f.x+Vector2(c[2],c[3])*f.y
	else:uv=Vector2(d[2],d[3])*(f.x+f.y-1)+Vector2(b[2],b[3])*(1-f.y)+Vector2(c[2],c[3])*(1-f.x)
	return images.detail_3_1.get_pixel(clampi(roundi(uv.x*1254),0,1253),clampi(roundi(uv.y*1254),0,1253))
func water(c: Color) -> bool:
	return c.b>c.r*1.10 and c.g>c.r*1.06 and c.b>c.g*0.95 and c.b>0.12
func pixel(tile: Dictionary,p: Vector2) -> Color:
	var rect: Array=tile.source_rect_px
	var xy: Vector2=(p-Vector2(rect[0],rect[1]))/Vector2(rect[2],rect[3])*1254.0
	return images[tile.id].get_pixel(clampi(roundi(xy.x),0,1253),clampi(roundi(xy.y),0,1253))
func _initialize() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DIR+"manifest.json"))
	base=Image.load_from_file("res://ui/korea_layout_v1/assets/korea_approved_1254.png")
	jeju=JSON.parse_string(FileAccess.get_file_as_string(DIR+"jeju_registration.json"))
	for tile: Dictionary in manifest.tiles: images[tile.id]=Image.load_from_file(DIR+tile.path)
	var measurements: Array=[];var seams: Array=[];var floors: Array=[]
	for tile: Dictionary in manifest.tiles:
		var r: Array=tile.source_rect_px;var count:=0;var mismatches:=0
		for y in range(int(r[1]),int(r[1]+r[3]),3):
			for x in range(int(r[0]),int(r[0]+r[2]),3):
				if water(base.get_pixel(x,y))!=water(pixel(tile,Vector2(x,y))):mismatches+=1
				count+=1
		measurements.append({"id":tile.id,"samples":count,"water_class_disagreement":float(mismatches)/count})
		for other: Dictionary in manifest.tiles:
			if other.id<=tile.id or other.level!=tile.level:continue
			var s: Array=other.source_rect_px
			var overlap:=Rect2(r[0],r[1],r[2],r[3]).intersection(Rect2(s[0],s[1],s[2],s[3]))
			if not overlap.has_area():continue
			var n:=0;var different:=0;var error:=0.0
			for y in range(int(overlap.position.y),int(overlap.end.y),3):
				for x in range(int(overlap.position.x),int(overlap.end.x),3):
					var a:=pixel(tile,Vector2(x,y));var b:=pixel(other,Vector2(x,y))
					if water(a)!=water(b):different+=1
					error+=Vector3(a.r-b.r,a.g-b.g,a.b-b.b).length_squared()/3.0;n+=1
			seams.append({"a":tile.id,"b":other.id,"overlap":[overlap.position.x,overlap.position.y,overlap.size.x,overlap.size.y],"water_class_disagreement":float(different)/n,"rgb_rmse":sqrt(error/n)})
	var layout: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://ui/korea_layout_v1/data/castle_layout_v1.json"))
	var sprite:=Image.load_from_file("res://ui/korea_layout_v1/assets/korean_fortress_original.png")
	for site: Dictionary in layout.points:
		var rows: Array=[]
		for tile: Dictionary in manifest.tiles:
			var r: Array=tile.source_rect_px;var anchor:=Vector2(site.render_xy[0],site.render_xy[1])
			if tile.level!="detail" or not Rect2(r[0],r[1],r[2],r[3]).has_point(anchor):continue
			var n:=0;var wet:=0;var original_wet:=0;var corrected_wet:=0
			for y in range(roundi(sprite.get_height()*0.60),roundi(sprite.get_height()*0.90),2):
				for x in range(0,sprite.get_width(),2):
					if sprite.get_pixel(x,y).a<0.4:continue
					var p:=anchor+(Vector2(x,y)/Vector2(sprite.get_size())-Vector2(0.5,0.67))*float(site.sprite_width_native)
					if water(pixel(tile,p)):wet+=1
					if site.id=="tamna" and water(registered_pixel(p)):
						corrected_wet+=1
						if corrected_wet<=5:print("JEJU flagged terrain sample ",p," rgb ",registered_pixel(p))
					if water(base.get_pixel(clampi(roundi(p.x),0,1253),clampi(roundi(p.y),0,1253))):original_wet+=1
					n+=1
			rows.append({"tile":tile.id,"sample_count":n,"candidate_water_fraction":float(wet)/n,"base_water_fraction":float(original_wet)/n})
			if site.id=="tamna":rows[-1]["registered_water_fraction"]=float(corrected_wet)/n
		floors.append({"id":site.id,"marker_only":site.marker_only,"anchor":site.render_xy,"lower_sprite_samples":rows})
	var output: Dictionary={"method":"RGB water heuristic: diagnostic only, not a territory/land mask or geography approval. Floors use opaque lower 60-90% of actual castle source sprite; vegetation requires visual review.","tiles":measurements,"seams":seams,"castles":floors}
	DirAccess.make_dir_recursive_absolute("res://.godot/full-r3-regions")
	var f:=FileAccess.open("res://.godot/full-r3-regions/registration_audit.json",FileAccess.WRITE);f.store_string(JSON.stringify(output,"\t"));f.close()
	print("REGISTRATION AUDIT ",measurements.size()," tiles ",seams.size()," overlaps ",floors.size()," castles")
	quit()
