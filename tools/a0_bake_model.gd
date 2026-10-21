extends SceneTree
## Bakes an imported VRM into a plain scene with our toon + outline materials, so the shipped build
## needs neither godot-vrm nor MToon. Drop-in for a new fighter: put the VRM anywhere, optionally add fighters/<id>/look.json,
## run tools/bake_fighter.sh <vrm> <id>. Output: fighters/<id>/model.scn + fighters/<id>/tex/. Animations are shared
## (fighters/shared/anims.res, keyed by humanoid bone names), so nothing else changes.
## look.json keys (all optional): shade_skin, shade_cloth [r,g,b]; outline_width {skin,cloth,hair}; outline_color [r,g,b];
## p2_swap (hue swap amount for the second player); flatten [{material, boxes:[[x,y,w,h]..] (1024-px UV space), color}].

const SH := "res://assets/shaders/"

var id := "a0"
var look := {}

func _col(key: String, fallback: Color) -> Color:
	var v = look.get(key)
	return Color(v[0], v[1], v[2]) if v is Array and v.size() >= 3 else fallback

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var src: String = args[0] if args.size() > 0 else "res://assets/src/vrm/Base_Female.vrm"
	id = args[1] if args.size() > 1 else "a0"
	var out := "res://fighters/%s/model.scn" % id
	DirAccess.make_dir_recursive_absolute("res://fighters/%s" % id)
	var look_path := "res://fighters/%s/look.json" % id
	if FileAccess.file_exists(look_path): look = JSON.parse_string(FileAccess.get_file_as_string(look_path))
	var inst: Node = (load(src) as PackedScene).instantiate()
	root.add_child(inst)   # the VRM materials are completed in the top-level script's _ready
	var model := Node3D.new(); model.name = "Model"
	var skel: Skeleton3D = inst.find_child("GeneralSkeleton", true, false)
	skel.get_parent().remove_child(skel)
	skel.owner = null
	model.add_child(skel)
	skel.name = "Skeleton3D"
	for mi in skel.find_children("*", "MeshInstance3D", false, false):
		_toonify(mi)
	for c in skel.get_children():
		if not (c is MeshInstance3D): c.queue_free()      # spring-bone and look nodes: not needed for A0
	_own(model, model)
	var ps := PackedScene.new()
	ps.pack(model)
	var err := ResourceSaver.save(ps, out, ResourceSaver.FLAG_COMPRESS)
	print("baked ", src, " -> ", out, " err=", err, " bones=", skel.get_bone_count())
	quit()

func _own(n: Node, root: Node) -> void:
	for c in n.get_children():
		c.owner = root
		_own(c, root)

## Rebuilds the mesh without blend shapes (56 face morphs are about 10 MB and the fighters do not use them).
func _strip_blends(src: ArrayMesh) -> ArrayMesh:
	var am := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		arrays.resize(Mesh.ARRAY_MAX)
		am.add_surface_from_arrays(src.surface_get_primitive_type(s), arrays)
	return am

func _toonify(mi: MeshInstance3D) -> void:
	var src: ArrayMesh = mi.mesh
	mi.mesh = _strip_blends(src)
	for s in mi.mesh.get_surface_count():
		var old: ShaderMaterial = src.surface_get_material(s)
		var shader_name := old.shader.resource_path.get_file()
		var mat_name := old.resource_name
		var is_eye := "EYE" in mat_name
		# only the eye overlays blend; everything else is opaque or alpha-scissored (no translucent sleeves)
		var kind := ("blend" if is_eye else "cutout") if ("trans" in shader_name or "cutout" in shader_name) else "opaque"
		var m := ShaderMaterial.new()
		m.resource_name = mat_name
		m.shader = load(SH + {"opaque": "toon.gdshader", "cutout": "toon_cutout.gdshader", "blend": "toon_blend.gdshader"}[kind])
		var tex := _small(old.get_shader_parameter("_MainTex"), mat_name)
		m.set_shader_parameter("albedo_tex", tex)
		m.set_shader_parameter("base_color", old.get_shader_parameter("_Color"))
		# hard 2-band: one neutral cool shadow colour per material class, not the VRM pastel shade
		var skin := "SKIN" in mat_name
		m.set_shader_parameter("shade_color", _col("shade_skin", Color(0.46, 0.3, 0.42)) if skin else _col("shade_cloth", Color(0.3, 0.26, 0.42)))
		m.set_shader_parameter("tint_k", 0.0 if (skin or is_eye or "Face" in mat_name) else 1.0)
		var is_face := "Face_00_SKIN" in mat_name
		m.set_shader_parameter("face_flatten", 0.85 if is_face else 0.0)
		if "EYE" in mat_name or "FaceMouth" in mat_name or "FaceEye" in mat_name or "FaceBrow" in mat_name:
			m.set_shader_parameter("rim_width", 0.0)
		m.render_priority = old.render_priority
		var wants_outline := old.next_pass != null or "HAIR" in mat_name or "CLOTH" in mat_name
		if wants_outline and not ("EYE" in mat_name):
			var o := ShaderMaterial.new()
			o.shader = load(SH + "toon_outline.gdshader")
			o.set_shader_parameter("albedo_tex", tex)
			o.set_shader_parameter("base_color", old.get_shader_parameter("_Color"))
			o.set_shader_parameter("use_cut", kind != "opaque")
			var ow: Dictionary = look.get("outline_width", {})
			o.set_shader_parameter("width", ow.get("hair", 0.026) if "HAIR" in mat_name else (ow.get("skin", 0.02) if skin else ow.get("cloth", 0.022)))
			o.set_shader_parameter("line_color", _col("outline_color", Color("120e14")))
			m.next_pass = o
		mi.set_surface_override_material(s, m)

const MAX_TEX := 1024
var _tex_cache := {}

func _small(t: Texture2D, mat_name: String) -> Texture2D:
	if t == null: return null
	if _tex_cache.has(t): return _tex_cache[t]
	var img := t.get_image()
	if img.is_compressed(): img.decompress()
	if maxi(img.get_width(), img.get_height()) > MAX_TEX:
		var k := float(MAX_TEX) / maxi(img.get_width(), img.get_height())
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	_flatten(img, mat_name)
	# texture files live next to the model and are imported by the editor; the second bake run links to the imported copies
	var path := "res://fighters/%s/tex/tex_%d.png" % [id, _tex_cache.size()]
	DirAccess.make_dir_recursive_absolute("res://fighters/%s/tex" % id)
	img.save_png(path)
	var r: Texture2D = load(path) if ResourceLoader.exists(path) else null
	if r == null:
		img.generate_mipmaps()
		r = ImageTexture.create_from_image(img)
	_tex_cache[t] = r
	return r

## Repaints painted-in shading regions flat (look.json "flatten"). VRoid shirts ship soft blue-to-white gradients in the
## sleeves and collar that read as a translucent smear in a hard-band toon.
func _flatten(img: Image, mat_name: String) -> void:
	var k := img.get_width() / 1024.0
	for rule in look.get("flatten", []):
		if not (str(rule.material) in mat_name): continue
		var col := Color(rule.color[0], rule.color[1], rule.color[2])
		for b in rule.boxes:
			var box := Rect2(b[0], b[1], b[2], b[3])
			for y in range(int(box.position.y * k), int(box.end.y * k)):
				for x in range(int(box.position.x * k), int(box.end.x * k)):
					var c := img.get_pixel(x, y)
					if c.a > 0.5 and c.get_luminance() > 0.1:
						img.set_pixel(x, y, Color(col.r, col.g, col.b, c.a))
