class_name Sfx
extends RefCounted
## Placeholder fight sounds, synthesised at start (no files): swish, light / heavy hit, block, KO boom. A real set replaces
## these through the same ids (data/audio.json, later); until then they keep the hits from being silent.

const RATE := 22050
static var _cache := {}

static func get_stream(kind: String) -> AudioStreamWAV:
	if not _cache.has(kind): _cache[kind] = _make(kind)
	return _cache[kind]

static func _make(kind: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var len_s := 0.14; var tone := 0.0; var noise := 0.0; var vol := 0.8; var sweep := false; var decay := 22.0
	match kind:
		"whoosh": len_s = 0.18; noise = 1.0; sweep = true; vol = 0.35; decay = 0.0
		"hit_l": len_s = 0.11; tone = 150.0; noise = 0.7; vol = 0.85; decay = 30.0
		"hit_h": len_s = 0.2; tone = 70.0; noise = 0.8; vol = 1.0; decay = 17.0
		"block": len_s = 0.07; tone = 520.0; noise = 0.4; vol = 0.6; decay = 55.0
		"ko": len_s = 0.7; tone = 48.0; noise = 0.5; vol = 1.0; decay = 5.5
	var n := int(len_s * RATE)
	var data := PackedByteArray(); data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := exp(-decay * t) if decay > 0.0 else sin(PI * float(i) / n)
		var nz := rng.randf_range(-1.0, 1.0)
		if sweep:
			var k := lerpf(0.08, 0.5, sin(PI * float(i) / n))      # the filter opens then closes: a swish
			lp += (nz - lp) * k; nz = lp * 2.2
		var s := (nz * noise + sin(TAU * tone * t * (1.0 - 0.35 * t / len_s)) * (1.0 if tone > 0.0 else 0.0)) * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = RATE; w.stereo = false; w.data = data
	return w

## Small round-robin pool so overlapping hits don't cut each other off.
class Pool extends Node:
	var players: Array[AudioStreamPlayer] = []
	var next := 0
	func _init(count := 6) -> void:
		for i in count:
			var p := AudioStreamPlayer.new(); add_child(p); players.append(p)
	func play(kind: String, pitch := 1.0, db := 0.0) -> void:
		var p := players[next]; next = (next + 1) % players.size()
		p.stream = Sfx.get_stream(kind); p.pitch_scale = pitch; p.volume_db = db
		p.play()
