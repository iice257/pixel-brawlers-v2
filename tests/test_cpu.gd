extends GutTest
## CPU tiers: deterministic, only ever emits legal inputs, and a higher tier beats a lower one.

func _match(t0: int, t1: int, seed: int) -> int:
	var w := WorldSim.new("placeholder", "placeholder", seed)
	var b := [CpuBrain.new(t0, 0, seed * 2 + 1), CpuBrain.new(t1, 1, seed * 2 + 2)]
	for t in 3600:
		w.step([b[0].think(w.fighters), b[1].think(w.fighters)])
		if w.fighters[0].ko or w.fighters[1].ko: break
	var h0: int = w.fighters[0].hp; var h1: int = w.fighters[1].hp
	return 0 if h0 > h1 else 1 if h1 > h0 else -1

func test_tier8_beats_tier2_at_least_80_percent() -> void:
	var wins := 0; var n := 20
	for i in n:
		var swap := i % 2 == 1
		var r := _match(2, 8, i + 1) if swap else _match(8, 2, i + 1)
		if (r == 1 and swap) or (r == 0 and not swap): wins += 1
	assert_gte(wins, int(n * 0.8), "tier 8 won %d of %d" % [wins, n])

func test_same_seed_same_result() -> void:
	assert_eq(_match(4, 4, 5), _match(4, 4, 5))

func test_tier1_does_something() -> void:
	var w := WorldSim.new("placeholder", "placeholder", 3)
	var b := CpuBrain.new(1, 1, 9)
	var moved := false
	for t in 600:
		var i: Dictionary = b.think(w.fighters)
		if i.left or i.right or i.buttons != 0: moved = true
		w.step([WorldSim.neutral(), i])
	assert_true(moved)
