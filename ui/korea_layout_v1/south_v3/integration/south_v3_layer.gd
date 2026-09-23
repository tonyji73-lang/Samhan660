extends Control
const DIR="res://ui/korea_layout_v1/south_v3/"
const ID="south_continuous_v3"
var review: bool="--south-v3-review" in OS.get_cmdline_user_args()
var raw: bool=false
var suppressed: bool=false
var approved: bool=false
var error: String=""
var weight: float=0
var world:=Rect2()
var texture: Texture2D
var region_mesh: ArrayMesh
var descriptor: Dictionary={}
var approval: Dictionary={}
var hashes: Dictionary={}
var drawn: bool=false
var region_data: Dictionary={}

func configure(layer: RefCounted) -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	descriptor=JSON.parse_string(FileAccess.get_file_as_string(DIR+"south_continuous_v3.json"))
	var png: String=DIR+descriptor.path
	var shader_path: String=DIR+descriptor.edge_blend.shader
	var mask_path: String=DIR+descriptor.open_sea_mask.path
	var mesh_path: String=DIR+"inland_registration.json"
	hashes={"png":FileAccess.get_sha256(png),"shader":FileAccess.get_sha256(shader_path),"sea_mask":FileAccess.get_sha256(mask_path),"mesh":FileAccess.get_sha256(mesh_path)}
	if hashes.png!=descriptor.sha256 or hashes.shader!=descriptor.edge_blend.shader_sha256 or hashes.sea_mask!=descriptor.open_sea_mask.sha256:
		error="v3 source hash mismatch";return
	texture=_texture(png);var mask:=_texture(mask_path)
	if texture.get_size()!=Vector2(1346,1168) or mask.get_size()!=Vector2(300,260):
		error="v3 source size mismatch";return
	var mesh_data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(mesh_path))
	region_data=mesh_data
	region_mesh=layer._registered_mesh(mesh_data)
	approval=layer.approvals.get("tiles",{}).get(ID,{})
	var tile: Dictionary={"id":ID,"sha256":hashes.png,"registered_mesh":region_mesh,"registered_mesh_hash":hashes.mesh}
	approved=layer.approved(tile) and approval.get("shader_sha256","")==hashes.shader and approval.get("sea_mask_sha256","")==hashes.sea_mask and FileAccess.get_sha256(layer.BASE)==descriptor.source_sha256
	var mat:=ShaderMaterial.new();mat.shader=load(shader_path)
	mat.set_shader_parameter("open_sea_keep_mask",mask)
	mat.set_shader_parameter("use_open_sea_mask",true)
	mat.set_shader_parameter("lod_weight",0.0)
	material=mat

func _texture(path: String) -> Texture2D:
	var resource:=load(path) as Texture2D
	var image:=resource.get_image()
	if image.is_compressed():image.decompress()
	if not image.has_mipmaps():image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func sync(rect: Rect2,pixels_per_native: float,allowed: bool) -> void:
	world=rect
	weight=0.0
	if allowed and not suppressed and error.is_empty():
		weight=1.0 if review else (smoothstep(1.8,2.6,pixels_per_native) if approved else 0.0)
	if material:
		material.set_shader_parameter("lod_weight",weight)
		material.set_shader_parameter("edge_width_native",0.0001 if raw and review else 4.0)
		material.set_shader_parameter("use_open_sea_mask",not (raw and review))
	queue_redraw()

func _draw() -> void:
	drawn=false
	if weight<=0 or texture==null:return
	var scale: Vector2=world.size/1254.0
	var rect:=Rect2(world.position+Vector2(560,740)*scale,Vector2(300,260)*scale)
	if not Rect2(Vector2.ZERO,size).intersects(rect):return
	if review:draw_texture_rect(texture,rect,false)
	else:
		var transform:=Transform2D(Vector2(scale.x,0),Vector2(0,scale.y),world.position)
		draw_mesh(region_mesh,texture,transform)
	drawn=true

func diagnostics() -> Dictionary:
	return {"id":ID,"path":DIR+str(descriptor.get("path","")),"hashes":hashes,"approved":approved,"approval":approval,"region_polygon":region_data.get("polygon_native",[]),"review":review,"raw":raw,"drawn":drawn,"weight":weight,"shader_weight":material.get_shader_parameter("lod_weight") if material else -1,"sea_mask_enabled":material.get_shader_parameter("use_open_sea_mask") if material else false,"error":error}

func coverage_at(native: Vector2) -> float:
	if not Rect2(560,740,300,260).has_point(native) or region_data.is_empty():return 0
	var grid: Vector2=(native-Vector2(560,740))/2
	var x:=mini(int(grid.x),149);var y:=mini(int(grid.y),129)
	var fx: float=grid.x-x;var fy: float=grid.y-y
	var i:=y*151+x;var v: Array=region_data.vertices
	return v[i][4]*(1-fx-fy)+v[i+1][4]*fx+v[i+151][4]*fy if fx+fy<=1 else v[i+1][4]*(1-fy)+v[i+151][4]*(1-fx)+v[i+152][4]*(fx+fy-1)
