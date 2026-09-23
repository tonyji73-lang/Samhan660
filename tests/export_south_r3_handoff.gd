extends SceneTree
## Requested diagnostic crops. Does not change the source artwork.
const ROOT="res://ui/korea_layout_v1/full_r3_v1/"
const OUT="res://tests/art_review/south_r3_v1/"
var base: Image
var tiles: Array=[]
var mesh: Dictionary
var sites: Array=[]
var issues: Array=[
	{"id":"01_confluences","rect":[600,790,110,100],"mark":[615,807,60,65],"note":"서쪽 큰 굽이와 대가야 북서 합류점 위치를 보정. 본류와 동쪽 지류의 합류 순서·폭은 원본 기준으로 재작성. 대응점 일치만으로 물길 전체 정합 아님."},
	{"id":"02_estuary_islands","rect":[625,900,150,80],"mark":[635,915,115,60],"note":"하구 분기와 작은 섬·바위 형상이 다름. detail_2_2/detail_3_2 겹침 및 아래쪽을 함께 재작성. 연결 수로/섬 개수 차이는 UV나 흐림으로 해결 불가."},
	{"id":"03_east_coast","rect":[775,780,64,128],"mark":[790,794,34,98],"note":"동쪽 갈고리 곶·안쪽 만·아래 해안 위치를 UV로 보정. 세부 해안 굴곡과 산림/해변 폭은 여전히 다름. 원본 해안선을 유지하며 상세 재작성."},
	{"id":"04_dalgubeol_floor","rect":[675,790,48,48],"mark":[686.69,797.5046,24.62,24.62],"city":"dalgubeol","note":"달구벌 (699,814), 폭24.62. 원본도 숲 구릉이며 후보 나무/능선과 바닥 겹침. 성 이동 금지. 원화에서 바닥 전체 접지면 확보."},
	{"id":"05_geumseong_floor","rect":[723,801,48,48],"mark":[734.69,808.5046,24.62,24.62],"city":"geumseong","note":"금성 (747,825), 폭24.62. 후보 산릉/바위가 성 아래에 걸림. 해안 UV 보정은 산릉 자체의 형상 차이를 해결하지 않음. 성 좌표 유지, 원화 재작성."},
	{"id":"06_daegaya_floor","rect":[630,827,48,48],"mark":[643,836.26,22,22],"city":"daegaya","note":"대가야 (654,851), 폭22. 합류점 이동 후에도 주변 숲/지류 폭 별도 수정 필요. 원본 바닥도 수계에 인접. 중심점만으로 승인 금지."},
	{"id":"07_west_tile_boundary","rect":[580,780,80,160],"mark":[599,780,2,160],"note":"x=600에서 detail_2_1 위로 detail_2_2 시작. 독립 원화의 수로·산림·색 불연속. 겹침 x=600..654 및 x=600,y=900 교차점 재작성."},
	{"id":"08_south_tile_boundary","rect":[620,875,180,100],"mark":[620,899,180,2],"note":"y=900에서 detail_3_2가 detail_2_2 위에 시작. 하구·섬·해안·바다 무늬 불연속. 겹침 y=900..954를 동일 지형으로 재작성."}
]

class Plate extends Control:
	var pictures: Array=[]
	var row: Dictionary
	var sprite: Texture2D
	var site: Dictionary={}
	func _draw() -> void:
		var font:=ThemeDB.fallback_font
		var w: float=pictures[0].get_width();var h: float=pictures[0].get_height()
		var names: Array=["APPROVED reference","CANDIDATE original","UV REVIEW, not approved"]
		var r: Array=row.rect;var scale: float=w/float(r[2])
		for i in range(pictures.size()):
			var offset:=Vector2(i*(w+12),48)
			draw_texture(pictures[i],offset)
			draw_string(font,Vector2(offset.x+8,25),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color.WHITE)
			var box: Array=row.mark
			var rect:=Rect2(offset+(Vector2(box[0],box[1])-Vector2(r[0],r[1]))*scale,Vector2(box[2],box[3])*scale)
			draw_rect(rect,Color(1,0.2,0.15),false,2)
			if not site.is_empty():
				var p: Array=site.render_xy;var width: float=site.sprite_width_native
				var at:=offset+(Vector2(p[0],p[1])-Vector2(r[0],r[1])-Vector2(0.5,0.67)*width)*scale
				draw_texture_rect(sprite,Rect2(at,Vector2.ONE*width*scale),false)
				draw_rect(Rect2(at,Vector2.ONE*width*scale),Color.CYAN,false,1)
			draw_string(font,Vector2(offset.x+8,h+72),str(row.id)+" "+str(row.rect),HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color.WHITE)

func _initialize() -> void:
	call_deferred("run")

func pixel(image: Image,p: Vector2) -> Color:
	return image.get_pixel(clampi(floori(p.x),0,image.get_width()-1),clampi(floori(p.y),0,image.get_height()-1))

func mesh_source(p: Vector2) -> Vector2:
	var grid: Vector2=(p-Vector2(600,600))/3.0
	var ix:=clampi(floori(grid.x),0,117);var iy:=clampi(floori(grid.y),0,117)
	var fx: float=grid.x-ix;var fy: float=grid.y-iy
	var indices: Array=[iy*119+ix,iy*119+ix+1,(iy+1)*119+ix,(iy+1)*119+ix+1]
	var weights: Array=[1-fx-fy,fx,fy,0] if fx+fy<=1 else [0,1-fy,1-fx,fx+fy-1]
	var uv:=Vector2.ZERO
	for i in range(4):
		var v: Array=mesh.vertices[indices[i]];uv+=Vector2(v[2],v[3])*weights[i]
	return Vector2(600,600)+uv*354

func sample_candidate(p: Vector2,corrected: bool) -> Color:
	for i in range(tiles.size()-1,-1,-1):
		var tile: Dictionary=tiles[i]
		if tile.rect.has_point(p):
			var q: Vector2=mesh_source(p) if corrected and tile.id=="detail_2_2" else p
			return pixel(tile.image,(q-tile.rect.position)/tile.rect.size*1254.0)
	return pixel(base,p)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	base=Image.load_from_file("res://ui/korea_layout_v1/assets/korea_approved_1254.png")
	mesh=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"south_registration_review.json"))
	sites=JSON.parse_string(FileAccess.get_file_as_string("res://ui/korea_layout_v1/data/castle_layout_v1.json")).points
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	for item: Dictionary in manifest.tiles:
		if item.id not in ["detail_2_1","detail_2_2","detail_3_1","detail_3_2"]:continue
		var r: Array=item.source_rect_px
		tiles.append({"id":item.id,"rect":Rect2(r[0],r[1],r[2],r[3]),"image":Image.load_from_file(ROOT+item.path)})
	var sprite:=ImageTexture.create_from_image(Image.load_from_file("res://ui/korea_layout_v1/assets/korean_fortress_original.png"))
	for issue: Dictionary in issues:
		var r: Array=issue.rect
		var region:=Rect2i(r[0],r[1],r[2],r[3]);var scale:=8 if issue.has("city") else 4
		var images: Array=[]
		base.get_region(region).save_png(OUT+issue.id+"-approved-native.png")
		for mode: String in ["approved","candidate","uv-review"]:
			var img:=Image.create(region.size.x*scale,region.size.y*scale,false,Image.FORMAT_RGB8)
			for y in range(img.get_height()):
				for x in range(img.get_width()):
					var p:=Vector2(region.position)+(Vector2(x,y)+Vector2.ONE*0.5)/float(scale)
					img.set_pixel(x,y,pixel(base,p) if mode=="approved" else sample_candidate(p,mode=="uv-review"))
			img.save_png(OUT+issue.id+"-"+mode+".png");images.append(ImageTexture.create_from_image(img))
		issue.output_size=[region.size.x*scale,region.size.y*scale]
		var viewport:=SubViewport.new();viewport.size=Vector2i((images[0].get_width()+12)*3-12,images[0].get_height()+90)
		viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.transparent_bg=false;root.add_child(viewport)
		var plate:=Plate.new();plate.pictures=images;plate.row=issue;viewport.add_child(plate)
		await process_frame;await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUT+issue.id+"-comparison.png")
		if issue.has("city"):
			plate.site=sites.filter(func(s):return s.id==issue.city)[0];plate.sprite=sprite;plate.queue_redraw()
			await process_frame;await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(OUT+issue.id+"-castle-context.png")
		viewport.queue_free();await process_frame
		print("SOUTH CROP ",issue.id," ",issue.output_size)
	var f:=FileAccess.open(OUT+"issues.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"coordinate_system":"approved 1254x1254 native pixels, top-left origin; rect=x,y,w,h","approved_sha256":FileAccess.get_sha256("res://ui/korea_layout_v1/assets/korea_approved_1254.png"),"display_sampling":"Equal native region/output dimensions; diagnostic nearest sampling only, not new high-resolution art. Native approved crops included.","candidate_composite_order":["detail_2_1","detail_2_2","detail_3_1","detail_3_2"],"annotations":"Red: issue area/full sprite rectangle. Cyan: actual sprite rectangle, NOT certified floor polygon. Original PNG, pivot .5,.67, original native width.","issues":issues},"\t"));f.close()
	quit()
