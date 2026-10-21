shader_type spatial;
// Inverted hull: back faces pushed out along the normal, drawn in a dark tint of the albedo.
render_mode unshaded, cull_front, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 line_color : source_color = vec4(0.071, 0.055, 0.078, 1.0);
uniform float line_mix = 0.0;                 // pure ink: no albedo tint (a tint reads as a brown halo)
uniform float width = 0.0075;                 // world units
uniform float alpha_cut = 0.5;
uniform bool use_cut = false;
uniform vec3 light_toward = vec3(-0.35, 0.8, 0.5);
uniform float thin = 0.55;                    // width factor on the lit side; the shadow side gets thin + 1
void vertex() {
	vec3 n = normalize(NORMAL);
	float lit = clamp(dot(normalize(MODEL_NORMAL_MATRIX * n), normalize(light_toward)) * 0.5 + 0.5, 0.0, 1.0);
	VERTEX += n * width * (thin + (1.0 - lit));   // thick-and-thin ink: heavier on the shadow side, fine on the lit side
}
void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (use_cut && tex.a * base_color.a < alpha_cut) discard;
	ALBEDO = mix(line_color.rgb, tex.rgb * base_color.rgb * 0.35, line_mix);
}
