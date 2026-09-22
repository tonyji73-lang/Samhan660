shader_type canvas_item;
render_mode blend_mix;

// Only for the east-detail terrain item, above the visible Korean overview.
// Texture: terrain_east_coast_detail_draft_v1_1254.png
// World rectangle: (3584, 2048, 512, 512). UV must cover this entire texture.
// These weights are spatial and deliberately independent of camera zoom.
uniform float edge_width_uv : hint_range(0.01, 0.25, 0.001) = 0.12;
uniform float outer_guard_uv : hint_range(0.001, 0.01, 0.0001) = 0.0078125;
uniform float protection_fade_uv : hint_range(0.001, 0.08, 0.001) = 0.02;

// Conservative sprite-envelope bounds, not territory or ground masks.
// Min x, min y, max x, max y. Derived from the existing 130-world-unit
// fortress reference and (0.5, 0.67) pivot. Do not reuse for other tiles.
uniform vec4 siljik_rect = vec4(0.07685546875, 0.0952734375, 0.32568359375, 0.3187109375);
uniform vec4 geumseong_rect = vec4(0.01685546875, 0.7352734375, 0.26568359375, 0.9587109375);
uniform vec4 ulleung_rect = vec4(0.31685546875, 0.2552734375, 0.56568359375, 0.4787109375);

float protected_region_weight(vec2 point_uv, vec4 bounds) {
	vec2 outside = max(max(bounds.xy - point_uv, point_uv - bounds.zw), vec2(0.0));
	return 1.0 - smoothstep(0.0, max(protection_fade_uv, 0.000001), length(outside));
}

void fragment() {
	float edge_distance = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float border_weight = smoothstep(0.0, max(edge_width_uv, 0.000001), edge_distance);
	float protected_weight = max(
		max(protected_region_weight(UV, siljik_rect), protected_region_weight(UV, geumseong_rect)),
		protected_region_weight(UV, ulleung_rect)
	);
	float border_guard = smoothstep(0.0, max(outer_guard_uv, 0.000001), edge_distance);
	float detail_weight = max(border_weight, protected_weight) * border_guard;
	// Fragment COLOR already includes the default texture and modulation.
	// Keep its RGB and existing alpha; do not sample and multiply TEXTURE twice.
	COLOR.a *= detail_weight;
}
