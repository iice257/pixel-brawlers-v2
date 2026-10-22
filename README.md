# Pixel Brawlers v2

A 2D pixel fighting game, rebuilt in **Godot 4.7** with ready-made art and audio packs instead of code-drawn art. v1 (vanilla JS + Canvas) lives at [iice257/pixel-brawlers](https://github.com/iice257/pixel-brawlers) and stays as the playable reference until v2 passes it.

## Status

Phase G0 (scaffold and animation contract). Two placeholder fighters walk, crouch and jump on a 60 Hz deterministic sim, with a box overlay (F2). Every push to `main` runs the tests and deploys the web build to https://iice257.github.io/pixel-brawlers-v2/. The build plan is `docs/GODOT_PLAN.md`.

## Run

- Editor: open the folder in Godot 4.7 (`project.godot`).
- Tests: `GODOT=<path to godot> sh tools/run_tests.sh` (GUT over `tests/`, then a smoke test).
- Web build: `godot --headless --path . --export-release "Web" build/web/index.html` (needs the 4.7.2 export templates; CI installs them). The build is single-threaded, so it runs on GitHub Pages without special headers.

## Online and mobile

See [docs/ONLINE_AND_MOBILE.md](docs/ONLINE_AND_MOBILE.md): ONLINE menu (rollback netcode, room codes), touch controls and the Android preset.

## Controls (defaults, rebindable)

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Move | W A S D | Arrow keys |
| Light / heavy punch | U / I | Numpad 4 / 5 (or `[` `]`) |
| Light / heavy kick | J / K | Numpad 1 / 2 (or `;` `'`) |
| Block | Space (or L) | Numpad 0 (or `/`) |
| Throw | O | Numpad 3 (or `.`) |
| Pause | Esc / P | Esc / P |

Gamepads: X LP, Y HP, A LK, B HK, shoulders block, right trigger throw, Start pause.

## Layout

- `sim/`: the pure 60 Hz simulation (`WorldSim`, `FighterSim`, `SimConst`). No nodes; tested headlessly.
- `data/fighters/`: per-fighter stats and move lists (JSON).
- `fighters/`: the animation contract (`anim_contract.gd`), `AnimMap`, and each fighter's `anim_map.tres` mapping a sprite pack onto the contract.
- `ui/`: scenes (`fight.tscn`). `scripts/autoload/controls.gd` owns the input map.
- `assets/fighters|stages|ui|audio`: third-party packs (each with its licence file).
- `docs/ref/`: design decisions carried over from v1 (rules, frame data, AI tiers, tuning). Spec, not code.
- `tests/`: GUT tests. `addons/gut`: GUT 9.7.1. `tools/`: headless scripts.
