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

# Buttons: one bit each (four-button design, docs/GODOT_PLAN.md rev 2).
const L := 1
const M := 2
const H := 4
const S := 8
const BL := 16
const THROW := 32
const ATTACK_BUTTONS := [["S", S], ["H", H], ["M", M], ["L", L]]   # priority order when several presses are buffered

# Input buffer
const PRESS_BUFFER := 5         # ticks a press stays consumable
const CHAIN_WINDOW := 5         # recovery ticks (after the last active tick) in which a chain cancel is accepted
const SPECIAL_WINDOW := 6

# Combat
const KNOCKBACK_DECAY := 0.86
const CORNER_SHARE := 0.4
const BLOCK_HITSTOP_LOSS := 2
const SCALE := [100, 90, 80, 70, 60, 50, 40, 40]   # % damage by hit number in a combo
const SCALE_FLOOR := 30
const STUN_DECAY_4 := 0.85
const STUN_DECAY_7 := 0.7
const LIE_SOFT := 22
const LIE_HARD := 34
const GETUP := 22
const WAKE_INVULN := 3
const LAND_LAG := 3
const AIR_HIT_VX := 2.0
const AIR_HIT_VY := 3.0
const THROW_RELEASE := 14
const TECH_WINDOW := 7          # defender may tech a grab on the 1st to 7th tick after it connects; damage lands on the 8th
const TECH_KB := 3.9            # slide per tick of a teched fighter; with KNOCKBACK_DECAY that is about 28 px apart
const TECH_STUN := 20
const JUGGLE_POINTS := 3

# Match flow (ticks)
const INTRO := 90
const CALL := 72
const GO := 30
const TIMEUP := 60
const ROUND_SECONDS := 99
const SLOW_EVERY := 4
const KO_PACE := { "normal": [24, 24, 60], "final": [24, 40, 90] }   # [freeze, slow-mo, post]

# Body boxes [x, y, w, h], relative to the fighter's centre on the floor, facing right, y up.
const BOXES := {
	"stand": { "push": [-12, 0, 24, 92], "hurt": [[-9, 72, 20, 26], [-14, 34, 28, 40], [-12, 0, 24, 36]] },
	"crouch": { "push": [-12, 0, 24, 60], "hurt": [[-14, 26, 28, 34], [-14, 0, 28, 28]] },
	"air": { "push": [-10, 16, 20, 60], "hurt": [[-13, 18, 26, 66]] },
	"lying": { "push": [0, 0, 0, 0], "hurt": [[-30, 0, 60, 16]] },
}
