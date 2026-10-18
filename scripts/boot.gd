extends Node2D
## G0 placeholder boot screen: proves the project runs, the 384x216 pixel viewport scales cleanly and input actions work.
## Replaced by the title/menu scene in the plan's first phase.

@onready var title: Label = $Title
@onready var hint: Label = $Hint
@onready var held: Label = $Held

func _ready() -> void:
	hint.text = "P1  " + Controls.describe("p1") + "\nP2  " + Controls.describe("p2")

func _process(_delta: float) -> void:
	var on := []
	for p in ["p1", "p2"]:
		for a in Controls.ACTIONS:
			if Input.is_action_pressed("%s_%s" % [p, a]): on.append("%s %s" % [p.to_upper(), a.to_upper()])
	held.text = " ".join(on) if on else "press any fighter key"
