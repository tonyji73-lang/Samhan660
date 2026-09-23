extends RefCounted
## Display-only registration. A package flag cannot approve generated geography.
const ROOT="res://ui/korea_layout_v1/full_r3_v1/"
const BASE="res://ui/korea_layout_v1/assets/korea_approved_1254.png"
const SOUTH_V2="res://ui/korea_layout_v1/south_v2/"
var south_v2_review: bool="--south-v2-review" in OS.get_cmdline_user_args()
var south_v2: Dictionary={}
var tiles: Array[Dictionary]=[]
var errors: Array[String]=[]
var review: bool="--full-r3-review" in OS.get_cmdline_user_args()
var suppressed: bool=false
var review_tile: String=""
var registered_review: bool=false
var last_drawn: Array[String]=[]
var approvals: Dictionary={}

func configure() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"manifest.json"))
	if manifest.get("source_sha256","")!=FileAccess.get_sha256(BASE):
		errors.append("approved atlas hash mismatch");return
	if FileAccess.file_exists(ROOT+"registration_review.json"):
		approvals=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"registration_review.json"))
	for row: Dictionary in manifest.tiles:
		var path: String=ROOT+row.path
		var resource:=load(path) as Texture2D
		var image: Image=resource.get_image() if resource else null
		if image==null or image.get_size()!=Vector2i(row.size_px[0],row.size_px[1]) or FileAccess.get_sha256(path)!=row.sha256:
			errors.append(str(row.id)+" size/hash mismatch");continue
		if image.is_compressed(): image.decompress()
		if not image.has_mipmaps(): image.generate_mipmaps()
		var tile: Dictionary=row.duplicate(true)
		tile.texture=ImageTexture.create_from_image(image)
		tile.rect=Rect2(row.source_rect_px[0],row.source_rect_px[1],row.source_rect_px[2],row.source_rect_px[3])
		tile.mesh=_mesh(tile)
		# South UV correction is available for review, but is NOT an approval.
		# Production still requires the independently pinned registration_review entry.
		var registration: String={"detail_3_1":"jeju_registration.json","detail_2_2":"south_registration_review.json"}.get(row.id,"")
		if not registration.is_empty() and FileAccess.file_exists(ROOT+registration):
			var registered: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+registration))
			if registered.get("folded_cells",1)==0 and registered.get("source_sha256","")==row.sha256:
				tile.registered_mesh=_registered_mesh(registered)
				tile.registered_mesh_hash=FileAccess.get_sha256(ROOT+registration)
				var region: Array=registered.region
				tile.registered_rect=Rect2(region[0],region[1],region[2],region[3])
		tiles.append(tile)
	_load_south_v2()

func _load_south_v2() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOUTH_V2+"south_continuous_v2.json"))
	var path: String=SOUTH_V2+str(data.path)
	var texture:=load(path) as Texture2D
	var r: Array=data.source_rect_px
	var region:=Rect2(r[0],r[1],r[2],r[3])
	if texture==null or texture.get_size()!=Vector2(1346,1168) or FileAccess.get_sha256(path)!=data.sha256 or FileAccess.get_sha256(BASE)!=data.source_sha256 or region!=Rect2(560,740,300,260):
		errors.append("south v2 registration/size/hash mismatch");return
	var image:=texture.get_image()
	if image.is_compressed():image.decompress()
	if not image.has_mipmaps():image.generate_mipmaps()
	south_v2={"id":"south_continuous_v2","path":path,"sha256":data.sha256,"rect":Rect2(560,740,300,260),"texture":ImageTexture.create_from_image(image)}
	# Identity UV on this NEW rectangle; never reuse the previous tile's 12-point warp.
	south_v2.mesh=_mesh(south_v2)

func approved(tile: Dictionary) -> bool:
	var entry: Dictionary=approvals.get("tiles",{}).get(tile.id,{})
	return tile.has("registered_mesh") and entry.get("mesh_sha256","")==tile.get("registered_mesh_hash","") and entry.get("sha256","")==tile.sha256 and entry.get("status","")=="visually_registered" and not entry.get("regions",[]).is_empty()

func weight(tile: Dictionary, pixels_per_source: float) -> float:
	if suppressed: return 0.0
	if south_v2_review:
		# Review the new continuous patch against the approved atlas, not a stack
		# of unregistered candidates. The approved Jeju patch remains independent.
		return smoothstep(1.8,2.6,pixels_per_source) if approved(tile) else 0.0
	if review:
		if not review_tile.is_empty() and tile.id!=review_tile:return 0.0
		return smoothstep(1.05,1.65,pixels_per_source) if tile.level=="overview" else smoothstep(1.8,2.6,pixels_per_source)
	if not approved(tile): return 0.0
	return smoothstep(1.8,2.6,pixels_per_source)

func _mesh(tile: Dictionary) -> ArrayMesh:
	var mesh:=ArrayMesh.new()
	var rect: Rect2=tile.rect
	var vertices:=PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_TEX_UV]=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
	arrays[Mesh.ARRAY_INDEX]=PackedInt32Array([0,1,2,0,2,3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

func _registered_mesh(data: Dictionary) -> ArrayMesh:
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX)
	var vertices:=PackedVector2Array();var uvs:=PackedVector2Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	for v: Array in data.vertices:
		vertices.append(Vector2(v[0],v[1]));uvs.append(Vector2(v[2],v[3]));colors.append(Color(v[5],v[6],v[7],v[4]) if v.size()==8 else Color(1,1,1,v[4]))
	var cols: int=int(data.grid[0]);var rows: int=int(data.grid[1])
	for y in range(rows-1):
		for x in range(cols-1):
			var i:=y*cols+x;indices.append_array(PackedInt32Array([i,i+1,i+cols,i+1,i+cols+1,i+cols]))
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	return mesh

func draw_on(canvas: CanvasItem, world: Rect2, pixels_per_source: float) -> void:
	last_drawn.clear()
	var transform:=Transform2D(Vector2(world.size.x/1254.0,0),Vector2(0,world.size.y/1254.0),world.position)
	for tile: Dictionary in tiles:
		var opacity: float=weight(tile,pixels_per_source)
		if opacity<=0: continue
		var use_registration: bool=tile.has("registered_mesh") and (south_v2_review or not review or registered_review)
		var native: Rect2=tile.registered_rect if use_registration else tile.rect
		var bounds:=Rect2(world.position+native.position*world.size/1254.0,native.size*world.size/1254.0)
		if not Rect2(Vector2.ZERO,canvas.size).intersects(bounds):continue
		var mesh: ArrayMesh=tile.registered_mesh if use_registration else tile.mesh
		canvas.draw_mesh(mesh,tile.texture,transform,Color(1,1,1,opacity))
		last_drawn.append(tile.id)
	if south_v2_review and not suppressed and not south_v2.is_empty():
		var r: Rect2=south_v2.rect
		var bounds:=Rect2(world.position+r.position*world.size/1254.0,r.size*world.size/1254.0)
		if Rect2(Vector2.ZERO,canvas.size).intersects(bounds):
			canvas.draw_mesh(south_v2.mesh,south_v2.texture,transform)
			last_drawn.append(south_v2.id)

func diagnostics(pixels_per_source: float) -> Dictionary:
	var rows: Array=[]
	for tile: Dictionary in tiles:
		rows.append({"id":tile.id,"sha256":tile.sha256,"size":tile.size_px,"approved":approved(tile),"weight":weight(tile,pixels_per_source),"screen_pixels_per_texel":pixels_per_source/float(tile.texels_per_source_pixel)})
	return {"tiles":rows,"errors":errors,"review":review,"drawn":last_drawn,"south_v2_review":south_v2_review,"south_v2_path":south_v2.get("path",""),"south_v2_sha256":south_v2.get("sha256",""),"south_v2_auto_approved":false}
