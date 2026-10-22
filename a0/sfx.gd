class_name Sfx
extends RefCounted
## Fight audio from data/audio.json: each id is a bus plus layers, a layer picks a random variant with a pitch range and a gain.
## Layered hits (light / medium / heavy), block, K.O., announcer and UI all come from the Kenney CC0 packs (docs/ASSETS.md F8, F9).
## The one synthesised sound left is the attack whoosh: the packs have no swish.

const PATH := "res://data/audio.json"
const BUSES := ["SFX", "Voice", "UI"]
const RATE := 22050
static var _doc := {}
static var _cache := {}

static func doc() -> Dictionary:
	if _doc.is_empty(): _doc = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return _doc

## Creates the SFX / Voice / UI buses under Master once (idempotent) and sets their default levels.
static func ensure_buses() -> void:
	for b in BUSES:
		if AudioServer.get_bus_index(b) >= 0: continue
		AudioServer.add_bus()
		var i := AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(i, b); AudioServer.set_bus_send(i, "Master")
		AudioServer.set_bus_volume_db(i, {"SFX": 0.0, "Voice": 2.0, "UI": -2.0}[b])

static func stream(path: String) -> AudioStream:
	if not _cache.has(path): _cache[path] = load(path)
	return _cache[path]

static func whoosh() -> AudioStreamWAV:
	if _cache.has("whoosh"): return _cache["whoosh"]
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var n := int(0.18 * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var k := lerpf(0.08, 0.5, sin(PI * float(i) / n))      # the filter opens then closes: a swish
		lp += (rng.randf_range(-1.0, 1.0) - lp) * k
		data.encode_s16(i * 2, int(clampf(lp * 2.2 * sin(PI * float(i) / n) * 0.35, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = data
	_cache["whoosh"] = w
	return w

## Placeholder for an announcer line whose file is not there yet: a short falling two-note tone. The on-screen banner carries the call.
static func tone() -> AudioStreamWAV:
	if _cache.has("tone"): return _cache["tone"]
	var n := int(0.22 * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	for i in n:
		var f := 660.0 if i < n / 2 else 495.0
		data.encode_s16(i * 2, int(sin(TAU * f * i / RATE) * 0.25 * sin(PI * float(i % (n / 2)) / (n / 2)) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = data
	_cache["tone"] = w
	return w

## Round-robin pool of players so overlapping hits and layers don't cut each other off.
class Pool extends Node:
	var players: Array[AudioStreamPlayer] = []
	var next := 0
	func _init(count := 16) -> void:
		Sfx.ensure_buses()
		for i in count:
			var p := AudioStreamPlayer.new(); add_child(p); players.append(p)
	func _go(st: AudioStream, bus: String, pitch: float, db: float) -> void:
		var p := players[next]; next = (next + 1) % players.size()
		p.stream = st; p.bus = bus; p.pitch_scale = pitch; p.volume_db = db
		p.play()
	## pitch is a multiplier on each layer's own random pitch; db is added to its gain.
	func play(id: String, pitch := 1.0, db := 0.0) -> void:
		var e: Dictionary = Sfx.doc().get(id, {})
		if e.is_empty() or (e.has("layers") and not ResourceLoader.exists(String(e.layers[0].files[0]))):
			if id.begins_with("voice_"): _go(Sfx.tone(), "Voice", 1.0, -8.0 + db)      # missing announcer line: tone + banner, nothing breaks
			return
		if e.has("synth"): _go(Sfx.whoosh(), e.bus, pitch, db); return
		for layer in e.layers:
			var f: String = layer.files[randi() % layer.files.size()]
			_go(Sfx.stream(f), e.bus, randf_range(layer.pitch[0], layer.pitch[1]) * pitch, float(layer.db) + db)
