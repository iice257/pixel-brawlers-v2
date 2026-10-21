shader_type spatial;
// Inverted hull: back faces pushed out along the normal, drawn in a dark tint of the albedo.
render_mode unshaded, cull_front, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 line_color : source_color = vec4(0.09, 0.04, 0.07, 1.0);
uniform float line_mix = 0.25;                // how much of the albedo tints the line
uniform float width = 0.0075;                 // world units
uniform float alpha_cut = 0.5;
uniform bool use_cut = false;
void vertex() {
	vec3 n = normalize(NORMAL);
	VERTEX += n * width;
}
void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (use_cut && tex.a * base_color.a < alpha_cut) discard;
	ALBEDO = mix(line_color.rgb, tex.rgb * base_color.rgb * 0.35, line_mix);
}
