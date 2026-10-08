shader_type canvas_item;
render_mode unshaded;
uniform vec2 fade_native;
uniform float detail_weight = 1.0;
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float edge = 1.0;
	if (fade_native.x > 0.0) edge *= smoothstep(0.0, fade_native.x, UV.x * 350.0);
	if (fade_native.y > 0.0) edge *= smoothstep(0.0, fade_native.y, UV.y * 350.0);
	COLOR = vec4(art.rgb, art.a * edge * detail_weight);
}
