extends Node
## Input actions, registered at startup so bindings are data (rebindable, saved to user://bindings.cfg).
## Default layout carried over from v1 (docs/v1/OVERHAUL_PLAN.md R1): light/medium/heavy/special on U I J K, thumb blocks.
## Action names: "<player>_<action>", player = p1 | p2; actions = up down left right light medium heavy special block throw.

const ACTIONS := ["up", "down", "left", "right", "light", "medium", "heavy", "special", "block", "throw"]
const SAVE_PATH := "user://bindings.cfg"

const DEFAULT_KEYS := {
	"p1": {
		"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
		"light": [KEY_U], "medium": [KEY_I], "heavy": [KEY_J], "special": [KEY_K],
		"block": [KEY_SPACE, KEY_L], "throw": [KEY_O],
	},
	"p2": {
		"up": [KEY_UP], "down": [KEY_DOWN], "left": [KEY_LEFT], "right": [KEY_RIGHT],
		"light": [KEY_KP_4, KEY_BRACKETLEFT], "medium": [KEY_KP_5, KEY_BRACKETRIGHT],
		"heavy": [KEY_KP_1, KEY_SEMICOLON], "special": [KEY_KP_2, KEY_APOSTROPHE],
		"block": [KEY_KP_0, KEY_SLASH], "throw": [KEY_KP_3, KEY_PERIOD],
	},
}

# Gamepad (device 0 -> p1, device 1 -> p2): X light, Y medium, A heavy, B special, shoulders block, triggers throw.
const PAD_BUTTONS := {
	"up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN], "left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT],
	"light": [JOY_BUTTON_X], "medium": [JOY_BUTTON_Y], "heavy": [JOY_BUTTON_A], "special": [JOY_BUTTON_B],
	"block": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER],
}
const PAD_AXES := { "left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0], "up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0], "throw": [JOY_AXIS_TRIGGER_RIGHT, 1.0] }

var keys := {}   # player -> action -> Array[int] physical keycodes

func _ready() -> void:
	keys = DEFAULT_KEYS.duplicate(true)
	_load()
	apply()
	if not InputMap.has_action("pause"):
		InputMap.add_action("pause")
		for k in [KEY_ESCAPE, KEY_P]:
			var e := InputEventKey.new(); e.physical_keycode = k; InputMap.action_add_event("pause", e)
		var b := InputEventJoypadButton.new(); b.button_index = JOY_BUTTON_START; b.device = -1; InputMap.action_add_event("pause", b)

func apply() -> void:
	for p in ["p1", "p2"]:
		var device := 0 if p == "p1" else 1
		for a in ACTIONS:
			var name := "%s_%s" % [p, a]
			if InputMap.has_action(name): InputMap.erase_action(name)
			InputMap.add_action(name, 0.5)
			for k in keys[p][a]:
				var e := InputEventKey.new(); e.physical_keycode = k; InputMap.action_add_event(name, e)
			for btn in PAD_BUTTONS.get(a, []):
				var jb := InputEventJoypadButton.new(); jb.button_index = btn; jb.device = device; InputMap.action_add_event(name, jb)
			if PAD_AXES.has(a):
				var jm := InputEventJoypadMotion.new(); jm.axis = PAD_AXES[a][0]; jm.axis_value = PAD_AXES[a][1]; jm.device = device
				InputMap.action_add_event(name, jm)

func rebind(player: String, action: String, keycode: int) -> void:
	keys[player][action] = [keycode]
	apply()
	save()

func reset() -> void:
	keys = DEFAULT_KEYS.duplicate(true)
	apply()
	save()

func save() -> void:
	var cfg := ConfigFile.new()
	for p in keys: for a in keys[p]: cfg.set_value(p, a, keys[p][a])
	cfg.save(SAVE_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK: return
	for p in keys: for a in ACTIONS:
		var v = cfg.get_value(p, a, null)
		if v is Array and not v.is_empty(): keys[p][a] = v

## Human-readable one-liner for hints and the cheat sheet, generated from the live bindings.
func describe(player: String) -> String:
	var k := func(a: String) -> String: return OS.get_keycode_string(keys[player][a][0])
	return "%s%s%s%s move | %s light | %s medium | %s heavy | %s special | %s block | %s throw" % [
		k.call("up"), k.call("left"), k.call("down"), k.call("right"),
		k.call("light"), k.call("medium"), k.call("heavy"), k.call("special"), k.call("block"), k.call("throw")]
