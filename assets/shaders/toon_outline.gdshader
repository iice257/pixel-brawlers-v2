shader_type spatial;
// Inverted hull: back faces pushed out along the normal, drawn in a dark tint of the albedo.
render_mode unshaded, cull_front, depth_draw_opaque;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 line_color : source_color = vec4(0.071, 0.055, 0.078, 1.0);
uniform float line_mix = 0.0;                 // pure ink: no albedo tint (a tint reads as a brown halo)
uniform float width = 0.0075;                 // line weight; drawn as a constant screen width (width * 187 px at 720p), scaling with the render height
uniform float alpha_cut = 0.5;
uniform bool use_cut = false;
uniform vec3 light_toward = vec3(-0.35, 0.8, 0.5);
uniform float thin = 0.55;                    // width factor on the lit side; the shadow side gets thin + 1
void vertex() {
	vec3 n = normalize(NORMAL);
	float lit = clamp(dot(normalize(MODEL_NORMAL_MATRIX * n), normalize(light_toward)) * 0.5 + 0.5, 0.0, 1.0);
	// Constant screen-space width: push the clip-space position sideways along the projected normal, so the line neither
	// swells with distance nor shimmers as the camera moves.
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 vn = normalize((MODELVIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec2 dir = (PROJECTION_MATRIX * vec4(vn, 0.0)).xy;
	dir = length(dir) > 0.0001 ? normalize(dir) : vec2(0.0);
	float px = width * 187.0 * (thin + (1.0 - lit)) * (VIEWPORT_SIZE.y / 720.0);   // thick-and-thin ink: heavier on the shadow side
	POSITION = clip;
	POSITION.xy += dir * vec2(VIEWPORT_SIZE.y / VIEWPORT_SIZE.x, 1.0) * (px * 2.0 / VIEWPORT_SIZE.y) * clip.w;
}
void fragment() {
	vec4 tex = texture(albedo_tex, UV);
	if (use_cut && tex.a * base_color.a < alpha_cut) discard;
	ALBEDO = mix(line_color.rgb, tex.rgb * base_color.rgb * 0.35, line_mix);
}
