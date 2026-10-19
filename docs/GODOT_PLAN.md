# Pixel Brawlers v2 (Godot 4): build plan

Owner decision: brand-new Godot 4 project, buy/import assets instead of drawing them in code. v1 (`pixel-brawlers`, JS) stays playable as the reference until v2 passes parity, then is archived.

## Principles
1. **Spec carries over, code does not.** Source of truth: `docs/ref/GAME_DESIGN.md`, `TUNING_LOG.md`, `OVERHAUL_PLAN.md` (R1 controls). Where v1 tuning conflicts with GAME_DESIGN, TUNING_LOG wins.
2. **Assets are never made in code.** If art/audio is missing, use a placeholder and ask the owner; do not build a procedural generator.
3. **Sim is separate from presentation.** Fixed 60 Hz (`_physics_process`, `Engine.physics_ticks_per_second = 60`), integer frames, seeded RNG (`RandomNumberGenerator` with explicit seed). Scenes/animations only render sim state; hit/hurtboxes come from data, not from node collisions.
4. **Data-driven moves.** Frame data in `.tres`/JSON per fighter (startup, active, recovery, dmg, hitstun, blockstun, pushback, hit level, cancels, box rects per frame). Tuning never needs code edits.
5. **Test the sim headlessly** (GUT, `godot --headless`). Every ported rule gets a test.
6. **Web first-class.** Single-threaded web export; GitHub Pages deploy; check it after each phase.

## Animation contract (asset-agnostic, fixed in G0)
Each fighter exposes the same named states; the sprite pack is mapped onto them via `fighters/<id>/anim_map.tres`.
Required: idle, walk_f, walk_b, crouch, jump_up, jump_f, jump_b, block_stand, block_crouch, hit_light, hit_heavy, knockdown, wakeup, ko, win, plus one anim per attack in the move list. Missing animation = move cut or placeholder, decided with the owner. The pack chosen defines the final move list; GAME_DESIGN's list is the target, not a promise.

## Phases (each ends with a gate: tests green, web export runs, screenshots/gif sent to owner)

### G0: Scaffold and contract (asset-agnostic)
- Project settings: 384x216 (or pack-appropriate) base, integer scaling, 60 Hz, pixel snap, InputMap with the R1 layout (U/I punches, J/K kicks, Space block, O throw; P2 arrows+numpad; pad support).
- Folder layout: `sim/`, `data/`, `fighters/`, `ui/`, `stages/`, `tests/`, `docs/ref/`.
- Placeholder fighter (colored rectangles) that idles, walks, jumps at 60 Hz; box debug overlay (toggle).
- Animation contract + `anim_map` loader; GUT installed; CI-less local `run_tests` script; web export preset + Pages workflow.
- Gate: rectangles move on web build; one GUT test passes.

### G1: Combat core (port rules + tests)
- Fighter state machine, hit/hurt/push boxes, hit levels and blocking, hitstop, hitstun/blockstun, pushback, knockdown/wakeup, throws and tech, chains/cancels, juggle, combo scaling, rounds/timer/KO flow (GAME_DESIGN 2, 3, 4).
- Frame data loaded from data files; use placeholder boxes until the pack arrives.
- Port the v1 behaviours as GUT tests (list them from `tests/*.test.mjs` in v1: deterministic replay, block/hit levels, throw/tech, chain once-per-normal, scaling, KO flow, soak of N random matches without NaN/exception).
- Gate: scripted fights reproduce v1 numbers for at least the universal normals.

### G2: Input, modes, menus, CPU
- Input buffer/motions (GAME_DESIGN 1), remappable controls screen, F1 cheat sheet, pause.
- Modes: VS CPU (1-8), 2 Players, Training, Watch; character select; Control-node UI with one Theme.
- CPU AI tiers 1-8 per GAME_DESIGN 7 and v1 `src/ai` as reference; tests: soak, tier 8 beats tier 2 at least 80%.
- Gate: owner playtest of controls and CPU on web build.

### G3: Real art and audio (needs the chosen sprite pack)
- Import the chosen fighter pack; build `anim_map`, author per-frame hitboxes in AnimationPlayer or the data files; reconcile the move list.
- Stage(s), HUD, announcer, music and SFX from asset packs; hit FX from a pack or simple GPU particles; shake/hitstop polish.
- Licences recorded in `docs/ASSETS.md` (source, licence, attribution).
- Gate: SURGE-equivalent fighter looks right in a combat sheet reviewed by the owner before the second fighter starts.

### G4: Content and ship
- Second (and further) fighters, specials and meter (GAME_DESIGN 2.8, 3.4), arcade ladder if scope allows.
- Web export tuned (load time, audio unlock, touch UI), Pages deploy, README with gif, portfolio entry.
- v1 repo archived with a pointer to v2.

## Orchestrator / builder split
Orchestrator owns this plan, reviews gate evidence and rulings; builder implements one phase at a time, commits only its own files, sends screenshots/gifs at each gate, and stops for review at G3's first-fighter checkpoint. No phase starts before the previous gate is accepted.

## Open decisions for the owner
- Sprite pack choice (blocks G3 only).
- Audio source (free packs vs purchased).
- Whether specials/arcade are in the first shippable cut or after.
