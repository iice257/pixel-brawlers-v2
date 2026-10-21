class_name AirshipDeck
extends Node3D
## Stage 1 greybox: an airship deck built from primitives, for the fixed side-view fight camera.
## The fight floor is the y = 0 plane across the sim stage (SimConst.STAGE_W px). Everything else is set dressing behind it.
## clamp_camera_x() keeps the camera inside the deck so the sky edge never shows past the hull.
const W := FighterView.WORLD_PER_PX
const HALF_W := SimConst.STAGE_W * 0.5 * W          # half the fightable width, metres
const FOV := 21.0
const ASPECT := 16.0 / 9.0
const EDGE_MARGIN := 0.9                            # how far past the fight limits the camera may look

const WOOD := Color("5a3d33")
const WOOD_DARK := Color("3b2a2c")
const WOOD_LIGHT := Color("7a5444")
const BRASS := Color("b8883a")
const IRON := Color("2c2d3a")
const TEAL := Color("2f5560")
const CANVAS := Color("c9b48a")
const SKY_TOP := Color("1d2748")
const SKY_BOT := Color("e0956a")

var _mats := {}

## Camera x limits for a camera at `dist` metres from the fight plane (visible half-width grows with distance).
static func camera_limit(dist: float) -> float:
	var half_view := dist * tan(deg_to_rad(FOV * 0.5)) * ASPECT
	return maxf(HALF_W + EDGE_MARGIN - half_view, 0.0)

static func clamp_camera_x(x: float, dist: float) -> float:
	var lim := camera_limit(dist)
	return clampf(x, -lim, lim)

func _ready() -> void:
	_build()

func _mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[key] = m
	return _mats[key]

func _box(pos: Vector3, size: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new(); b.size = size
	mi.mesh = b; mi.material_override = _mat(c); mi.position = pos
	add_child(mi)
	return mi

func _cyl(pos: Vector3, r: float, h: float, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new(); m.top_radius = r; m.bottom_radius = r; m.height = h; m.radial_segments = 16
	mi.mesh = m; mi.material_override = _mat(c); mi.position = pos; mi.rotation = rot
	add_child(mi)
	return mi

func _sphere(pos: Vector3, scl: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new(); m.radial_segments = 32; m.rings = 16
	mi.mesh = m; mi.material_override = _mat(c); mi.position = pos; mi.scale = scl
	add_child(mi)
	return mi

func _build() -> void:
	_sky()
	_deck()
	_rail()
	_props()
	_envelope()

## Vertical sky gradient on a big quad behind everything, plus a few flat cloud blobs for parallax-free depth.
func _sky() -> void:
	var sh := Shader.new()
	sh.code = "shader_type spatial; render_mode unshaded; uniform vec4 top: source_color; uniform vec4 bot: source_color;\nvoid fragment() { ALBEDO = mix(bot.rgb, top.rgb, clamp(1.0 - UV.y, 0.0, 1.0)); }"
	var m := ShaderMaterial.new(); m.shader = sh
	m.set_shader_parameter("top", SKY_TOP); m.set_shader_parameter("bot", SKY_BOT)
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new(); qm.size = Vector2(64, 28)
	q.mesh = qm; q.material_override = m; q.position = Vector3(0, 8, -18)
	add_child(q)
	for c in [Vector3(-9, 2.2, -14), Vector3(6, 3.4, -15), Vector3(-2, 5.0, -16), Vector3(14, 1.6, -13)]:
		_sphere(c, Vector3(4.2, 0.9, 0.4), Color("f0b98a").lerp(SKY_BOT, 0.3))

## Plank floor, front lip and under-hull so the deck reads as an object floating in the sky.
func _deck() -> void:
	var span := HALF_W * 2.0 + 8.0
	_box(Vector3(0, -0.15, -0.6), Vector3(span, 0.3, 4.6), WOOD)
	var x := -span * 0.5
	while x < span * 0.5:       # plank seams run front to back
		_box(Vector3(x, 0.005, -0.6), Vector3(0.035, 0.012, 4.6), WOOD_DARK)
		x += 0.55
	for z in [-2.0, -1.3, -0.6, 0.1, 0.8]:   # butt joints, staggered
		_box(Vector3(0, 0.006, z), Vector3(span, 0.01, 0.025), WOOD_DARK)
	_box(Vector3(0, -0.34, 1.75), Vector3(span, 0.4, 0.3), WOOD_LIGHT)   # front lip, catches the eye as the edge of the stage
	_box(Vector3(0, -0.55, 1.78), Vector3(span, 0.06, 0.26), BRASS)      # brass trim under the lip
	_box(Vector3(0, -1.6, -0.6), Vector3(span * 0.8, 2.0, 4.0), WOOD_DARK)   # hull below the deck

## Back rail: posts, a brass top rail and two iron cross-bars.
func _rail() -> void:
	var z := -2.7
	var x := -HALF_W - 3.0
	while x <= HALF_W + 3.0:
		_box(Vector3(x, 0.55, z), Vector3(0.1, 1.1, 0.1), WOOD_LIGHT)
		x += 1.2
	var len := (HALF_W + 3.0) * 2.0
	_box(Vector3(0, 1.12, z), Vector3(len, 0.09, 0.14), BRASS)
	_box(Vector3(0, 0.78, z), Vector3(len, 0.04, 0.05), IRON)
	_box(Vector3(0, 0.4, z), Vector3(len, 0.04, 0.05), IRON)

## Mast with rigging, a boiler stack, crates and a ship's wheel: big readable shapes, nothing in front of the fight plane.
func _props() -> void:
	_cyl(Vector3(-3.4, 2.4, -3.6), 0.2, 4.8, WOOD_LIGHT)                               # mast
	_cyl(Vector3(-3.4, 4.2, -3.6), 0.07, 3.4, WOOD, Vector3(0, 0, PI * 0.5))           # yard arm
	_box(Vector3(-3.4, 3.2, -3.62), Vector3(2.6, 1.3, 0.04), CANVAS)                   # furled sail
	_cyl(Vector3(3.9, 1.4, -3.4), 0.55, 2.8, IRON)                                     # boiler stack
	_cyl(Vector3(3.9, 2.9, -3.4), 0.7, 0.18, BRASS)
	_cyl(Vector3(3.9, 0.9, -3.4), 0.6, 0.12, BRASS)
	for p in [Vector3(1.6, 0.3, -2.2), Vector3(2.15, 0.25, -2.2), Vector3(1.9, 0.78, -2.2)]:
		_box(p, Vector3(0.5, 0.5, 0.5) if p.y < 0.5 else Vector3(0.42, 0.42, 0.42), WOOD)
	_cyl(Vector3(-0.2, 0.75, -2.5), 0.38, 0.08, BRASS, Vector3(PI * 0.5, 0, 0))        # wheel
	_box(Vector3(-0.2, 0.35, -2.5), Vector3(0.12, 0.7, 0.12), WOOD_LIGHT)
	for i in 6:   # rigging lines from the mast head to the rail
		var a := Vector3(-3.4, 4.6, -3.6)
		var b := Vector3(-3.4 + (i - 2.5) * 1.1, 1.1, -2.7)
		_line(a, b, IRON)

func _line(a: Vector3, b: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new(); m.top_radius = 0.012; m.bottom_radius = 0.012; m.height = a.distance_to(b); m.radial_segments = 4
	mi.mesh = m; mi.material_override = _mat(c)
	mi.position = (a + b) * 0.5
	mi.basis = Basis.looking_at(b - a, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	add_child(mi)

## The balloon envelope hangs over the top of frame, with ribs and a gondola link so the scale reads.
func _envelope() -> void:
	_sphere(Vector3(0, 10.5, -6), Vector3(13, 4.2, 3.2), TEAL)
	for i in range(-5, 6):
		_box(Vector3(i * 1.15, 8.1, -4.4), Vector3(0.05, 1.2, 0.05), IRON)
	_box(Vector3(0, 7.4, -4.4), Vector3(12.5, 0.08, 0.08), BRASS)
