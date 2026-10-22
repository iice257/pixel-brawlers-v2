// Shared toon lighting for fighters. All lighting is computed here (the materials are `unshaded`),
// so the look is deterministic and does not depend on scene lights. Cel look: ONE hard shadow tone, a thin lit-side rim, no screentone.
// The light rides with the fighter: `facing` mirrors its x, so each fighter is lit from the same side of their own body.
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 shade_color : source_color = vec4(0.82, 0.8, 0.95, 1.0);
uniform vec3 light_toward = vec3(0.45, 0.8, 0.65);    // direction towards the light, in the fighter's frame (x = their front)
uniform float band_lit = 0.35;                        // ndl above this: full colour, below: the one shadow tone
uniform vec4 rim_color : source_color = vec4(1.0, 0.93, 0.78, 1.0);
uniform float rim_width = 0.26;                        // 0 disables the rim
uniform float face_flatten = 0.0;                     // 1 for face skin: pushes the normal towards the face direction
uniform vec3 face_forward = vec3(0.0, 0.0, 1.0);      // world-space face direction, set per fighter facing
uniform float alpha_cut = 0.5;
uniform float tint_k = 1.0;                           // 0 for skin and eyes: the per-fighter tint never touches them
instance uniform vec4 tint : source_color = vec4(1.0);   // per-fighter colour shift (hue swap for the second player)
instance uniform float swap = 0.0;                       // 1 rotates the hue (P2 outfit/hair); skin is exempt through tint_k
instance uniform vec4 rim_override : source_color = vec4(0.0);   // a > 0: this fighter's rim colour (teal P1, amber P2)
instance uniform float facing = 1.0;                     // +1 / -1: which way the fighter faces, mirrors the light
instance uniform float flash = 0.0;                      // 0..1 white hit flash

varying vec3 v_wn;
varying vec4 v_col;   // vertex colour tints the albedo (merged props carry their colours here; model meshes are white)

vec3 toon_color(vec2 uv, vec3 view_n, vec3 view_dir, vec2 frag, out float alpha) {
	vec4 tex = texture(albedo_tex, uv);
	alpha = tex.a * base_color.a;
	vec3 lit = tex.rgb * v_col.rgb * base_color.rgb;
	vec3 shd = tex.rgb * v_col.rgb * shade_color.rgb * 0.88;
	vec3 n = normalize(mix(v_wn, normalize(face_forward), face_flatten));
	vec3 ld = normalize(vec3(light_toward.x * facing, light_toward.y, light_toward.z));
	float ndl = dot(n, ld);
	float aa = 0.012;
	float lit_k = smoothstep(band_lit - aa, band_lit + aa, ndl);
	vec3 col = mix(shd, lit, lit_k);
	float rim = 1.0 - clamp(dot(normalize(view_n), normalize(view_dir)), 0.0, 1.0);
	float rim_k = step(1.0 - rim_width, rim) * step(0.001, rim_width) * lit_k;   // thin, lit side only: no fringe on the shadow side
	vec3 rc = mix(rim_color.rgb, rim_override.rgb, rim_override.a);
	col = mix(col, rc * mix(vec3(1.0), tex.rgb, 0.25), rim_k);
	col = mix(col, col.brg, swap * tint_k);
	col *= mix(vec3(1.0), tint.rgb, tint_k);
	col = mix(col, vec3(1.0), flash * 0.75);
	return col;
}
