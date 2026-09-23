extends Control
## Behind the map's routes, castles and labels; the base and detail share one camera.
var map: Control
func _draw() -> void:
	if is_instance_valid(map):map._draw_terrain(self)
