extends SceneTree
const DIR="res://ui/korea_layout_v1/full_r3_v1/"
var base: Image
var detail: Image
var rect:=Rect2(300,900,354,354)
const AREA=Rect2(470,1048,122,100)
func water(c: Color) -> bool:
	return c.b>c.r*1.10 and c.g>c.r*1.06 and c.b>c.g*0.95 and c.b>0.12
func sample(image: Image,p: Vector2,candidate: bool) -> Color:
	var pixel: Vector2=(p-rect.position)/rect.size*Vector2(image.get_size()) if candidate else p
	return image.get_pixel(clampi(roundi(pixel.x),0,image.get_width()-1),clampi(roundi(pixel.y),0,image.get_height()-1))
func center(image: Image,candidate: bool) -> Vector2:
	var sum:=Vector2.ZERO;var count:=0
	for y in range(1060,1135):
		for x in range(475,585):
			if not water(sample(image,Vector2(x,y),candidate)):
				sum+=Vector2(x,y);count+=1
	return sum/float(count)
func coast(image: Image,origin: Vector2,angle: float,candidate: bool) -> float:
	var dir:=Vector2.from_angle(angle);var dry: float=0
	# This isolated island has no other land within the surveyed radial window.
	for i in range(4,142):
		var r:=i*0.5
		if not water(sample(image,origin+dir*r,candidate)): dry=r
	return dry
func radius(values: Array,angle: float) -> float:
	var index: float=fposmod(angle,TAU)/TAU*values.size()
	return lerpf(values[floori(index)%values.size()],values[(floori(index)+1)%values.size()],fmod(index,1.0))
func average(image: Image,p: Vector2,candidate: bool) -> Color:
	var sum:=Color(0,0,0,0)
	for y in [-3,0,3]:
		for x in [-3,0,3]:sum+=sample(image,p+Vector2(x,y),candidate)
	return sum/9.0
func _initialize() -> void:
	base=Image.load_from_file("res://ui/korea_layout_v1/assets/korea_approved_1254.png")
	detail=Image.load_from_file(DIR+"assets/detail/detail_3_1.png")
	var a:=center(base,false);var b:=center(detail,true)
	var ra: Array=[];var rb: Array=[]
	for i in range(128):
		var angle:=TAU*i/128.0
		ra.append(coast(base,a,angle,false));rb.append(coast(detail,b,angle,true))
	# Median suppresses isolated foam/noise; this is a visual-art contour, not a territory mask.
	for values: Array in [ra,rb]:
		var original:=values.duplicate()
		for i in range(values.size()):
			var neighborhood: Array=[original[posmod(i-1,128)],original[i],original[(i+1)%128]]
			neighborhood.sort();values[i]=neighborhood[1]
		for smoothing in range(3):
			original=values.duplicate()
			for i in range(values.size()): values[i]=(original[posmod(i-1,128)]+2.0*original[i]+original[(i+1)%128])/4.0
	var vertices: Array=[];var cols:=62;var rows:=51
	for y in range(rows):
		for x in range(cols):
			var p:=AREA.position+Vector2(x,y)*2.0
			var delta:=p-a;var angle:=delta.angle();var r:=delta.length()
			var edge:=radius(ra,angle);var other:=radius(rb,angle)
			var source:=p
			if r<edge: source=b+delta*(other/maxf(edge,1))
			else:
				var influence:=1.0-smoothstep(edge,edge+36.0,r)
				source=p+((b-a)+delta.normalized()*(other-edge))*influence
			var uv: Vector2=(source-rect.position)/rect.size
			var border:=minf(minf(p.x-AREA.position.x,AREA.end.x-p.x),minf(p.y-AREA.position.y,AREA.end.y-p.y))
			# End in water beyond the registered shore, never fade away the shoreline.
			var alpha:=smoothstep(0,5,border)*(1.0-smoothstep(edge+6,edge+18,r))
			var gain:=Color.WHITE
			if r>edge+2:
				var bg:=average(base,p,false);var fg:=average(detail,source,true)
				var amount:=smoothstep(edge+2,edge+9,r)
				gain=Color.WHITE.lerp(Color(clampf(bg.r/maxf(fg.r,0.01),0.5,2.0),clampf(bg.g/maxf(fg.g,0.01),0.5,2.0),clampf(bg.b/maxf(fg.b,0.01),0.5,2.0)),amount)
			vertices.append([p.x,p.y,uv.x,uv.y,alpha,gain.r,gain.g,gain.b])
	var folds:=0
	for y in range(rows-1):
		for x in range(cols-1):
			var i:=y*cols+x
			var v: Array=vertices[i];var right: Array=vertices[i+1];var down: Array=vertices[i+cols];var corner: Array=vertices[i+cols+1]
			var u:=Vector2(v[2],v[3]);var r:=Vector2(right[2],right[3]);var d:=Vector2(down[2],down[3]);var q:=Vector2(corner[2],corner[3])
			if (r-u).cross(d-u)<=0 or (q-r).cross(d-r)<=0: folds+=1
	var result: Dictionary={"tile":"detail_3_1","source_sha256":FileAccess.get_sha256(DIR+"assets/detail/detail_3_1.png"),"region":[470,1048,122,100],"grid":[cols,rows],"vertices":vertices,"base_center":[a.x,a.y],"candidate_center":[b.x,b.y],"base_radii":ra,"candidate_radii":rb,"folded_cells":folds,"note":"Isolated Jeju art-contour registration only; no game or territory geometry changed. Ocean edge feather is not a coast correction."}
	var file:=FileAccess.open(DIR+"jeju_registration.json",FileAccess.WRITE);file.store_string(JSON.stringify(result));file.close()
	print("JEJU REGISTRATION centers ",a," -> ",b," folded cells ",folds)
	quit(0 if folds==0 else 1)
