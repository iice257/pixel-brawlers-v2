class_name FxSheet
extends Sprite3D
## One-shot sprite-sheet effect from data/fx.json: plays the frames once, then frees itself. `exists(id)` is false until the pack's png is dropped in.

const PATH := "res://data/fx.json"
static var _doc := {}

static func doc() -> Dictionary:
	if _doc.is_empty(): _doc = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _doc

static func exists(id: String) -> bool:
	return doc().has(id) and ResourceLoader.exists(String(doc()[id].sheet))

var _fps := 30.0
var _n := 1
var _t := 0.0

## Builds the effect for `id` at `pos`; `scale_k` scales the entry's own size; `flip` mirrors it for a fighter facing left.
static func make(id: String, pos: Vector3, flip: bool, scale_k := 1.0, tint := Color.WHITE) -> FxSheet:
	var e: Dictionary = doc()[id]
	var s := FxSheet.new()
	s.texture = load(String(e.sheet))
	s.hframes = int(e.frames[0]); s.vframes = int(e.frames[1])
	s._n = s.hframes * s.vframes; s._fps = float(e.fps)
	s.pixel_size = float(e.size) * scale_k / (s.texture.get_width() / float(s.hframes))
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false; s.no_depth_test = true; s.transparent = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	s.modulate = tint
	s.flip_h = flip
	if e.get("additive", true): s.material_override = _additive()
	s.position = pos
	return s

static func _additive() -> Material:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = true
	m.vertex_color_use_as_albedo = true
	return m

func _process(dt: float) -> void:
	_t += dt
	var i := int(_t * _fps)
	if i >= _n: queue_free(); return
	frame = i
