class_name TrainingTools
extends RefCounted
## Training-mode readouts: the input display (numpad notation + button letters, with a short history) and frame advantage after a hit or block.

const HISTORY := 8
const GIVE_UP_TICKS := 240    # a hit whose advantage never resolves (knockdown, combo continues) is dropped
const SHOW_TICKS := 90        # the advantage stays on screen for 1.5 s

var history: Array = []       # newest first: { "text": String, "ticks": int }
var _last := ""
var _held := 0
var adv_text := ""
var adv_left := 0
var _pend := {}               # { att, def, a, d, age }

## Numpad notation: 5 neutral, 4 back/left, 6 forward/right, 2 down, 8 up (opposite directions cancel).
static func numpad(i: Dictionary) -> int:
	var h := (1 if i.get("right", false) else 0) - (1 if i.get("left", false) else 0)
	var v := (1 if i.get("up", false) else 0) - (1 if i.get("down", false) else 0)
	return 5 + h + v * 3

static func buttons_text(mask: int) -> String:
	var s := ""
	if mask & SimConst.L: s += "L"
	if mask & SimConst.M: s += "M"
	if mask & SimConst.H: s += "H"
	if mask & SimConst.S: s += "S"
	if mask & SimConst.BL: s += "B"
	if mask & SimConst.THROW: s += "T"
	return s

static func input_text(i: Dictionary) -> String:
	var b := buttons_text(int(i.get("buttons", 0)))
	return str(numpad(i)) + ("+" + b if b != "" else "")

## Feed one tick of P1 input. Repeats extend the newest row's frame count; a change pushes a new row.
func record_input(i: Dictionary) -> void:
	var t := input_text(i)
	if t == _last and not history.is_empty():
		history[0].ticks += 1
	else:
		history.push_front({ "text": t, "ticks": 1 }); _last = t
		if history.size() > HISTORY: history.pop_back()

func input_lines() -> String:
	var out := PackedStringArray()
	for h in history: out.append("%-8s %d" % [h.text, mini(int(h.ticks), 99)])
	return "\n".join(out)

## A hit or block landed: start timing when each side gets control back.
func on_contact(att: int, def: int) -> void:
	_pend = { "att": att, "def": def, "a": -1, "d": -1, "age": 0 }

## Call once per sim tick after the step. Advantage = ticks the attacker is free before the defender (positive: attacker acts first).
func update(fighters: Array, tick: int) -> void:
	if adv_left > 0: adv_left -= 1
	if _pend.is_empty(): return
	_pend.age += 1
	if _pend.a < 0 and fighters[_pend.att].actionable(): _pend.a = tick
	if _pend.d < 0 and fighters[_pend.def].actionable(): _pend.d = tick
	if _pend.a >= 0 and _pend.d >= 0:
		var adv: int = _pend.d - _pend.a
		adv_text = "%s%d" % ["+" if adv > 0 else "", adv]; adv_left = SHOW_TICKS
		_pend = {}
	elif _pend.age > GIVE_UP_TICKS:
		_pend = {}

func adv_positive() -> bool:
	return not adv_text.begins_with("-") and adv_text != "0"
