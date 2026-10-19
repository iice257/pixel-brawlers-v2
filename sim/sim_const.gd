class_name SimConst
## Fixed numbers of the simulation (docs/ref/GAME_DESIGN.md + TUNING_LOG.md; TUNING_LOG wins on conflict).
## World space: x grows right along the stage, y grows UP from the floor (y = 0 is standing on the floor).

const TICK_HZ := 60
const STAGE_W := 576
const FLOOR_Y := 192            # screen row of the floor in the 384x216 view
const STAGE_MIN := 16           # fighter centre clamp
const STAGE_MAX := 560
const MAX_SEP := 296            # fighters can never be further apart than this (walking away is stopped)
const START_X := [228, 348]

const PREJUMP := 3              # ticks of jump squat before takeoff
const JUMP_VY := 8.0
const JUMP_FWD := 2.6
const JUMP_BACK := -2.2

# Buttons: one bit each. Throw is LP + LK pressed together.
const LP := 1
const HP := 2
const LK := 4
const HK := 8
const BL := 16
const THROW := LP | LK

# Body boxes [x, y, w, h], relative to the fighter's centre on the floor, facing right, y up.
const BOXES := {
	"stand": { "push": [-12, 0, 24, 92], "hurt": [[-9, 72, 20, 26], [-14, 34, 28, 40], [-12, 0, 24, 36]] },
	"crouch": { "push": [-12, 0, 24, 60], "hurt": [[-14, 26, 28, 34], [-14, 0, 28, 28]] },
	"air": { "push": [-10, 16, 20, 60], "hurt": [[-13, 18, 26, 66]] },
}
