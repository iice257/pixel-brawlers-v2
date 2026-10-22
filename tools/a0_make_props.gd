extends SceneTree
## Kitbashes the first steampunk dressing pass (goggles, gauntlet, pauldron, belt with gear) from primitive meshes and
## saves each as a plain scene in fighters/shared/props/. Placeholder art: replace with Blender or CC0 props later.
## Props are authored in bone-local space of the T-pose humanoid (character faces +Z, its left is +X), attached by
## humanoid bone name from look.json "accessories".
## Run: godot --headless --path . --script res://tools/a0_make_props.gd

const OUT := "res://fighters/shared/props/"
const BRASS := Color(0.86, 0.6, 0.24)
const LEATHER := Color(0.3, 0.17, 0.12)
const GLASS := Color(0.3, 0.85, 0.85)
const DARK := Color(0.16, 0.14, 0.17)
const STEEL := Color(0.5, 0.52, 0.58)
const COAT := Color(0.12, 0.5, 0.5)
const COAT_TRIM := Color(0.07, 0.2, 0.24)
const VENT_RED := Color(2.4, 0.03, 0.02)        # HDR: reads as a glowing vent
const VENT_TEAL := Color(0.3, 2.6, 2.3)
const STACHE := Color(0.2, 0.1, 0.06)
const APRON := Color(0.2, 0.11, 0.08)

func _mat(c: Color, width := 0.012) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://assets/shaders/toon.gdshader")
	m.set_shader_parameter("albedo_tex", load("res://assets/shaders/white.png"))
	m.set_shader_parameter("base_color", c)
	m.set_shader_parameter("shade_color", Color(c.r * 0.45, c.g * 0.4, c.b * 0.55))
	m.set_shader_parameter("tint_k", 0.0)
	var o := ShaderMaterial.new()
	o.shader = load("res://assets/shaders/toon_outline.gdshader")
	o.set_shader_parameter("albedo_tex", load("res://assets/shaders/white.png"))
	o.set_shader_parameter("base_color", c)
	o.set_shader_parameter("width", width)
	m.next_pass = o
	return m

func _add(parent: Node3D, mesh: Mesh, c: Color, pos := Vector3.ZERO, rot := Vector3.ZERO, scale := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scale
	parent.add_child(mi)

func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new(); t.inner_radius = inner; t.outer_radius = outer; t.rings = 20; t.ring_segments = 8
	return t

func _sphere(r: float, segs := 14) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2.0; m.radial_segments = segs; m.rings = segs / 2
	return m

func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new(); m.radius = r; m.height = h; m.radial_segments = 16; m.rings = 6
	return m

func _cyl(r: float, h: float, segs := 16) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = segs; c.rings = 1
	return c

## A box with a different width at the top and bottom, and a bottom that sits `flare` further along +Z than the top (coat tails, aprons).
## Hung from y = +h/2 (top) to y = -h/2 (bottom); built as flat-shaded quads wound the way Godot expects (front faces clockwise).
func _panel(wt: float, wb: float, h: float, t: float, flare := 0.0) -> ArrayMesh:
	var c: Array = []
	for yy in [h / 2.0, -h / 2.0]:
		var w: float = wt if yy > 0.0 else wb
		var z0: float = 0.0 if yy > 0.0 else flare
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]: c.append(Vector3(sx * w / 2.0, yy, sz * t / 2.0 + z0))
	# corner index = yi * 4 + xi * 2 + zi ; faces as [a, b, c, d]
	var faces := [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
	var centre := Vector3(0, 0, flare / 2.0)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f in faces:
		var a: Vector3 = c[f[0]]; var b: Vector3 = c[f[1]]; var cc: Vector3 = c[f[2]]; var d: Vector3 = c[f[3]]
		var mid := (a + b + cc + d) / 4.0
		var n := (b - a).cross(cc - a).normalized()
		var order := [a, b, cc, a, cc, d]
		if n.dot(mid - centre) > 0.0:                 # Godot front faces are clockwise: flip so the winding faces outwards
			order = [a, cc, b, a, d, cc]; n = -n
		for v in order:
			st.set_normal(n); st.set_uv(Vector2(0.5, 0.5)); st.add_vertex(v)
	return st.commit()

func _gear(parent: Node3D, pos: Vector3, rot: Vector3, r: float, thick: float, teeth: int) -> void:
	var g := Node3D.new(); g.position = pos; g.rotation_degrees = rot
	parent.add_child(g)
	_add(g, _cyl(r, thick, 20), BRASS)
	_add(g, _cyl(r * 0.35, thick * 1.6, 12), DARK)
	for i in teeth:
		var a := TAU * i / teeth
		var b := BoxMesh.new(); b.size = Vector3(r * 0.38, thick, r * 0.34)
		_add(g, b, BRASS, Vector3(cos(a), 0, sin(a)) * r * 1.02, Vector3(0, -rad_to_deg(a), 0))

## Collapses a prop's many primitive meshes into one mesh with vertex colours: one surface plus one outline pass is 2 draw calls per prop.
func _merge(root: Node3D) -> Node3D:
	var verts := PackedVector3Array(); var norms := PackedVector3Array(); var cols := PackedColorArray(); var uvs := PackedVector2Array(); var idx := PackedInt32Array()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != root:
			xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var c: Color = (mi.material_override as ShaderMaterial).get_shader_parameter("base_color")
		var a := (mi.mesh as Mesh).surface_get_arrays(0)
		var off := verts.size()
		for v in a[Mesh.ARRAY_VERTEX]: verts.append(xf * v); cols.append(c)
		for nn in a[Mesh.ARRAY_NORMAL]: norms.append((xf.basis * nn).normalized())
		uvs.append_array(PackedVector2Array(a[Mesh.ARRAY_TEX_UV]) if a[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array())
		if a[Mesh.ARRAY_INDEX] != null:
			for i in a[Mesh.ARRAY_INDEX]: idx.append(off + i)
		else:                                           # SurfaceTool meshes are not indexed
			for i in (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(): idx.append(off + i)
	var arrays := []; arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts; arrays[Mesh.ARRAY_NORMAL] = norms; arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs; arrays[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var out := Node3D.new(); out.name = root.name
	var mi2 := MeshInstance3D.new(); mi2.mesh = am; mi2.name = "Mesh"
	mi2.material_override = _mat(Color.WHITE)
	out.add_child(mi2)
	return out

func _save(root_in: Node3D, name: String) -> void:
	var root := _merge(root_in)
	_own(root, root)
	var ps := PackedScene.new(); ps.pack(root)
	DirAccess.make_dir_recursive_absolute(OUT)
	print("saved ", name, " err=", ResourceSaver.save(ps, OUT + name + ".tscn"))

func _own(n: Node, r: Node) -> void:
	for c in n.get_children():
		c.owner = r
		_own(c, r)

func _init() -> void:
	# goggles: pushed up on the forehead; strap round the head, two brass-rimmed lenses
	var gg := Node3D.new(); gg.name = "Goggles"
	for sx in [-0.05, 0.05]:
		_add(gg, _cyl(0.05, 0.05), BRASS, Vector3(sx, 0, 0.0), Vector3(90, 0, 0))               # chunky lens housing: reads in side silhouette
		_add(gg, _cyl(0.037, 0.012), GLASS, Vector3(sx, 0, 0.027), Vector3(90, 0, 0))
	_add(gg, _torus(0.084, 0.104), LEATHER, Vector3(0, 0, -0.085), Vector3(0, 0, 0), Vector3(1.0, 1.0, 1.0))
	_save(gg, "goggles")
	# gauntlet: brass cuff with a dark band and a small gear, forearm axis = +X (mirrored for the other side by scale.x = -1)
	var ga := Node3D.new(); ga.name = "Gauntlet"
	_add(ga, _cyl(0.052, 0.14), BRASS, Vector3(0.0, 0, 0), Vector3(0, 0, 90))
	_add(ga, _cyl(0.056, 0.03), DARK, Vector3(-0.07, 0, 0), Vector3(0, 0, 90))
	_add(ga, _torus(0.05, 0.064), LEATHER, Vector3(0.07, 0, 0), Vector3(0, 0, 90))
	_gear(ga, Vector3(0.0, 0.0, 0.058), Vector3(90, 0, 0), 0.028, 0.016, 8)
	_save(ga, "gauntlet")
	# pauldron: a half-sphere shoulder plate with a rim
	var pa := Node3D.new(); pa.name = "Pauldron"
	var sp := SphereMesh.new(); sp.radius = 0.075; sp.height = 0.15; sp.radial_segments = 16; sp.rings = 8
	_add(pa, sp, BRASS, Vector3(0, 0.0, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
	_add(pa, _torus(0.07, 0.085), DARK, Vector3(0, -0.02, 0))
	_save(pa, "pauldron")
	# belt: leather ring with a front buckle gear and a side pouch
	var be := Node3D.new(); be.name = "Belt"
	_add(be, _torus(0.145, 0.17), LEATHER, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.0, 0.85))
	_gear(be, Vector3(0.0, 0.0, 0.147), Vector3(90, 0, 0), 0.045, 0.02, 10)
	var pouch := BoxMesh.new(); pouch.size = Vector3(0.05, 0.06, 0.04)
	_add(be, pouch, LEATHER, Vector3(0.16, -0.01, 0.02))
	_save(be, "belt")
	_new_props()
	quit()

## Signature placeholder silhouettes (accessory slot): BRIGGS' hydraulic fist, apron, boots, moustache; KESTREL's coat tails and piston gauntlets.
func _new_props() -> void:
	# vertex colours are read as linear: convert the authored (sRGB-looking) colours so dark leather stays dark
	var L_DARK := Color(0.16, 0.14, 0.17).srgb_to_linear()
	var L_LEATHER := Color(0.42, 0.25, 0.16).srgb_to_linear()
	var L_STACHE := Color(0.24, 0.13, 0.08).srgb_to_linear()
	var L_APRON := Color(0.5, 0.3, 0.16).srgb_to_linear()
	var L_COAT := Color(0.17, 0.78, 0.72).srgb_to_linear()
	var L_COAT_TRIM := Color(0.06, 0.22, 0.28).srgb_to_linear()
	# big gauntlet: forearm axis +X (mirrored with scale.x = -1 for the right arm); about 1.6x the standard gauntlet: a rounded shell, a round fist,
	# piston rods on top, rivets, and glowing red vent rings that wrap the shell so the glow reads from either side of the camera
	var bg := Node3D.new(); bg.name = "BigGauntlet"
	_add(bg, _capsule(0.094, 0.3), BRASS, Vector3(0.12, 0, 0), Vector3(0, 0, 90))
	_add(bg, _cyl(0.104, 0.04, 20), L_DARK, Vector3(-0.03, 0, 0), Vector3(0, 0, 90))
	_add(bg, _sphere(0.11), L_DARK, Vector3(0.31, 0, 0), Vector3.ZERO, Vector3(1.05, 1.0, 1.0))
	_add(bg, _sphere(0.075), BRASS, Vector3(0.405, 0, 0), Vector3.ZERO, Vector3(0.6, 1.1, 1.1))
	for sx in [0.15, 0.25]: _add(bg, _torus(0.086, 0.13), VENT_RED, Vector3(sx, 0, 0), Vector3(0, 0, 90))
	for sz in [-0.05, 0.05]:
		_add(bg, _cyl(0.014, 0.3, 10), STEEL, Vector3(0.17, 0.128, sz), Vector3(0, 0, 90))
		_add(bg, _cyl(0.027, 0.11, 12), L_DARK, Vector3(0.04, 0.128, sz), Vector3(0, 0, 90))
		_add(bg, _sphere(0.022), STEEL, Vector3(0.325, 0.128, sz))
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		_add(bg, _sphere(0.014), STEEL, Vector3(-0.03, sin(a) * 0.104, cos(a) * 0.104))
	_gear(bg, Vector3(0.1, 0.0, 0.095), Vector3(90, 0, 0), 0.04, 0.02, 8)
	_save(bg, "big_gauntlet")
	# piston gauntlet (both KESTREL forearms): the standard cuff plus two piston rods and a small teal vent
	var pg := Node3D.new(); pg.name = "PistonGauntlet"
	_add(pg, _cyl(0.056, 0.17), BRASS, Vector3(0.02, 0, 0), Vector3(0, 0, 90))
	_add(pg, _cyl(0.062, 0.03), L_DARK, Vector3(-0.07, 0, 0), Vector3(0, 0, 90))
	_add(pg, _torus(0.054, 0.068), L_LEATHER, Vector3(0.1, 0, 0), Vector3(0, 0, 90))
	for sz in [-0.03, 0.03]:
		_add(pg, _cyl(0.01, 0.2), STEEL, Vector3(0.04, 0.072, sz), Vector3(0, 0, 90))
		_add(pg, _cyl(0.017, 0.07), L_DARK, Vector3(-0.03, 0.072, sz), Vector3(0, 0, 90))
	var pv := BoxMesh.new(); pv.size = Vector3(0.05, 0.018, 0.04)
	_add(pg, pv, VENT_TEAL, Vector3(0.05, 0.066, 0))
	_gear(pg, Vector3(0.0, 0.0, 0.06), Vector3(90, 0, 0), 0.028, 0.016, 8)
	_save(pg, "piston_gauntlet")
	# apron: leather panel from the chest to the knee, with a pocket and rivets (hung from the hips, front is +Z)
	var ap := Node3D.new(); ap.name = "Apron"
	_add(ap, _panel(0.26, 0.34, 0.66, 0.03, 0.02), L_APRON, Vector3(0, 0, 0))
	_add(ap, _panel(0.2, 0.2, 0.16, 0.02), L_LEATHER, Vector3(0, -0.14, 0.05))
	_add(ap, _panel(0.3, 0.3, 0.05, 0.034), L_DARK, Vector3(0, 0.3, 0.0))
	for sx in [-0.09, 0.09]: _add(ap, _cyl(0.014, 0.01), BRASS, Vector3(sx, 0.1, 0.022), Vector3(90, 0, 0))
	_save(ap, "apron")
	# heavy boots: a rounded shoe body, a brass toe cap, an ankle cuff with rivets (foot axis +Z)
	var bo := Node3D.new(); bo.name = "Boot"
	_add(bo, _capsule(0.062, 0.26), L_DARK, Vector3(0, 0.0, 0.03), Vector3(90, 0, 0))
	_add(bo, _sphere(0.062), BRASS, Vector3(0, -0.005, 0.15), Vector3.ZERO, Vector3(1.05, 0.85, 1.1))
	_add(bo, _cyl(0.078, 0.1, 16), L_LEATHER, Vector3(0, 0.085, -0.035))
	_add(bo, _torus(0.07, 0.088), BRASS, Vector3(0, 0.132, -0.035))
	for sx in [-0.07, 0.07]: _add(bo, _sphere(0.011), STEEL, Vector3(sx, 0.08, -0.035))
	_save(bo, "boot")
	# moustache: a wide bar with two upturned tips, in the head frame (front is +Z)
	var mo := Node3D.new(); mo.name = "Moustache"
	var bar := BoxMesh.new(); bar.size = Vector3(0.07, 0.022, 0.04)
	_add(mo, bar, L_STACHE)
	var tip := BoxMesh.new(); tip.size = Vector3(0.04, 0.018, 0.036)
	_add(mo, tip, L_STACHE, Vector3(0.05, 0.012, -0.002), Vector3(0, 0, 28))
	_add(mo, tip, L_STACHE, Vector3(-0.05, 0.012, -0.002), Vector3(0, 0, -28))
	_save(mo, "moustache")
	# coat tails: front and back panels from the chest to mid-thigh, teal with a dark hem and brass buttons
	for side in ["front", "back"]:
		var ct := Node3D.new(); ct.name = "Coat" + side.capitalize()
		_add(ct, _panel(0.2, 0.3, 0.5, 0.025, -0.03 if side == "back" else 0.02), L_COAT)
		_add(ct, _panel(0.31, 0.31, 0.04, 0.03, -0.03 if side == "back" else 0.02), L_COAT_TRIM, Vector3(0, -0.24, 0.0))
		if side == "front":
			for i in 3: _add(ct, _cyl(0.014, 0.01), BRASS, Vector3(0, 0.15 - 0.12 * i, 0.016), Vector3(90, 0, 0))
		_save(ct, "coat_" + side)
