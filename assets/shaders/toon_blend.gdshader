shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;
#include "res://assets/shaders/toon_common.gdshaderinc"
void vertex() { v_wn = normalize((MODEL_NORMAL_MATRIX * NORMAL)); v_col = COLOR; }
void fragment() {
	float a;
	vec3 view_n = FRONT_FACING ? NORMAL : -NORMAL;
	ALBEDO = toon_color(UV, view_n, VIEW, FRAGCOORD.xy, a);
	ALPHA = a;
}
