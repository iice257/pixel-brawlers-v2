class_name PoseLib
extends RefCounted
## Hand-keyed poses (the ASB / Xrd way): data/poses.json holds, per sim anim name, a base clip frame plus a few key poses.
## A key pose is additive bone rotations in skeleton space, degrees [x, y, z]. +X pitches a limb that points up/down toward the
## character's front when it is a spine/head bone, and swings a hanging limb BACK (so arm/leg swing forward = negative X).
## "hips" is an offset in metres. Keys are held, never blended, so they step like the 12 fps clips do.

const PATH := "res://data/poses.json"
## Parents first: each bone's rotation is applied in skeleton space after its parent's.
const ORDER := ["Hips", "Spine", "Chest", "UpperChest", "Neck", "Head",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot"]
const FEET := ["LeftFoot", "RightFoot", "LeftToes", "RightToes"]
const ANKLE := 0.07

static var _doc := {}

static func doc() -> Dictionary:
	if _doc.is_empty():
		_doc = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _doc

static func reload() -> void:
	_doc = {}

static func has_pose(name: String) -> bool:
	return doc().has(name)

## [clip, t] the pose is layered on.
static func base(name: String) -> Array:
	var b = doc()[name].get("base", ["Punch_Jab", 0.0])
	return [String(b[0]), float(b[1])]

static func phases(name: String) -> Array:
	var out := []
	for k in ["ant", "imp", "fol", "rec"]:
		if doc()[name].has(k): out.append(k)
	return out

## Key pose to show for a phase; a missing phase falls back to the previous one, then the base.
static func key(name: String, phase: String) -> Dictionary:
	var d: Dictionary = doc()[name]
	var order := ["ant", "imp", "fol", "rec"]
	for i in range(order.find(phase), -1, -1):
		if d.has(order[i]): return d[order[i]]
	return d.get("pose", {})

## Applies the key's rotations to an animated skeleton (call after the base clip was seeked).
static func apply(skel: Skeleton3D, k: Dictionary) -> void:
	for bn in ORDER:
		if not k.has(bn): continue
		var b := skel.find_bone(bn)
		if b < 0: continue
		var v: Array = k[bn]
		var r := Quaternion.from_euler(Vector3(deg_to_rad(v[0]), deg_to_rad(v[1]), deg_to_rad(v[2])))
		var par := skel.get_bone_parent(b)
		var pq := skel.get_bone_global_pose(par).basis.get_rotation_quaternion() if par >= 0 else Quaternion.IDENTITY
		skel.set_bone_pose_rotation(b, pq.inverse() * r * pq * skel.get_bone_pose_rotation(b))
	if k.has("hips"):
		var h := skel.find_bone("Hips")
		var o: Array = k["hips"]
		skel.set_bone_pose_position(h, skel.get_bone_pose_position(h) + Vector3(o[0], o[1], o[2]))

## Drop that puts the lowest foot on the floor.
static func floor_drop(skel: Skeleton3D) -> float:
	var low := 1e9
	for n in FEET:
		var b := skel.find_bone(n)
		if b >= 0: low = minf(low, skel.get_bone_global_pose(b).origin.y)
	return -(low - ANKLE) if low < 1e8 else 0.0
