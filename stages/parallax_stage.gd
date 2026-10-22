class_name ParallaxStage
extends Node
## 2D painted stage: sky (far, drifts slowly), deck (rides the fight plane, so its floor line sits under the fighters' feet),
## front (passes in front of the fight, faster than the camera) and a haze tint. Layer art is looked up by name in the stage's
## art_dir (sky.png, deck.png, front.png: tools/import_stage_art.py writes them); a missing file falls back to a drawn placeholder.
## Layout comes from data/stages/<id>.json. `floor_y` is where the deck image's floor line sits, as a fraction of its height.
## Needs Environment.background_mode = BG_CANVAS with background_canvas_max_layer = -1 so layers below 0 draw behind the 3D fighters.

const W := FighterView.WORLD_PER_PX
const HALF_W := SimConst.STAGE_W * 0.5 * W
const EDGE := AirshipDeck.EDGE_MARGIN
const PLACEHOLDER_PPM := 100.0       # the placeholder deck is drawn at 100 px per metre

var cfg := {}
var layers := {}                     # name -> Node2D
var haze_mat: ShaderMaterial
var sky_mat: ShaderMaterial
var _ppm := {}                       # layer name -> image pixels per metre
var _size := {}                      # layer name -> image size in px

static func config(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/stages/%s.json" % id))

func setup(env: Environment, id := "stage1") -> void:
	cfg = config(id)
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = -1
	var span_m := 2.0 * (HALF_W + EDGE)
	for l in cfg.layers:
		var cl := CanvasLayer.new()
		cl.layer = {"far": -10, "plane": -6, "front": 0}[l.kind]
		add_child(cl)
		var node: Node2D
		var path: String = String(cfg.art_dir) + String(l.name) + ".png"
		if ResourceLoader.exists(path):
			var sp := Sprite2D.new(); sp.texture = load(path)
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			node = sp
			_size[l.name] = sp.texture.get_size()
			_ppm[l.name] = sp.texture.get_size().x / span_m
		else:
			node = _placeholder(l)
			_ppm[l.name] = PLACEHOLDER_PPM
		cl.add_child(node)
		layers[l.name] = node
	var hl := CanvasLayer.new(); hl.layer = -4; add_child(hl)     # haze: over the deck, behind the fighters
	var rect := ColorRect.new(); rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	haze_mat = ShaderMaterial.new(); haze_mat.shader = _haze_shader()
	haze_mat.set_shader_parameter("tint", Color(cfg.haze.color)); haze_mat.set_shader_parameter("amount", float(cfg.haze.alpha))
	rect.material = haze_mat
	hl.add_child(rect)

## Moves every layer for the current camera. Call after the camera has been placed for the frame.
func update(cam: Camera3D) -> void:
	var vp := cam.get_viewport().get_visible_rect().size
	var o := cam.unproject_position(Vector3.ZERO)
	var ppm := absf(cam.unproject_position(Vector3.RIGHT).x - o.x)
	var floor_y := o.y
	var cx := cam.position.x
	var fy := float(cfg.floor_y)
	for l in cfg.layers:
		var n: Node2D = layers[l.name]
		var s := float(l.scroll)
		var is_img := n is Sprite2D
		match l.kind:
			"far":
				var lim := maxf(AirshipDeck.camera_limit(cam.position.z), 0.001)
				var nx := clampf(cx / lim, -1.0, 1.0)
				var sc := 1.0
				var wpx := vp.x * 1.2
				if is_img:
					var ts: Vector2 = _size[l.name]
					sc = maxf(vp.x * 1.2 / ts.x, vp.y * 1.1 / ts.y)
					wpx = ts.x * sc
				n.scale = Vector2(sc, sc)
				n.position = vp * 0.5 + Vector2(-nx * (wpx - vp.x) * 0.5 * clampf(s * 10.0, 0.0, 1.0), 0.0)
				if sky_mat: sky_mat.set_shader_parameter("cam", cx * 0.12)
			"plane":
				var k := ppm / float(_ppm[l.name])
				n.scale = Vector2(k, k)
				var local_floor := 0.0
				if is_img: local_floor = _size[l.name].y * (fy - 0.5)
				n.position = Vector2(vp.x * 0.5 - cx * ppm, floor_y - local_floor * k)
			"front":
				var k2 := ppm * s / float(_ppm[l.name])
				n.scale = Vector2(k2, k2)
				var local_floor2 := 0.0
				if is_img: local_floor2 = _size[l.name].y * (fy - 0.5)
				n.position = Vector2(vp.x * 0.5 - cx * ppm * s, floor_y - local_floor2 * k2)
	haze_mat.set_shader_parameter("floor_uv", floor_y / vp.y)

func _haze_shader() -> Shader:
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform vec4 tint : source_color = vec4(0.94, 0.72, 0.54, 1.0);\nuniform float amount = 0.16;\nuniform float floor_uv = 0.8;\nvoid fragment() {\n\tfloat d = (UV.y - floor_uv + 0.12) / 0.3;\n\tCOLOR = vec4(tint.rgb, amount * exp(-d * d));\n}"
	return sh

func _placeholder(l: Dictionary) -> Node2D:
	match l.kind:
		"far":
			var holder := Node2D.new()
			var r := ColorRect.new(); r.size = Vector2(1536, 828); r.position = -r.size * 0.5
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sky_mat = ShaderMaterial.new(); sky_mat.shader = _sky_shader()
			r.material = sky_mat
			holder.add_child(r)
			return holder
		"plane":
			var d := DeckDraw.new(); d.half_w = (HALF_W + EDGE) * PLACEHOLDER_PPM
			return d
		_:
			var f := FrontDraw.new(); f.half_w = (HALF_W + EDGE) * PLACEHOLDER_PPM
			return f

func _sky_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 top : source_color = vec4(0.17, 0.2, 0.4, 1.0);
uniform vec4 mid : source_color = vec4(0.55, 0.36, 0.5, 1.0);
uniform vec4 bot : source_color = vec4(0.94, 0.62, 0.38, 1.0);
uniform float cam = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float a = 0.5, s = 0.0; for (int i = 0; i < 4; i++) { s += a * noise(p); p *= 2.03; a *= 0.5; } return s; }
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(top.rgb, mid.rgb, smoothstep(0.0, 0.55, uv.y));
	col = mix(col, bot.rgb, smoothstep(0.45, 1.0, uv.y));
	for (int i = 0; i < 2; i++) {
		float sp = i == 0 ? 0.004 : 0.011;
		float y = i == 0 ? 0.52 : 0.72;
		vec2 p = vec2(uv.x * (i == 0 ? 2.4 : 3.4) + TIME * sp + cam * (i == 0 ? 0.3 : 0.6), uv.y * 6.0);
		float c = fbm(p) - abs(uv.y - y) * 1.6;
		float lit = step(0.28, c);
		float shade = step(0.28, c - 0.08 + 0.1 * uv.y);
		vec3 cloud = mix(vec3(0.99, 0.82, 0.62), vec3(0.62, 0.42, 0.55), 1.0 - shade);
		col = mix(col, cloud, lit * (i == 0 ? 0.55 : 0.8));
	}
	COLOR = vec4(col, 1.0);
}"""
	return sh

## Placeholder deck, drawn at 100 px per metre, origin at world x = 0 on the floor line (y = 0, up is negative).
class DeckDraw extends Node2D:
	var half_w := 700.0
	const INK := Color("0a0614")
	func _box(r: Rect2, c: Color, w := 3.0) -> void:
		draw_rect(r, c); draw_rect(r, INK, false, w)
	func _draw() -> void:
		_box(Rect2(-half_w, 0, half_w * 2, 420), Color("5a3d33"), 4.0)
		var x := -half_w + 40.0
		while x < half_w:
			draw_line(Vector2(x, 6), Vector2(x, 420), Color("3b2a2c"), 3.0); x += 140.0
		draw_rect(Rect2(-half_w, 0, half_w * 2, 14), Color("7a5444")); draw_line(Vector2(-half_w, 14), Vector2(half_w, 14), INK, 3.0)
		_box(Rect2(-half_w, 170, half_w * 2, 18), Color("b8883a"), 3.0)
		var px := -half_w + 30.0
		while px < half_w:
			_box(Rect2(px, -130, 14, 130), Color("7a5444"), 2.0); px += 120.0
		_box(Rect2(-half_w, -134, half_w * 2, 12), Color("b8883a"), 3.0)
		_box(Rect2(-half_w, -86, half_w * 2, 6), Color("2c2d3a"), 2.0)
		_box(Rect2(-half_w, -42, half_w * 2, 6), Color("2c2d3a"), 2.0)
		_box(Rect2(-380, -520, 34, 520), Color("7a5444"), 3.0)
		_box(Rect2(-520, -440, 310, 150), Color("c9b48a"), 3.0)
		for i in 6: draw_line(Vector2(-363, -510), Vector2(-363 + (i - 2.5) * 130.0, -130), Color("2c2d3a"), 2.0)
		_box(Rect2(340, -330, 150, 330), Color("2c2d3a"), 4.0)
		_box(Rect2(325, -340, 180, 22), Color("b8883a"), 3.0)
		_box(Rect2(325, -120, 180, 16), Color("b8883a"), 3.0)
		draw_circle(Vector2(415, -230), 42.0, Color("efe6d2")); draw_arc(Vector2(415, -230), 42.0, 0, TAU, 32, INK, 4.0)
		draw_arc(Vector2(415, -230), 32.0, -0.4, 0.9, 12, Color("e3262f"), 8.0)
		draw_line(Vector2(415, -230), Vector2(441, -246), Color("e3262f"), 4.0)
		_box(Rect2(130, -70, 70, 70), Color("5a3d33"), 3.0); _box(Rect2(205, -58, 58, 58), Color("5a3d33"), 3.0); _box(Rect2(150, -135, 56, 56), Color("7a5444"), 3.0)
		draw_circle(Vector2(-60, -90), 44.0, Color("b8883a")); draw_arc(Vector2(-60, -90), 44.0, 0, TAU, 28, INK, 4.0)
		_box(Rect2(-66, -90, 12, 90), Color("7a5444"), 3.0)

## Placeholder foreground: dark railing posts in the lower corners and hanging rope top-left, drawn at 100 px per metre.
class FrontDraw extends Node2D:
	var half_w := 700.0
	const SOOT := Color("0a0814")
	func _draw() -> void:
		for sx in [-1.0, 1.0]:
			var x: float = sx * (half_w - 30.0)
			draw_rect(Rect2(x - 28, -240, 56, 700), SOOT)
			draw_rect(Rect2(x - 34, -262, 68, 26), Color("b8883a").darkened(0.5))
		for i in 3: draw_line(Vector2(-half_w + 90 + i * 26, -900), Vector2(-half_w + 100 + i * 26, -420 - i * 40), SOOT, 5.0)
