shader_type canvas_item;
render_mode unshaded;
#include "res://ui/korea_layout_v1/unified_world_20261002/play_atlas_coverage.gdshaderinc"
void fragment() {
	vec2 native = UV * 1254.0;
	float edge = play_atlas_coverage(native);
	vec4 art = texture(TEXTURE,UV);
	COLOR = vec4(art.rgb,art.a*edge);
}
