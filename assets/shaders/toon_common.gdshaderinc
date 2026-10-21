// Shared toon lighting for fighters. All lighting is computed here (the materials are `unshaded`),
// so the look is deterministic and does not depend on scene lights. Hard bands, rim, screentone in deep shade.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 shade_color : source_color = vec4(0.82, 0.8, 0.95, 1.0);
uniform vec3 light_toward = vec3(-0.35, 0.8, 0.5);   // direction towards the light, world space
uniform float band_lit = 0.6;                         // ndl above this: full colour
uniform float band_deep = -0.2;                       // ndl below this: deep shade + screentone
uniform float deep_mul = 0.45;
uniform vec4 rim_color : source_color = vec4(1.0, 0.93, 0.78, 1.0);
uniform float rim_width = 0.2;                        // 0 disables the rim
uniform float tone_size = 3.0;                        // screentone dot cell, in pixels
uniform float face_flatten = 0.0;                     // 1 for face skin: pushes the normal towards the face direction
uniform vec3 face_forward = vec3(0.0, 0.0, 1.0);      // world-space face direction, set per fighter facing
uniform float alpha_cut = 0.5;
uniform float tint_k = 1.0;                           // 0 for skin and eyes: the per-fighter tint never touches them
instance uniform vec4 tint : source_color = vec4(1.0);   // per-fighter colour shift (hue swap for the second player)
instance uniform float swap = 0.0;                       // 1 rotates the hue (P2 outfit/hair); skin is exempt through tint_k
instance uniform float flash = 0.0;                      // 0..1 white hit flash

varying vec3 v_wn;

vec3 toon_color(vec2 uv, vec3 view_n, vec3 view_dir, vec2 frag, out float alpha) {
	vec4 tex = texture(albedo_tex, uv);
	alpha = tex.a * base_color.a;
	vec3 lit = tex.rgb * base_color.rgb;
	vec3 shd = tex.rgb * shade_color.rgb;
	vec3 n = normalize(mix(v_wn, normalize(face_forward), face_flatten));
	float ndl = dot(n, normalize(light_toward));
	float aa = 0.015;
	float lit_k = smoothstep(band_lit - aa, band_lit + aa, ndl);
	float deep_k = 1.0 - smoothstep(band_deep - aa, band_deep + aa, ndl);
	vec3 col = mix(shd, lit, lit_k);
	col = mix(col, shd * deep_mul, deep_k);
	vec2 cell = fract(frag / tone_size) - 0.5;
	float dots = step(length(cell), 0.32);
	col *= 1.0 - deep_k * dots * 0.22;
	float rim = 1.0 - clamp(dot(normalize(view_n), normalize(view_dir)), 0.0, 1.0);
	float rim_k = step(1.0 - rim_width, rim) * step(0.001, rim_width) * lit_k;   // thin, lit side only: no fringe on the shadow side
	col = mix(col, rim_color.rgb * mix(vec3(1.0), tex.rgb, 0.35), rim_k * 0.9);
	col = mix(col, col.brg, swap * tint_k);
	col *= mix(vec3(1.0), tint.rgb, tint_k);
	col = mix(col, vec3(1.0), flash * 0.75);
	return col;
}
