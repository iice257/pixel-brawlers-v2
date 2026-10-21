class_name FrameData
extends RefCounted
## Frame data derived from a move table (data/fighters/<id>.json), used by the box editor and by the MOVES.md test.
## The first hit's window gives startup (from - 1) and active (to - from + 1); recovery is the data value.

## { startup, active, recovery, adv_hit, adv_block } for a move. Throws have no hit entries: their own fields are returned.
static func derive(m: Dictionary) -> Dictionary:
	if not m.has("hits") or m.hits.is_empty():
		return { "startup": int(m.startup), "active": int(m.active), "recovery": int(m.recovery), "adv_hit": 0, "adv_block": 0 }
	var h: Dictionary = m.hits[0]
	var active := int(h["to"]) - int(h["from"]) + 1
	var rem := active + int(m.recovery) - 1       # attacker ticks left after the first active tick connects
	return { "startup": int(h["from"]) - 1, "active": active, "recovery": int(m.recovery),
		"adv_hit": int(h.hitstun) - rem, "adv_block": int(h.blockstun) - rem }

## Keeps a move's startup/active fields in step with its first hit window (call after editing from / to).
static func sync(m: Dictionary) -> void:
	if m.has("hits") and not m.hits.is_empty():
		var d := derive(m)
		m.startup = d.startup
		m.active = d.active
