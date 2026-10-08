extends Control
## Game flag, using the existing map faction colour, not a historical flag claim.
var color: Color=Color("777777")
func _ready() -> void: mouse_filter=Control.MOUSE_FILTER_IGNORE; custom_minimum_size=Vector2(38,42)
func _draw() -> void:
	draw_line(Vector2(7,4),Vector2(7,size.y-3),Color("b69a62"),3)
	draw_colored_polygon(PackedVector2Array([Vector2(9,5),Vector2(size.x-3,5),Vector2(size.x-9,size.y*0.43),Vector2(size.x-3,size.y*0.72),Vector2(9,size.y*0.72)]),color)
