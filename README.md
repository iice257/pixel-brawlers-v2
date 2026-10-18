# Pixel Brawlers v2

A 2D pixel fighting game, rebuilt in **Godot 4.7** with ready-made art and audio packs instead of code-drawn art. v1 (vanilla JS + Canvas) lives at [iice257/pixel-brawlers](https://github.com/iice257/pixel-brawlers) and stays as the playable reference until v2 passes it.

## Status

Scaffold. The project runs, scales a 384x216 pixel viewport by whole numbers, registers rebindable P1/P2 controls, and builds to the web on every push to `main`. The build plan is in `docs/GODOT_PLAN.md` (written by the orchestrator).

## Run

- Editor: open the folder in Godot 4.7 (`project.godot`).
- Smoke test: `godot --headless --path . --script res://tools/smoke.gd`
- Web build: `godot --headless --path . --export-release "Web" build/web/index.html` (needs the 4.7.2 export templates; CI installs them). The build is single-threaded, so it runs on GitHub Pages without special headers.

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

- `scenes/`, `scripts/`: game code. `scripts/autoload/controls.gd` owns the input map.
- `assets/fighters|stages|ui|audio`: third-party packs (each with its licence file).
- `docs/v1/`: design decisions carried over from v1 (rules, frame data, AI tiers, tuning). Spec, not code.
- `tools/`: headless scripts.
