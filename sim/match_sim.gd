class_name MatchSim
extends RefCounted
## Round / match flow around a WorldSim: intro, ROUND call, FIGHT, play with a 99 s timer, KO pacing, best of 1/3/5.
## Phases: intro -> call -> fight -> play -> ko | timeup -> (next round: call -> fight ...) -> over.
## Inputs are locked (neutral) until the "fight" phase. `events` carries the world's events plus round_end / match_end.

var world: WorldSim
var phase := "intro"
var pt := 0                     # ticks spent in the current phase
var round_no := 1
var wins := [0, 0]
var need := 2
var cap := 5                    # most rounds a match can last (draws count as a round)
var timer_ticks := SimConst.ROUND_SECONDS * SimConst.TICK_HZ
var round_winner := -2          # -2 not decided, -1 draw, 0/1 fighter
var match_winner := -2
var perfect := false
var pace: Array = [0, 0, 0]     # [freeze, slow-mo, post] of the current round end
var final_round := false
var events: Array = []

func _init(p1 := "placeholder", p2 := "placeholder", seed := 1, best_of := 3) -> void:
	world = WorldSim.new(p1, p2, seed)
	need = best_of / 2 + 1
	cap = 2 * need + 1

func seconds_left() -> int:
	return int(ceil(timer_ticks / float(SimConst.TICK_HZ)))

func inputs_live() -> bool:
	return phase == "fight" or phase == "play"

func _idle() -> void:
	world.step([WorldSim.neutral(), WorldSim.neutral()])

func step(inputs: Array) -> void:
	events.clear()
	pt += 1
	match phase:
		"intro":
			_idle()
			if pt >= SimConst.INTRO: _go("call")
		"call":
			_idle()
			if pt >= SimConst.CALL: _go("fight")
		"fight":
			world.step(inputs)
			events.append_array(world.events)
			if pt >= SimConst.GO: _go("play")
		"play":
			world.step(inputs)
			events.append_array(world.events)
			timer_ticks -= 1
			var h0: int = world.fighters[0].hp; var h1: int = world.fighters[1].hp
			if h0 <= 0 or h1 <= 0:
				_end_round((1 if h0 <= 0 and h1 > 0 else 0 if h1 <= 0 and h0 > 0 else -1), true)
			elif timer_ticks <= 0:
				var p0 := h0 / float(world.fighters[0].stats.hp); var p1 := h1 / float(world.fighters[1].stats.hp)
				_end_round(0 if p0 > p1 else 1 if p1 > p0 else -1, false)
		"ko", "timeup":
			_round_end_step()
		"over":
			_idle()

func _go(p: String) -> void:
	phase = p; pt = 0

func _end_round(winner: int, by_ko: bool) -> void:
	round_winner = winner
	if winner == -1:
		wins[0] += 1; wins[1] += 1
	else:
		wins[winner] += 1
	perfect = by_ko and winner >= 0 and world.fighters[winner].hp >= int(world.fighters[winner].stats.hp)
	final_round = wins[0] >= need or wins[1] >= need or round_no >= cap
	if by_ko: pace = SimConst.KO_PACE["final" if final_round else "normal"]
	else: pace = [0, 0, SimConst.TIMEUP]
	events.append({ "type": "round_end", "winner": winner, "by_ko": by_ko, "perfect": perfect, "round": round_no, "final": final_round })
	_go("ko" if by_ko else "timeup")

func _round_end_step() -> void:
	var freeze: int = pace[0]; var slow: int = pace[1]; var post: int = pace[2]
	if pt <= freeze:
		pass                                            # full freeze on the killing blow
	elif pt <= freeze + slow:
		if (pt - freeze) % SimConst.SLOW_EVERY == 0: _idle()
	else:
		_idle()
		if round_winner >= 0:
			var w: FighterSim = world.fighters[round_winner]
			if w.actionable() and not w.ko: w.set_state("win")
	if pt >= freeze + slow + post: _finish_round()

func _finish_round() -> void:
	if final_round:
		match_winner = -1 if wins[0] == wins[1] else (0 if wins[0] > wins[1] else 1)
		events.append({ "type": "match_end", "winner": match_winner, "wins": wins.duplicate() })
		_go("over")
		return
	round_no += 1
	round_winner = -2; perfect = false
	timer_ticks = SimConst.ROUND_SECONDS * SimConst.TICK_HZ
	world.reset_round()
	_go("call")

func snapshot() -> Dictionary:
	return { "phase": phase, "pt": pt, "round": round_no, "wins": wins.duplicate(), "timer": timer_ticks, "rw": round_winner, "mw": match_winner, "world": world.snapshot() }

## Full match state for rollback netcode (the world's own save() plus the round flow).
func save() -> Dictionary:
	return { "phase": phase, "pt": pt, "round_no": round_no, "wins": wins.duplicate(), "timer": timer_ticks, "rw": round_winner, "mw": match_winner,
		"perfect": perfect, "pace": pace.duplicate(), "final": final_round, "world": world.save() }

func restore(s: Dictionary) -> void:
	phase = s.phase; pt = s.pt; round_no = s.round_no; wins = s.wins.duplicate(); timer_ticks = s.timer
	round_winner = s.rw; match_winner = s.mw; perfect = s.perfect; pace = s.pace.duplicate(); final_round = s.final
	world.restore(s.world)
	events.clear()

func checksum() -> int:
	return hash(var_to_str(save()))
