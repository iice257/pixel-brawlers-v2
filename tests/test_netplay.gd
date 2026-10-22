extends GutTest
## Rollback netplay: two sessions in one process talk over simulated latency with CPU brains playing, and must never desync.

const FIGHTERS := [["kestrel", "briggs"], ["briggs", "kestrel"], ["kestrel", "kestrel"]]

class Peer:
	var s: RollbackSession
	var brain: CpuBrain
	func _init(m: MatchSim, idx: int, seed: int) -> void:
		s = RollbackSession.new(m, idx)
		brain = CpuBrain.new(6, idx, seed)
	func input() -> Dictionary:
		return brain.think(s.sim.world.fighters) if s.sim.inputs_live() else WorldSim.neutral()

## Plays a full match between two peers; returns { ticks, a, b, desync, ... }.
func _play(pair: Array, seed: int, delay: int, jitter := 0, loss := 0.0, max_ticks := 60000) -> Dictionary:
	var a := Peer.new(MatchSim.new(pair[0], pair[1], seed, 3), 0, seed + 1)
	var b := Peer.new(MatchSim.new(pair[0], pair[1], seed, 3), 1, seed + 2)
	var ab := LatencyPipe.new(delay, jitter, loss, seed)
	var ba := LatencyPipe.new(delay, jitter, loss, seed + 50)
	var t := 0
	while t < max_ticks and not (a.s.sim.phase == "over" and b.s.sim.phase == "over"):
		for p in ba.pop_due(t): a.s.receive(p)
		for p in ab.pop_due(t): b.s.receive(p)
		a.s.advance(a.input()); b.s.advance(b.input())
		for p in a.s.outbox: ab.push(p, t)
		for p in b.s.outbox: ba.push(p, t)
		a.s.outbox.clear(); b.s.outbox.clear()
		t += 1
		if a.s.desync or b.s.desync: break
	return { "ticks": t, "a": a.s, "b": b.s }

func _same_match(r: Dictionary) -> void:
	var a: RollbackSession = r.a; var b: RollbackSession = r.b
	assert_false(a.desync, "A saw no desync"); assert_false(b.desync, "B saw no desync")
	assert_eq(a.sim.phase, "over", "A reached the end")
	assert_eq(b.sim.phase, "over", "B reached the end")
	assert_eq(a.sim.wins, b.sim.wins, "both peers agree on the round wins")
	assert_eq(a.sim.match_winner, b.sim.match_winner, "both peers agree on the winner")
	assert_eq(a.sim.world.fighters[0].hp, b.sim.world.fighters[0].hp)
	assert_eq(a.sim.world.fighters[1].hp, b.sim.world.fighters[1].hp)

func test_pack_unpack_roundtrip() -> void:
	for buttons in [0, 1, 7, 63]:
		var i := { "left": true, "right": false, "up": true, "down": true, "buttons": buttons }
		assert_eq(RollbackSession.unpack(RollbackSession.pack(i)), i)

func test_match_state_save_restore() -> void:
	var m := MatchSim.new("kestrel", "briggs", 3, 3)
	for t in 400: m.step([WorldSim.neutral(), WorldSim.neutral()])
	var snap := m.save(); var sum := m.checksum()
	for t in 100: m.step([TestKit.btn(SimConst.L), WorldSim.neutral()])
	m.restore(snap)
	assert_eq(m.checksum(), sum)

func test_zero_latency_stays_in_sync() -> void:
	var r := _play(FIGHTERS[0], 11, 0)
	_same_match(r)

func test_100ms_latency_three_matches_no_desync() -> void:
	var rolled := 0
	var depth := 0
	for k in 3:
		var r := _play(FIGHTERS[k], 20 + k, 6)       # 6 ticks one way = 100 ms
		_same_match(r)
		rolled += r.a.rollbacks + r.b.rollbacks
		depth = maxi(depth, maxi(r.a.max_depth, r.b.max_depth))
	assert_gt(rolled, 0, "the latency made the sessions roll back")
	assert_lte(depth, RollbackSession.MAX_ROLLBACK, "never deeper than the limit")
	gut.p("rollbacks %d, deepest %d" % [rolled, depth])

func test_jitter_and_packet_loss_stay_in_sync() -> void:
	var r := _play(FIGHTERS[0], 31, 4, 3, 0.05)
	_same_match(r)

func test_asymmetric_latency_and_very_high_latency() -> void:
	var r := _play(FIGHTERS[1], 41, 12)               # 200 ms one way: the sessions stall instead of predicting further than 8 frames
	_same_match(r)
	assert_gt(r.a.stall_frames + r.b.stall_frames, 0)

func test_a_corrupted_state_is_detected() -> void:
	var a := Peer.new(MatchSim.new("kestrel", "briggs", 5, 3), 0, 1)
	var b := Peer.new(MatchSim.new("kestrel", "briggs", 5, 3), 1, 2)
	var ab := LatencyPipe.new(2); var ba := LatencyPipe.new(2)
	for t in 400:
		for p in ba.pop_due(t): a.s.receive(p)
		for p in ab.pop_due(t): b.s.receive(p)
		if t == 120: b.s.sim.world.fighters[0].hp -= 1       # the peers silently diverge
		a.s.advance(a.input()); b.s.advance(b.input())
		for p in a.s.outbox: ab.push(p, t)
		for p in b.s.outbox: ba.push(p, t)
		a.s.outbox.clear(); b.s.outbox.clear()
	assert_true(a.s.desync or b.s.desync, "checksums caught the divergence")
