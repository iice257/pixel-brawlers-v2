shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
#include "res://assets/shaders/toon_common.gdshaderinc"
void vertex() { v_wn = normalize((MODEL_NORMAL_MATRIX * NORMAL)); }
void fragment() {
	float a;
	ALBEDO = toon_color(UV, NORMAL, VIEW, FRAGCOORD.xy, a);
}
