# Pixel Brawlers v2 (Godot 4): build plan

> **Superseded in part (2026-10-19):** the art direction is now a steampunk 2.5D anime fighter. See `docs/ART_DIRECTION.md` and `docs/HANDOFF.md`. Anything here that assumes pixel art is void.

Rev 2 (2026-10-19). Replaces rev 1. The main changes: real art comes before depth, the move list is fitted to the art pack before combat is built, and the design target shrinks to what free or cheap packs can actually animate.

The owner decided on a brand-new Godot 4 project with imported assets. v1 (`pixel-brawlers`, JS) stays playable as the reference until v2 reaches parity (defined in G5), and is then archived.

## Why rev 1 needed changing
1. **It repeated v1's mistake.** Real art arrived in G3, after combat and AI, so the owner would have judged placeholder rectangles for three phases. Rev 2 gets a real fighter on a real stage in G1.
2. **It built moves no pack can show.** G1 asked for the full GAME_DESIGN set (crouch, lows, overheads, block). After auditing about 20 packs, none of the side-view fighter packs has crouch, block and crouch attacks together in an unarmed style, and none has a KO plus a win pose in its free tier. Building rules for moves with no animation is wasted work.
3. **There was no asset gate.** Nothing forced the pack choice, the animation audit or the licence check to happen before code depended on them.
4. **Hitbox authoring was unspecified.** That is the biggest hidden cost of the switch.

## Principles
1. **Use what exists.** Godot built-ins first: AnimatedSprite2D + SpriteFrames, Theme, AudioStreamPlayer and buses, CPUParticles2D (reliable on the Compatibility/web renderer), InputMap. Write custom tooling only when it saves more than it costs. The one planned exception is the box editor (G1).
2. **Assets are never drawn in code.** Missing art means a placeholder plus a question to the owner, never a procedural generator.
3. **The spec carries over, the code does not.** References live in `docs/ref/`. Where they conflict, TUNING_LOG beats GAME_DESIGN, and `docs/MOVES.md` (written in A0) beats both for the move list.
4. **The sim stays separate from presentation.** It runs at a fixed 60 Hz in `_physics_process`, uses integer frame counts and a seeded RNG, and is a pure RefCounted sim (already in place). Hit, hurt and push boxes come from data keyed by animation frame, never from physics bodies.
5. **Data-driven moves.** Each fighter has one `data/fighters/<id>.json`: stats, a move table (startup, active, recovery, damage, hitstun, blockstun, pushback, level, cancels) and per-frame boxes. Changing tuning or the move list never needs a code edit.
6. **Every phase ships to the web.** The single-threaded export deploys to Pages on every push. Each gate is checked on the live URL, not only in the editor.
7. **Small phases and early playtests.** The owner plays something new at every gate. Nothing waits more than one phase for their eyes.

## Design target (simplified to match the art)
This replaces the SF-style six-button target with a four-button fighter that packs can animate:

| Button | P1 key | P2 key | Meaning |
|---|---|---|---|
| Light | U | Num4 / [ | pack "attack 1" (fast, chains into Medium) |
| Medium | I | Num5 / ] | pack "attack 2" |
| Heavy | J | Num1 / ; | pack "attack 3" (knockdown or launch) |
| Special | K | Num2 / ' | pack special, or `back+Heavy` if the pack has none |
| Block | Space / L | Num0 / / | hold to block (see the block note below) |
| Throw | O | Num3 / . | only if the pack has a grab, otherwise cut |

The physical keys stay as they are in `scripts/autoload/controls.gd`; only the action names change (lp/hp/lk/hk become light/medium/heavy/special).

The rules that stay as in v1: hitstop, hitstun and blockstun, pushback, chains (Light > Medium > Heavy, each once), juggle limit, damage scaling, rounds, timer, KO flow, the AI tiers and the input buffer.

The rules that are cut or deferred until a pack supports them: crouch and the high/low/overhead mix, throw techs, meter and EX, and command motions (QCF and so on). The special is a button, not a motion. Motions can come back in G4 if the controls test well.

**Block when the pack has no block animation:** hold the idle pose's first frame with a guard tint and a small backward lean offset. This is an acknowledged compromise. A generated block pose is a fallback only if it matches the pack's style.

## Phases
Every gate needs four things: `tools/run_tests.sh` green, the Pages build live, screenshots or a gif in `media/qa/`, and a short report to the orchestrator. No phase starts until the previous gate is accepted.

### G0: Scaffold (done, 5fb30c8)
60 Hz placeholder sim, animation contract, Controls autoload, GUT (9 tests), CI, Pages.

### A0: Asset lock (orchestrator + owner; the builder can start G1-core in parallel)
- The fighter kit is decided (owner, 2026-10-19): it combines free packs anchored on Oonquil's free trio, with gaps filled from existing frames and every sheet run through the `tools/unify` pipeline so the packs look like one game. Paid drop-ins are listed for later. The full spec is in `docs/ASSETS.md`.
- Build `tools/unify` and produce the contact sheets. The orchestrator reviews them before any import.
- Audit every animation: name, frame count, frame size, pivot, and whether a hit frame exists. Record it in `docs/ASSETS.md` together with the source URL and licence.
- Write `docs/MOVES.md`: the final move list per fighter, mapped onto pack animations, with v1 frame data used as the starting numbers.
- Choose the base resolution for the sprite size: keep 384x216 if fighters are 80 px tall or less; otherwise use 480x270, with integer scaling either way.
- Rewrite the animation contract REQUIRED list from MOVES.md and drop the names the pack cannot fill.
- Audio set chosen (see the Audio section) and generated-art briefs approved (`docs/ART_PROMPTS.md`).

### G1: Vertical slice (real art, basic hits)
- Import fighter 1 and fighter 2 (or a palette-swapped mirror). SpriteFrames are built by an import script from the pack's sheets, not by hand.
- **Box editor** (`tools/box_editor.tscn`, debug only): step through a move's frames, drag hurt and hit rects, save to the fighter JSON. This is the one bespoke tool. It replaces hand-typing hundreds of rects.
- Frame timing: each sprite frame is held N ticks (per move, in data), so startup, active and recovery come from data and line up with the art.
- Combat core over the MOVES.md set: hit and block, hitstop, hitstun and blockstun, pushback, chains, knockdown and wakeup (pack hurt + wakeup), KO, and rounds and timer. Keep a basic HUD placeholder using Theme, not art yet.
- The real stage background is dropped in (generated SKYLINE image or the chosen pack), with simple two-layer parallax.
- Tests: hit and block outcomes, chain rules, scaling, round and KO flow, deterministic replay, and a soak of 200 seeded matches with no NaN and no exceptions.
- **Gate: the owner plays two real fighters on a real stage on the web build.** This is the moment v1 never reached.

### G2: Feel and CPU
- Juice: hit sparks (pack or Pozac VFX), screen shake (half amplitude on non-final hits, per the v1 ruling), defender flash, KO slow-mo and dust. Particles use CPUParticles2D.
- SFX hooked to events through audio buses (Master, Music, SFX, Voice), plus the announcer (ROUND n, FIGHT, KO, WINNER).
- CPU AI tiers 1-8 per GAME_DESIGN section 7, trimmed to the MOVES.md actions and using v1 `src/ai/ai.js` as the behaviour reference. Tests: a soak, and tier 8 beats tier 2 in at least 80% of matches.
- Training mode: dummy settings and a box overlay toggle (F2).
- Gate: an owner playtest against the CPU on the web build.

### G3: Front end
- Title (logo + key art), mode select (VS CPU, 2 Players, Training, Watch), character select with portraits, stage select (if there is more than one stage), the remappable controls screen, F1 cheat sheet, pause and options (volume, shake off/low/full, CPU difficulty).
- Final HUD from the generated HUD kit: bars, round pips, timer, combo counter. Keep one Theme resource for all UI.
- Music per screen, with loop points set in the import settings.
- Gate: the full flow from title to win screen to rematch, mouse-free, on the web build.

### G4: Content
- Fighters 3 and 4, if the pack has them. A second stage if one is approved.
- Specials and projectiles where the pack has blast, charge or teleport animations. Command motions only if the owner wants them after G2's playtest.
- Win pose and intro (pack animations or a held pose with a banner).
- Gate: the roster is balanced (every pairing is within 40-60% over 500 CPU-vs-CPU tier-6 matches).

### G5: Ship
- Web polish: load time under 5 s on broadband, the audio unlock on first click, focus handling (no "click to focus" surprise), touch controls if the owner wants mobile.
- README with a gif, the Pages link and the asset credits. Portfolio banner (generated art).
- **Parity with v1 means** every v1 mode exists, the CPU is 1-8, controls are remappable, rounds and KO work, and visuals are clearly better (owner verdict). When that holds, archive v1 with a pointer to v2.

## Generated art
Seven images covering 15 items. The prompts are in `docs/ART_PROMPTS.md`.
- AI images are not pixel-exact. Every generated asset goes through `tools/pixelize` (downscale with nearest-neighbour to the target size, quantise to the stage or UI palette, hand clean-up only if needed). The target sizes are listed in ART_PROMPTS.
- Generate from text only. Some packs forbid using their assets "in AI creations" (Oonquil), so never upload pack sprites as image references.
- Store the originals in `assets/_source/` (git-ignored if they are large) and the processed files in `assets/ui/` and `assets/stages/`.

## Audio (non-commercial, so mixed licences are fine; credit everything)
- Announcer: Kenney "Voiceover Pack: Fighter" (CC0). Fill the missing "KO" line from another free pack.
- Hits: Kenney "Impact Sounds" (CC0) plus qubodup "Punch" (CC0). Whooshes and UI from Kenney "Interface Sounds" (CC0).
- Music: CC0 chiptune or synthwave loops (Lashman "Pixel Adventure", OGA "Fast fight battle music", OGA "Chiptune Battle Music"). Use CC-BY tracks if they are better, with credit.
- All of it is recorded in `docs/ASSETS.md` and credited in-game and in the README.

## Hitbox and frame-data workflow (fixed)
1. The import script builds SpriteFrames and writes a stub move entry per attack animation (frame count, default 2 ticks per frame).
2. In the box editor, the builder marks active frames and drags the boxes, and they save to JSON.
3. The startup, active and recovery numbers are derived from the frames times the ticks per frame. A test asserts the derived numbers match MOVES.md within 1 tick.

## Roles
The orchestrator owns this plan, MOVES.md, ASSETS.md and ART_PROMPTS.md, reviews gate evidence and gives rulings. The builder implements one phase at a time, commits only its own files, sends evidence at each gate, and never asks the owner to relay messages.

## Risks
| Risk | Mitigation |
|---|---|
| The pack's moves are too thin to be fun | Four-button design, chains, a strong CPU and juice. Decide at the G1 playtest whether to buy a fuller pack. |
| Generated art clashes with the pack's style | Pixelize pass plus palette lock. The owner reviews at A0 before integration. |
| Mixed sprite sizes between fighters | All fighters come from one artist, or are rescaled by an integer factor only. |
| Web export issues (audio, focus, threads) | The single-threaded build is already on Pages. Check every gate live. |
| Token burn on tooling | Only the box editor and the import, unify and pixelize scripts are allowed as custom tools. |
