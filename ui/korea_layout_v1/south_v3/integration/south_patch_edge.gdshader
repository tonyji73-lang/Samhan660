shader_type canvas_item;
render_mode unshaded, blend_mix;

// Attach ONLY to the separate terrain-patch CanvasItem, never the full map/UI.
// Draw the complete texture with UV 0..1, over the approved base map.
// Native source rect: (560, 740, 300, 260).
uniform vec2 native_size = vec2(300.0, 260.0);
uniform float edge_width_native : hint_range(0.1, 8.0, 0.1) = 4.0;
// Caller sets the verified region's LOD weight. Zero until explicitly set.
uniform float lod_weight : hint_range(0.0, 1.0, 0.01) = 0.0;
// Grayscale rendering data, NOT an sRGB/color texture or a territory mask.
uniform sampler2D open_sea_keep_mask : filter_linear, repeat_disable;
uniform bool use_open_sea_mask = false;

void fragment() {
	vec2 d = min(UV, vec2(1.0) - UV) * native_size;
	float distance_to_edge = max(0.0, min(d.x, d.y));
	float edge_alpha = smoothstep(0.0, max(edge_width_native, 0.0001), distance_to_edge);
	// COLOR already includes TEXTURE * vertex/modulate color in canvas_item.
	// RGB and UV remain untouched: this does not fix geographic differences.
	float sea_keep = use_open_sea_mask ? texture(open_sea_keep_mask, UV).r : 1.0;
	COLOR.a *= edge_alpha * sea_keep * clamp(lod_weight, 0.0, 1.0);
}
