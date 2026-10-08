shader_type canvas_item;
render_mode unshaded;
uniform sampler2D southern_join : source_color, filter_linear_mipmap, repeat_disable;
void fragment() {
	vec2 p = UV * 1000.0;
	float edge = smoothstep(0.0,80.0,p.x)*smoothstep(0.0,80.0,p.y);
	edge *= smoothstep(0.0,120.0,1000.0-p.x)*smoothstep(0.0,100.0,1000.0-p.y);
	vec4 art = mix(texture(TEXTURE,UV),texture(southern_join,UV),smoothstep(0.76,0.80,UV.y));
	COLOR = vec4(art.rgb,art.a*edge);
}
