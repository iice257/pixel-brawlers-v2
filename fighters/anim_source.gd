class_name AnimSource
extends RefCounted
## Animation drop-in slot (data/anim_map.json). Every sim anim name resolves to a source: the hand-keyed PoseLib pose or a UAL clip by
## default, or an imported clip (assets/anims/ext.res, baked by tools/bake_anims.py) when the map names one. Per-entry "pose" layers a
## PoseLib key on top, so a purchased clip can still be nudged per move. Entries whose clip is not in the library are ignored.

const PATH := "res://data/anim_map.json"
const STEP_FPS := 12.0   # held-pose cel playback, same as the fighter view
static var _doc := {}
static var _lib: AnimationLibrary

static func doc() -> Dictionary:
	if _doc.is_empty(): _doc = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _doc

static func reload() -> void:
	_doc = {}; _lib = null

## The imported clip library, or null while nothing has been dropped in.
static func library() -> AnimationLibrary:
	if _lib == null and ResourceLoader.exists(String(doc().clips)): _lib = load(String(doc().clips)) as AnimationLibrary
	return _lib

static func has(name: String) -> bool:
	var e = doc().map.get(name)
	return e != null and library() != null and library().has_animation(StringName(e.clip))

## [clip name in the "ext" library, time in seconds, PoseLib key]; `u` is 0..1 progress through the move (or the loop clock in seconds for loops).
## `speed` is the fighter's ground speed in m/s: mode "stride" plays the clip at the rate that keeps the planted foot moving with the body
## (entry "mps" = the clip's own planted-foot speed, measured by tools/bake_mco.gd); "reverse" plays it backwards for walking backwards, and
## "fast_clip"/"fast_above"/"fast_mps" swap in a run clip above that speed.
static func resolve(name: String, u: float, clock: float, speed := 0.0) -> Array:
	var e: Dictionary = doc().map[name]
	var clip := String(e.clip)
	var mps := float(e.get("mps", 1.0))
	if e.has("fast_clip") and speed > float(e.fast_above) and library().has_animation(StringName(e.fast_clip)):
		clip = String(e.fast_clip); mps = float(e.fast_mps)
	var len := library().get_animation(StringName(clip)).length
	var t := 0.0
	match String(e.get("mode", "loop")):
		"hold": t = float(e.get("t", 0.0))
		"move": t = clampf(u, 0.0, 1.0) * (len - 0.02)
		"stride":
			t = floorf(clock * speed / maxf(mps, 0.01) * STEP_FPS) / STEP_FPS
			t = fposmod(t, len)
			if e.get("reverse", false): t = len - t - 0.02
		_: t = fposmod(floorf(clock * float(e.get("rate", 1.0)) * STEP_FPS) / STEP_FPS, len)
	var key := PoseLib.key(String(e.pose), "imp") if e.has("pose") and PoseLib.has_pose(String(e.pose)) else {}
	return ["ext/" + clip, t, key]
