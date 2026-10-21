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

func _cyl(r: float, h: float, segs := 16) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = r; c.bottom_radius = r; c.height = h; c.radial_segments = segs; c.rings = 1
	return c

func _gear(parent: Node3D, pos: Vector3, rot: Vector3, r: float, thick: float, teeth: int) -> void:
	var g := Node3D.new(); g.position = pos; g.rotation_degrees = rot
	parent.add_child(g)
	_add(g, _cyl(r, thick, 20), BRASS)
	_add(g, _cyl(r * 0.35, thick * 1.6, 12), DARK)
	for i in teeth:
		var a := TAU * i / teeth
		var b := BoxMesh.new(); b.size = Vector3(r * 0.38, thick, r * 0.34)
		_add(g, b, BRASS, Vector3(cos(a), 0, sin(a)) * r * 1.02, Vector3(0, -rad_to_deg(a), 0))

func _save(root: Node3D, name: String) -> void:
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
	_add(gg, _torus(0.036, 0.052), BRASS, Vector3(-0.05, 0, 0.0), Vector3(90, 0, 0))
	_add(gg, _torus(0.036, 0.052), BRASS, Vector3(0.05, 0, 0.0), Vector3(90, 0, 0))
	_add(gg, _cyl(0.037, 0.012), GLASS, Vector3(-0.05, 0, 0.0), Vector3(90, 0, 0))
	_add(gg, _cyl(0.037, 0.012), GLASS, Vector3(0.05, 0, 0.0), Vector3(90, 0, 0))
	_add(gg, _torus(0.088, 0.1), LEATHER, Vector3(0, 0, -0.085), Vector3(0, 0, 0), Vector3(1.0, 1.0, 1.0))
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
	quit()
