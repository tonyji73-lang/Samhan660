shader_type canvas_item;
render_mode unshaded;
// Local display-only inverse UV adjustments. Never used for gameplay positions.
vec2 correction(vec2 uv, vec2 target, vec2 source, vec2 radius) {
	float d = length((uv-target)/radius);
	float w = 1.0-smoothstep(0.0,1.0,d);
	return (source-target)*w;
}
void fragment() {
	vec2 sample_uv = UV;
	sample_uv += correction(UV,vec2(0.490,0.790),vec2(0.498,0.728),vec2(0.065,0.14));
	sample_uv += correction(UV,vec2(0.620,0.550),vec2(0.638,0.569),vec2(0.045,0.065));
	COLOR = texture(TEXTURE,clamp(sample_uv,vec2(0.0),vec2(1.0)));
}
