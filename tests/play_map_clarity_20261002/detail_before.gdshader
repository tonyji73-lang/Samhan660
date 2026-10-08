shader_type canvas_item;
render_mode unshaded;
uniform sampler2D original_map : source_color, filter_linear, repeat_disable;
uniform vec4 source_rect;
uniform float detail_weight = 0.0;

// Conservative visual guard, not a gameplay land/river mask.
float water_tone(vec3 c) {
	return smoothstep(0.01, 0.06, min(c.b-c.r, c.g-c.r));
}
void fragment() {
	vec2 native = source_rect.xy + UV * source_rect.zw;
	vec2 uv = native / 1254.0;
	vec4 art = texture(TEXTURE, UV);
	vec3 original = texture(original_map, uv).rgb;
	// Transfer fine generated detail, not its changed river banks or broad colors.
	vec3 broad_art = textureLod(TEXTURE, UV, 2.5).rgb;
	vec3 detailed = clamp(original + clamp(art.rgb-broad_art, vec3(-0.16), vec3(0.16)), vec3(0.0), vec3(1.0));
	float water = water_tone(art.rgb);
	for (int y=-1; y<=1; y++) {
		for (int x=-1; x<=1; x++) {
			water = max(water, water_tone(texture(original_map, uv+vec2(float(x),float(y))*3.0/1254.0).rgb));
		}
	}
	float edge = 1.0;
	if (source_rect.x > 0.0) edge *= smoothstep(0.0, 23.0, native.x-source_rect.x);
	if (source_rect.y > 0.0) edge *= smoothstep(0.0, 23.0, native.y-source_rect.y);
	if (source_rect.x+source_rect.z < 1254.0) edge *= smoothstep(0.0, 23.0, source_rect.x+source_rect.z-native.x);
	if (source_rect.y+source_rect.w < 1254.0) edge *= smoothstep(0.0, 23.0, source_rect.y+source_rect.w-native.y);
	// Keep the existing registered Jeju island detail independent.
	if (native.x >= 470.0 && native.x <= 592.0 && native.y >= 1048.0 && native.y <= 1148.0) edge = 0.0;
	COLOR = vec4(detailed, art.a * detail_weight * edge * (1.0-water));
}
