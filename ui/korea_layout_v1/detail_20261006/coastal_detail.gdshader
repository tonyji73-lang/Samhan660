shader_type canvas_item;
render_mode unshaded;
uniform vec4 source_rect;
uniform float detail_weight = 0.0;
void fragment() {
	vec2 p = source_rect.xy+UV*source_rect.zw;
	float edge = 1.0;
	// One-sided 25px overlaps: never expose the low-resolution base between tiles.
	if(source_rect.x>0.0) edge *= smoothstep(0.0,25.0,UV.x*350.0);
	if(source_rect.y>0.0) edge *= smoothstep(0.0,25.0,UV.y*350.0);
	// The two absent southeast grid cells contain open sea, not land detail.
	// Feather only these exposed water edges; internal overlaps stay fully covered.
	if(source_rect.x==325.0 && source_rect.y>0.0) edge *= smoothstep(0.0,35.0,(1.0-UV.x)*350.0);
	if(source_rect.x==650.0) edge *= smoothstep(0.0,35.0,(1.0-UV.y)*350.0);
	// Match the outer regional join; adjoining world detail remains underneath.
	edge *= smoothstep(0.0,80.0,p.x)*smoothstep(0.0,80.0,p.y);
	edge *= smoothstep(0.0,120.0,1000.0-p.x)*smoothstep(0.0,100.0,1000.0-p.y);
	vec4 art = texture(TEXTURE,UV);
	// Coast and island detail must remain high resolution, not replaced by base water.
	COLOR = vec4(art.rgb,art.a*edge*detail_weight);
}
