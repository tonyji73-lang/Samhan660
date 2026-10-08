extends Node2D
## Drawing-only child: takes no Container slot, mouse input or keyboard focus.
const Art = preload("res://ui/living_city_v1/ornament_resources.gd")
var decoration: StyleBoxTexture
var placement := "frame"
var corner_scale := 1.0

static func attach(parent: Control, profile: String, position_kind: String = "frame") -> Node2D:
	var node := new()
	node.name="Ornament_"+profile
	node.decoration=Art.style(profile)
	node.placement=position_kind
	# Keep the manifest's source/slices; render smaller end ornaments inside the
	# original frame bounds so existing 12px text padding remains unobstructed.
	if profile in ["top","bottom"]: node.corner_scale=0.5
	if profile=="work_panel": node.corner_scale=0.4
	parent.add_child(node)
	parent.resized.connect(node.queue_redraw)
	node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	node.texture_repeat=CanvasItem.TEXTURE_REPEAT_DISABLED
	return node

func _draw() -> void:
	var control: Control=get_parent()
	var rect := Rect2(Vector2.ZERO,control.size)
	if placement=="underline": rect=Rect2(16,control.size.y-12,control.size.x-32,12)
	if placement=="title_line": rect=Rect2(48,control.size.y-12,control.size.x-96,12)
	if corner_scale!=1.0:
		draw_set_transform(Vector2.ZERO,0,Vector2.ONE*corner_scale)
		rect=Rect2(rect.position/corner_scale,rect.size/corner_scale)
	decoration.draw(get_canvas_item(),rect)

func select(value: bool) -> void:
	modulate=Color.WHITE if value else Color(0.65,0.65,0.65,0.55)
