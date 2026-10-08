shader_type canvas_item;
render_mode unshaded;
uniform sampler2D base_map : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 source_rect;
uniform float detail_weight = 0.0;
float water(vec3 c) {
	return smoothstep(0.015,0.08,min(c.b-c.r,c.g-c.r));
}
void fragment() {
	vec2 base_uv = (source_rect.xy+UV*source_rect.zw)/1000.0;
	vec3 original = texture(base_map,base_uv).rgb;
	vec3 fine = texture(TEXTURE,UV).rgb;
	vec3 broad = textureLod(TEXTURE,UV,2.2).rgb;
	vec3 tone = textureLod(base_map,base_uv,0.7).rgb;
	float shore_guard = water(original);
	for(int y=-1;y<=1;y++) {
		for(int x=-1;x<=1;x++) {
			shore_guard = max(shore_guard,water(texture(base_map,base_uv+vec2(float(x),float(y))/1254.0).rgb));
		}
	}
	shore_guard = max(shore_guard,water(fine));
	vec3 color = mix(original,clamp(fine+tone-broad,vec3(0.0),vec3(1.0)),1.0-shore_guard);
	vec2 edge_distance = min(UV,1.0-UV)*350.0;
	float edge = smoothstep(0.0,25.0,min(edge_distance.x,edge_distance.y));
	// Southern connection was repainted; do not reintroduce the old coast there.
	edge *= 1.0-smoothstep(740.0,780.0,base_uv.y*1000.0);
	COLOR = vec4(color,edge*detail_weight);
}
