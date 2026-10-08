shader_type canvas_item;
render_mode unshaded;
#include "res://ui/korea_layout_v1/unified_world_20261002/play_atlas_coverage.gdshaderinc"
uniform sampler2D original_map : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 source_rect;
uniform float detail_weight = 0.0;
uniform float detail_radius = 2.5;
uniform bool fine_art = false;

// Reconstruct the PLAY atlas at native coordinates, including shores and rivers.
// Catmull-Rom keeps texel centres and uses modest contrast reconstruction.
vec4 cubic_weights(float f) {
	float f2 = f*f;
	float f3 = f2*f;
	return vec4(-0.5*f + f2 - 0.5*f3, 1.0 - 2.5*f2 + 1.5*f3,
		0.5*f + 2.0*f2 - 1.5*f3, -0.5*f2 + 0.5*f3);
}
vec3 reconstruct(vec2 uv) {
	vec2 p = uv * 1254.0 - 0.5;
	vec2 base = floor(p);
	vec4 wx = cubic_weights(fract(p.x));
	vec4 wy = cubic_weights(fract(p.y));
	vec3 value = vec3(0.0);
	for (int y=0; y<4; y++) {
		for (int x=0; x<4; x++) {
			vec3 sample_value = texture(original_map, (base + vec2(float(x-1),float(y-1)) + 0.5)/1254.0).rgb;
			value += sample_value * wx[x] * wy[y];
		}
	}
	vec3 centre = texture(original_map, uv).rgb;
	vec3 cross_mean = (texture(original_map,uv+vec2(1.0,0.0)/1254.0).rgb
		+ texture(original_map,uv-vec2(1.0,0.0)/1254.0).rgb
		+ texture(original_map,uv+vec2(0.0,1.0)/1254.0).rgb
		+ texture(original_map,uv-vec2(0.0,1.0)/1254.0).rgb)*0.25;
	return clamp(value + (centre-cross_mean)*0.2,vec3(0.0),vec3(1.0));
}

// Conservative visual guard, not a gameplay land/river mask.
float water_tone(vec3 c) {
	return smoothstep(0.015, 0.08, min(c.b-c.r, c.g-c.r)) * smoothstep(-0.055, -0.005, c.b-c.g);
}
void fragment() {
	vec2 native = source_rect.xy + UV * source_rect.zw;
	vec2 uv = native / 1254.0;
	vec4 art = texture(TEXTURE, UV);
	vec3 original = reconstruct(uv);
	// Transfer fine generated detail, not its changed river banks or broad colors.
	vec3 broad_art = textureLod(TEXTURE, UV, detail_radius).rgb;
	float water = water_tone(textureLod(TEXTURE,UV,2.0).rgb);
	for (int y=-1; y<=1; y++) {
		for (int x=-1; x<=1; x++) {
			// Overlapping footprints avoid disjoint stripes beside narrow rivers.
			water = max(water, water_tone(textureLod(original_map, uv+vec2(float(x),float(y))/1254.0,1.0).rgb));
			water = max(water, water_tone(textureLod(TEXTURE, UV+vec2(float(x),float(y))/source_rect.zw,2.0).rgb));
		}
	}
	vec3 detailed = clamp(original + clamp((art.rgb-broad_art)*0.8, vec3(-0.10), vec3(0.10))*(1.0-water), vec3(0.0), vec3(1.0));
	if (fine_art) {
		// Match low-frequency light/color to the play atlas, replace the blurry
		// inland texture with the smaller high-resolution crop's actual detail.
		float ratio = float(textureSize(TEXTURE,0).x) / source_rect.z;
		vec3 base_color = textureLod(original_map,uv,max(0.0,detail_radius-log2(ratio))).rgb;
		vec3 fine_color = clamp(art.rgb + base_color-broad_art,vec3(0.0),vec3(1.0));
		detailed = mix(original,fine_color,1.0-water);
	}
	float edge = 1.0;
	if (source_rect.x > 0.0) edge *= smoothstep(0.0, 23.0, native.x-source_rect.x);
	if (source_rect.y > 0.0) edge *= smoothstep(0.0, 23.0, native.y-source_rect.y);
	if (source_rect.x+source_rect.z < 1254.0) edge *= smoothstep(0.0, 23.0, source_rect.x+source_rect.z-native.x);
	if (source_rect.y+source_rect.w < 1254.0) edge *= smoothstep(0.0, 23.0, source_rect.y+source_rect.w-native.y);
	// Keep the existing registered Jeju island detail independent.
	if (native.x >= 470.0 && native.x <= 592.0 && native.y >= 1048.0 && native.y <= 1148.0) edge = 0.0;
	// Water rejects generated terrain, but still receives original-only reconstruction.
	edge *= play_atlas_coverage(native);
	COLOR = vec4(detailed, art.a * detail_weight * edge);
}
