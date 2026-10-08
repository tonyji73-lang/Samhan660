shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 native = UV * 1254.0;
	float edge = smoothstep(0.0, 24.0, min(min(native.x,native.y),1254.0-native.y));
	// The old sheet's empty eastern sea must not cover the new Japanese islands.
	edge *= 1.0 - smoothstep(1000.0,1080.0,native.x);
	vec4 art = texture(TEXTURE,UV);
	COLOR = vec4(art.rgb,art.a*edge);
}
