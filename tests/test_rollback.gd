extends GutTest
## Rollback readiness: save/restore round-trips, and rolling back 8 ticks then resimulating the same inputs lands on the same checksums.

const L := SimConst.L
const M := SimConst.M
const H := SimConst.H
const THROW := SimConst.THROW

func _inputs(seed: int, n: int) -> Array:
	var rng := RandomNumberGenerator.new(); rng.seed = seed
	var out := []
	var held := [WorldSim.neutral(), WorldSim.neutral()]
	for t in n:
		for p in 2:
			if t % 6 == 0:
				var i := WorldSim.neutral()
				var r := rng.randf()
				i.right = r < 0.3; i.left = r > 0.3 and r < 0.45; i.up = r > 0.9; i.down = r > 0.45 and r < 0.55
				var b := rng.randf()
				i.buttons = L if b < 0.12 else M if b < 0.2 else H if b < 0.27 else THROW if b < 0.3 else SimConst.BL if b < 0.4 else 0
				held[p] = i
		out.append([held[0].duplicate(), held[1].duplicate()])
	return out

func test_restore_round_trip() -> void:
	var w := TestKit.arena(30)
	var inp := _inputs(3, 120)
	for t in 60: w.step(inp[t])
	var snap := w.save(); var sum := w.checksum()
	for t in range(60, 100): w.step(inp[t])
	assert_ne(w.checksum(), sum, "the sim moved on")
	w.restore(snap)
	assert_eq(w.checksum(), sum, "restore puts back the exact state")

func test_rollback_8_ticks_resimulates_identically() -> void:
	for seed in [1, 2, 3, 4, 5]:
		var w := TestKit.arena(30, seed)
		var inp := _inputs(seed, 600)
		var sums := []
		var snaps := {}
		for t in 600:
			if t % 1 == 0: snaps[t] = w.save()
			w.step(inp[t])
			sums.append(w.checksum())
			if t >= 8 and t % 37 == 0:
				var back := t - 7           # roll back 8 ticks: state before tick t-7, resimulate t-7..t
				w.restore(snaps[back])
				for u in range(back, t + 1):
					w.step(inp[u])
					assert_eq(w.checksum(), sums[u], "seed %d tick %d resimulates identically" % [seed, u])
