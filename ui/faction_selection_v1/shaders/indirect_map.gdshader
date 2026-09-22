shader_type canvas_item;
render_mode unshaded;

uniform float map_opacity : hint_range(0.0, 1.0) = 0.82;
uniform float warm_mix : hint_range(0.0, 1.0) = 0.64;

void fragment() {
    vec4 sampled_color = texture(TEXTURE, UV);
    float luminance = dot(sampled_color.rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 ink = vec3(luminance * 1.13, luminance * 1.02, luminance * 0.77);
    float edge = smoothstep(0.0, 0.17, UV.x) * smoothstep(0.0, 0.17, 1.0 - UV.x);
    edge *= smoothstep(0.0, 0.17, UV.y) * smoothstep(0.0, 0.17, 1.0 - UV.y);
    vec2 distance_from_center = (UV - vec2(0.5)) * vec2(1.0, 0.93);
    edge *= 1.0 - smoothstep(0.41, 0.65, length(distance_from_center));
    COLOR = vec4(mix(sampled_color.rgb, ink, warm_mix), sampled_color.a * edge * map_opacity) * COLOR;
}
