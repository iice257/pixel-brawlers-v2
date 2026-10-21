# Pixel Brawlers v2 (Godot 4): build plan

Rev 3 (2026-10-20). Replaces rev 2, which assumed pixel art. Art direction is in `docs/ART_DIRECTION.md`; the owner's answers (web first, steampunk without elements, roster 2 then 6) are recorded there.

The product: a 2.5D steampunk anime fighter. Characters are 3D cel-shaded, gameplay stays on a 2D plane, and the game must run **in the browser**.

## What carries over unchanged
- The G0 deterministic 60 Hz sim (`sim/`), the animation contract and AnimMap, rebindable controls, the 9 GUT tests, CI and the Pages deploy.
- Rules and numbers in `docs/ref/` (TUNING_LOG beats GAME_DESIGN).
- The rev 2 principles: use Godot built-ins; never draw assets in code; the sim is separate from presentation (pure RefCounted, integer frames, seeded RNG); moves and boxes are data (`data/fighters/<id>.json`); every phase ships to Pages; the owner plays at every gate.

## What changes
- **Rendering sits on top of the sim.** The sim outputs state, frame, position and facing. A presenter node poses the 3D character from that. The sim never reads the 3D scene. Hit, hurt and push boxes stay 2D rects keyed by move frame, authored in a small box editor over the model's side view.
- **Web first.** The Compatibility renderer (WebGL2) is the only target that must work.
- **Moves fit animation clips, not pixel packs.** Clips come from Quaternius UAL (CC0) and Mixamo (owner-fetched), retargeted to Godot's humanoid profile.

## Design target
Four attack buttons plus block, as decided: Light, Medium, Heavy, Special, and hold Block.

**Ruling: crouch and lows come back. Throws, overheads, meter and command motions stay deferred.**
- Why: the clip libraries have crouch idle, crouch walk, crouch attacks and block poses, so the old blocker (no animation) is gone. Standing versus crouch block plus a low gives the basic mix-up for one extra stance state in the sim.
- Scope: Down held = crouch. Crouch block. Down+Light and Down+Medium are lows; Down+Heavy is a sweep or launcher. Standing attacks are mids. No overheads in G1 to G4.
- Throw: G4 only, and only for a fighter with a grab clip. Meter/EX and motions: revisit after the G2 playtest.
- Sim impact: add a crouch stance with its own hurtbox, and a rule that lows must be blocked crouching. The crouch placeholder work already in the working tree is kept.

Keys stay as in `scripts/autoload/controls.gd` (actions light/medium/heavy/special/block).

## Web budget (hard limits, checked at every gate on the live Pages build)
| Item | Limit |
|---|---|
| Frame rate | 60 fps on a mid laptop iGPU in Chrome and Firefox |
| Per fighter | 15k triangles or fewer, 6 materials or fewer (VRoid's export material reduction; no custom atlas tool), textures 1024 px or smaller, one skeleton |
| Draw calls | 150 or fewer in a fight scene (this is the governing limit; the outline pass doubles each material's draws) |
| Lights | One directional light feeding the toon ramp; no per-pixel point lights |
| Shadows | One directional shadow for fighters only, or a blob decal if it costs too much |
| Build size | 40 MB gzipped or less total; first interactive in under 10 s on broadband |
| Post-process | One full-screen pass at most (impact invert / palette shift), only while active |
| Particles | Cap live counts; use whichever of CPU or GPU particles tests faster on web |

If a limit is hit, cut the effect, not the budget.

## Look recipe (Compatibility-safe)
1. **Cel shading:** a custom `toon.gdshader`: 2 to 3 hard light bands, a flat rim light, a per-fighter palette ramp, an emission pass for brass-tech glow.
2. **Ink outlines:** inverted-hull pass (back faces pushed along normals, width varied by vertex colour). Depth/normal post edges only if budget allows later.
3. **Screentone and hatching** in the deepest shadow band, from a screen-space dither pattern in the shader (no depth texture).
4. **Stepped animation:** the presenter seeks AnimationPlayer to time quantised to 12 to 15 fps, holding key poses on active frames. Smear frames on big hits come in G2.
5. **Impact frames:** a CanvasLayer shader inverts and thresholds the screen for 2 to 4 sim frames (`hint_screen_texture`), with onomatopoeia sprites on top.
6. **Environment:** a fixed side camera on a 3D scene. Near and mid planes from modular kits, far planes as painted billboards, plus moving parts (steam, gears, airships). The camera follows the pair with a hard x clamp.

## Phases
Every gate needs: `tools/run_tests.sh` green, the Pages build live and inside the web budget, screenshots or a gif in `media/qa/`, and a short report to the orchestrator. No phase starts until the previous gate is accepted. The owner plays at each gate.

### G1-core (in progress, asset-agnostic)
Hit and block, hitstop, hitstun and blockstun, pushback, chains, KO, rounds and timer, plus crouch and lows per the ruling, with tests. No rendering. Gate: tests green and a headless soak. A0 starts when this is committed.

### A0: Character-pipeline proof
Goal: prove one steampunk anime fighter looks right and runs fast in the browser before spending on more art.
1. Import one VRM with godot-vrm, starting from the CC0 VRoid sample bases (see `docs/ASSETS.md`). The owner's own VRoid character replaces it later. **Bake the dependency out:** after import, save the character as ordinary scenes and resources with our own toon materials, so the shipped build does not need the importer or MToon.
2. Retarget clips to the Godot humanoid profile: idle, walk forward and back, crouch idle, crouch block, stand block, light/medium/heavy punch, kick, special, hit (light and heavy), knockdown, get-up, KO, win, taunt. Quaternius UAL first (free, no login). Mixamo clips fill gaps from the list in ASSETS.md, which the owner downloads because Mixamo needs an Adobe login.
3. Toon shader, inverted-hull outline and shadow screentone on that character.
4. A stepped 12 to 15 fps presenter driven by the real `sim/` with the placeholder fighter, in a **side-view test scene** with a flat floor and the fixed camera.
5. A first steampunk dressing pass: goggles, a gauntlet or pauldron and belt/gears attached to bones (Blender or CC0 props). Not a full outfit yet.
6. Export to the web and measure against the web budget.

**A0 quality bar (all must pass; the orchestrator rejects otherwise):**
- **Not "Mixamo in a toon shader".** Every attack has a readable anticipation pose, a held impact pose (at least 3 to 6 sim frames on the active frame) and a clear recovery. Poses are exaggerated past the source clip where needed (per-move pose offsets or keyed edits), never played back raw.
- **Silhouette test:** a black-fill render of idle, punch, kick and hit is readable at game camera size. Fists and feet extend clearly away from the body on active frames.
- **Shading:** no smooth gradients on skin or cloth. Two or three hard bands, a visible rim, and outline width consistent at game camera distance. No outline gaps or spikes at the hair, fingers or clothing seams.
- **Faces:** anime face shading stays clean (no shadow blotches across the face from the toon ramp); use face-normal or a face-specific ramp if needed.
- **Stepped motion** reads as deliberate (held keys), not as a low frame rate. Root and body position stay smooth at 60 Hz while the pose steps.
- **Side-by-side check:** `media/qa/A0-compare.png` places our frame next to a still from each top reference (JoJo ASB, Genshin, Arcane) at the same size, with a short note on what is still missing. Reference stills are kept out of the repo (review only).
- **Web:** the numbers in the web budget, measured on the live Pages build in Chrome, are reported alongside the gif.

**Gate:** a Pages URL showing the character idle, walking and playing a punch, kick, hit and KO cycle under keyboard control, with FPS and build size reported. Owner verdict on the look. If the look or the budget fails, adjust the recipe here, not later.

### G1: Vertical slice (2 fighters, 1 stage)
- Two fighters, each with a move list in data and a MOVES.md entry. The second may be a re-dressed, re-palette sibling of the first if the owner agrees.
- Box editor (`tools/box_editor.tscn`, debug only) over the side-view pose, saving boxes to fighter JSON. A test asserts derived startup/active/recovery match MOVES.md within 1 tick.
- Stage 1, the airship deck: a kit-built mid plane, a painted far plane, moving parts and the fixed camera.
- Placeholder HUD in Theme. Tests: hit, block and crouch outcomes, chain rules, scaling, round and KO flow, deterministic replay, a 200-match soak.
- **Gate:** the owner plays two real fighters on a real stage in the browser.

### G2: Feel, FX and CPU
- Hitstop, screen shake (half amplitude on non-final hits), impact frames, onomatopoeia popups, steam, spark and shockwave FX, KO slow-mo with a palette shift, smear frames on heavy hits.
- SFX and announcer through audio buses (Master, Music, SFX, Voice).
- CPU tiers 1 to 8 per GAME_DESIGN section 7 (v1 `src/ai/ai.js` is the behaviour reference). Tier 8 beats tier 2 in at least 80% of matches. Training mode with a box overlay (F2).
- **Gate:** an owner playtest against the CPU in the browser.

### G3: Front end
- Title (logo, key art), mode select, character select (portraits), stage select, controls screen, F1 sheet, pause and options, the final HUD from the generated kit, music per screen.
- **Gate:** title to win screen to rematch, mouse-free, on the web build.

### G4: Content
- Fighters 3 to 6 (a roster of 6), stage 2 (the clocktower interior) and more as budget allows, specials and projectiles, win poses and intros, throws where a grab clip exists.
- **Gate:** every pairing within 40 to 60% over 500 CPU-vs-CPU tier-6 matches, all inside the web budget.

### G5: Ship
- Load-time polish (lazy-load stages and fighters), audio unlock, focus handling, optional touch controls, README with a gif and credits, portfolio banner.
- **Parity with v1:** every v1 mode, CPU 1 to 8, remappable controls, rounds and KO, and visuals clearly better (owner verdict). Then archive v1.

## Roles
The orchestrator owns this plan, MOVES.md, ASSETS.md, ART_DIRECTION.md and ART_PROMPTS.md, reviews gate evidence and gives rulings. The builder implements one phase at a time, commits only its own files, sends evidence at each gate, and never asks the owner to relay.

## Risks
| Risk | Mitigation |
|---|---|
| VRM models are too heavy for the web | VRoid's reduced-poly export, decimation in Blender, 1024 px textures, importer baked out. Measured at A0. |
| The toon look is weak without post-process edges | Inverted hull, screentone and stepped animation carry it. Depth/normal edges only if budget allows. |
| godot-vrm or retargeting misbehaves on Godot 4.7 | Verify at A0 step 1. Fallback: load the VRM as glTF (rename to .glb) and rebuild the materials ourselves. |
| Godot web limits (threads, audio unlock, memory) | The single-threaded build is already on Pages. Check every gate live. |
| Retargeted clips look off at 12 to 15 fps | Tune hold frames per move in data; add smear frames in G2. |
| Mixamo needs the owner's Adobe login | A0 starts on Quaternius; the owner downloads the Mixamo list once. |
| Style drift across 6 fighters | One shared skeleton, shader and palette-ramp rules. Concept sheets approved before modelling. |
