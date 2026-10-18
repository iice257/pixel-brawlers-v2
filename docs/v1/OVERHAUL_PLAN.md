# Overhaul Plan (post-playtest, 2026-10-17)

Owner playtested the 2.6 build. Verdict: gameplay is fine; **controls are unintuitive**; **characters look wonky** (not acceptable); **background and UI look bad**; wants **both players controllable nicely** and a **CPU opponent**. This plan re-orders the work: it overrides the order in `BUILD_PLAN.md` (Phases 3-8 resume after it; Phase 5 stage tasks and 6.1 HUD are pulled forward in a better form).

New order: **R1 controls + modes + CPU -> R2 character render overhaul -> R3 first real stage + HUD/UI -> R4 resume Phase 3 (specials/meter) -> remaining stages/screens/audio**.

---

## R1: Controls, modes, CPU (do right after 2.9)

### Diagnosis
Punches were on the bottom row (J K) and kicks on the top row (U I): the opposite of the SF/MK mental model. Block was on L. P2's keys were punctuation. There was no on-screen reminder and no way to remap.

### New default layout (keyboard)

Mental model: **top row of the right-hand cluster = punches, bottom row = kicks, thumb = block** (SF/MK keyboard habit).

| | Solo / P1 | P2 (shared keyboard) |
|---|---|---|
| Move | **W A S D** | **Arrow keys** |
| Light Punch / Heavy Punch | **U / I** | **Numpad 4 / 5** (alt: **[ / ]**) |
| Light Kick / Heavy Kick | **J / K** | **Numpad 1 / 2** (alt: **; / '**) |
| Block | **Space** (alt: **L**) | **Numpad 0** (alt: **/**) |
| Throw | **O** (macro for LP+LK) | **Numpad 3** (alt: **.**) |
| Pause | Esc / P | |

- In single-player modes (VS CPU, Training), **both** the P1 layout AND the arrow-key layout (arrows + `Z X C V` = LP HP LK HK, `B`/Shift = block, `N` throw) control the human, so right-handed or left-handed players are both fine.
- Gamepad: first pad = P1, second = P2 (or the only pad = whoever is human in CPU mode); layout: D-pad/stick move, X LP, Y HP, A LK, B HK, LB or RB block, RT or LT throw, Start pause. Gamepad plugged in mid-menu is detected and shown.
- **Controls screen** (from main menu and pause menu): shows the active layout as a keyboard diagram (not a text list), per player; press a button to rebind that action; presets "Standard / Left-hand / Arrow-only"; saved in `localStorage` (`src/core/save.js`). A conflict (same key on two actions) is flagged red.
- **On-screen cheat sheet**: small translucent footer in the fight showing the current P1/P2 key map; toggled with F1 (default ON for the first 3 matches, then OFF), also shown in the pause menu.
- The in-page hint line under the canvas must be generated from the actual bindings, never hardcoded.

### Modes (temporary menu is fine, but make it clear and navigable by keyboard/gamepad)
1. **VS CPU**: pick your fighter, pick CPU fighter (or random), pick **difficulty 1-8** (labels Easy / Normal / Hard / Brutal for 2/4/6/8 plus the numeric tier), rounds 1/3/5.
2. **2 PLAYERS** (local): both pick; P1 left layout, P2 right layout, or gamepads.
3. **TRAINING**: one human; **Tab swaps which fighter you control** (the other becomes a dummy); dummy modes: stand / crouch / jump / block-all / CPU (tier 1-8) / record-and-replay (record 8 s of the other fighter's inputs with R, replay loop with T) **[nice to have]**; infinite HP, hitbox overlay on, input history.
4. **WATCH** (CPU vs CPU) **[nice, cheap once the AI exists]**.
Plus the Controls screen and LEGACY.

### CPU AI (pull 6.5 forward, scaled to the moves that exist)
Implement per GAME_DESIGN section 7: perception -> intent -> scripted input sequences, same `{dir,buttons}` output as a human, reaction delay by tier, the tier table (1-8). Available moves now: normals, throws, block, jump, dash; design the action library so specials slot in later (`AI_ACTIONS` registry). Style knobs per fighter in data (`ai: {idealRange, aggression, jumpiness}`): SURGE aggressive/close, BRICK mid-range poker with overheads.
Must-haves: spacing walk to ideal range, poke on whiff-bait, block with the tier's skill (stand/crouch chosen by incoming level), anti-air with 2HP, throw when opponent blocks too much, punish unsafe moves on block, wake-up behaviour (block/back-dash), no infinite loops (stuck-in-corner timeout), never inputs impossible states. Never reads the opponent's *current-tick* inputs.
Tests: `tests/ai.test.mjs`: AI-vs-AI soak (100 matches per tier pair, no exceptions, all end), tier 8 beats tier 2 in >= 80% of 30 matches, tier ordering monotone (win-rate matrix roughly increasing).

---

## R2: Character render overhaul ("no more wonky")

### Diagnosis (from the viewer, walk_f at 3x)
The "doll of rotated parts" look: every joint (hip, knee, ankle, shoulder, elbow, wrist) is a separately rotated sprite with its own 1px outline, so limbs show seams and notches at every bend; legs are spindly cylinders under a huge torso; feet are tiny wedges; rotation steps (15 deg) make limbs pop; arm-over-torso outlines are heavy blocks. Idle looks okay, motion looks broken. The reference art reads as *continuous organic muscle forms*, not segmented puppets.

### Decision
Keep hand-pixeled **head, torso, hands, feet, hips** (they are the identity and look good), but **stop building arms and legs from rotated bitmaps**. Render each limb **procedurally as one continuous cel-shaded form** per pose:

**Limb renderer (src/gfx/limb.js)**
- A limb = 2 bones (upper+lower) from the pose angles (same pose schema, same angle meaning, no 15-degree quantisation needed: use any angle, round the *positions* to the pixel grid after the fact).
- Silhouette: union of two tapered capsules plus a round joint cap at the elbow/knee, sampled per pixel at pixel centres (no AA). Thickness profile along each bone (per-fighter data), e.g. arm: shoulder 17 -> bicep bulge 18 at t=.35 -> elbow 13 -> forearm 14 at t=.35 -> wrist 10; leg: hip 22 -> quad bulge 23 at t=.3 -> knee 16 -> calf bulge 18 at t=.3 -> ankle 11. Parameters live in the fighter's `rig.limbs` data and are tuned in the viewer.
- Cel shading from the pixel's depth into the shape and edge normal vs light direction `L = (-0.6, -0.8)`: shadow band 2 px on the lower-right edges (tone 2), 1px accent (tone 1) at the extreme lower-right and where the limb overlaps something, lit band (tone 4) 1-2 px on the upper-left edges, highlight blob (tone 5, 3x2 px) at (t=.3, across=-.35) on each bone, muscle seam (1px tone-2 line along the inner side from t=.45 to .85 on upper arm and calf, plus a knee/elbow crease dot). Hard thresholds, no gradients, no dithering. Skin ramp from the fighter palette.
- Bands along the bone parameter t: wraps (SURGE forearm and shin: white with diagonal 1px grey stripes), armband, cuffs, jeans (BRICK legs: denim ramp, fold lines, rolled cuff), boot shaft; defined in `rig.limbs.<limb>.bands` as `{from,to,ramp,pattern}` so BRICK's jeans are full-length fabric and SURGE's legs are bare skin + wraps.
- Hands/feet stay as hand-pixeled sprites rotated to the wrist/ankle angle (multiples of 15, small parts), attached with a 2 px overlap and a blend ring so the join is invisible.
- Outline: the **whole limb** is outlined once as a single silhouette (+1 px `O`), drawn before the limb pixels; no outline inside the limb. Where the front arm crosses the torso an outline appears naturally (it is outside the torso silhouette). Back limbs are drawn darker (shift every tone one step down, outline unchanged).
- Proportion fixes in the same task: legs 12% thicker with visible calf, thigh and quad; shorter, wider torso-to-leg ratio (torso 36 -> 33 high, legs 6 px longer); feet 28 px wide; the hips/trunks piece wider (34); hands 16 px; remove the awkward chest-width "shelf".
- Motion fixes: apply per-frame **root bob and squash** in all locomotion anims, torso counter-rotation 10 degrees opposite to the lead leg, head lag 1 frame, and **keep the feet planted** during walk (no skating: compute stride so the foot moves 0 px relative to the floor during the plant phase).
- Torso variants stay (stand/lean/crouch/fallen), plus authored `torso_twist` (punch wind-up) if needed. Neck blend: draw a small trapezius wedge sprite between head and torso to hide the head-torso seam.

**Why this works:** no bitmap rotation means no jaggies or seams; limb shapes bend smoothly; shading is consistent in every pose; thickness profiles (muscle) are data, so the look is tuned numerically and applies to all fighters (BASALT thicker, JUNO slimmer, JUNO's legs longer). The risk (looks airbrushed/vector) is controlled by hard thresholds, 5-tone cel bands, 1px seams, and per-fighter band patterns; the builder must compare against the reference in the viewer and iterate.

**Tasks**
- **R2.1 limb renderer + SURGE arms/legs**, replace limb parts in the baker for SURGE, viewer toggle "old vs new" side-by-side; contact sheets of walk_f, walk_b, jump, LP, HP, HK, 2HK, hit_high, knockdown at 3x, old above new, saved to `media/qa/R2.1-*.png`. Orchestrator reviews before continuing.
- **R2.2 proportions + torso/hips/feet/hands rework** for SURGE: neck wedge, wider trunks, bigger feet, bigger hands, torso counter-rotation, bobs and stride planting; review sheet again.
- **R2.3 BRICK** (denim legs with folds + cuffs, arms w/ gloves) on the same renderer, review.
- **R2.4 re-check all poses**: go through the full pose list for both fighters, fix any pose that looks wrong (list failing poses in a table), regenerate the contact sheets; the *whole* set must pass visual QA.
- **R2.5 in-game animation polish**: anticipation, hold frames, hit squash, 2-tick afterimages on dashes, stride/foot-plant check by measuring foot x velocity during walk plant phase (test).
Definition of done: at 3x in motion, nobody says "wonky": limbs are continuous, feet planted, silhouettes read as heroic bruisers like the reference.

---

## R3: One real stage + HUD/UI (after R2)

### Diagnosis
The placeholder stage is a flat dark gradient with unlit box buildings: no depth, no light, no life. The HUD is flat green bars and a thin timer. The page chrome (title bar, hint line) is generic.

### Stage quality bar (SKYLINE 88, from STAGES_AND_FX 2.1; build this one stage to the full bar before any other)
- >= 8 parallax layers (sky with dithered bands + big banded retro sun/moon + stars; far skyline with lit windows; 2 mid skyline layers with **neon signs and animated billboards**; flying cars/blimp with LED text; rooftop wall with AC units, antennas with blinking red lights; the arena rooftop floor with painted lines, puddles reflecting neon (vertical dither streaks), steam vents; foreground pipes/fence silhouettes overlapping the floor edge).
- Rim lighting on fighters (cyan on the left edge, magenta on the right) via prebaked tinted copies; neon glow on the floor under signs; vignette.
- Animated: billboards (4-frame loops), flickering neon, blinking lights, searchlight sweep every 12 s, smoke/steam particles, 6-10 spectators on the far rooftop reacting (idle bob, cheer on combos, gasp on knockdown).
- Reactive: billboards flash white on heavy hits, light flicker on KO.
- Perf: prebake static layers to canvases at load; frame cost < 5 ms.
- Reference quality: it should look like a 16-bit arcade fighting stage (think layered cityscape with depth haze: far layers desaturated and lighter, near layers saturated and darker = atmospheric perspective).

### HUD/UI (6.1 pulled forward)
- Arcade-style HUD: ornate bevelled bars with gold frame, segmented glow fill with highlight strip, damage lag bar, portrait boxes with the real HUD crops (portraits exist), name plates with outline text, round gems, centre timer in an octagon/shield with big numerals, meter bars at the bottom corners (3 segments, empty until Phase 3), combo counter with gold gradient numerals.
- Announcer text with the ART_BIBLE section 9 big gradient treatment, scale-pop + letter flash.
- Page chrome: remove the generic header and hint line: full-bleed dark page with the canvas scaled to the largest integer, a slim bottom bar with controls hint (generated), fullscreen button. Pixel font Press Start 2P everywhere; 8px grid; consistent bevel panels; menu screens in the same language (title with key art comes in Phase 6 but the menu must already look consistent).
- Menus: panel with bevel and gold selection chevron, animated cursor, sound hooks.

**Tasks:** R3.1 gfx toolkit (dither, ramps, noise, bitmap text, panels); R3.2 skyline stage layers; R3.3 skyline animation/lighting/spectators; R3.4 HUD v1 + announcer; R3.5 menu/select/page chrome restyle; each ends with a screenshot of a match at 1x and fullscreen 4x for review.

---

## R4: resume

Phase 3 (motions, projectiles, specials, meter, supers, training) -> Phase 4 (JUNO/BASALT/VANTA, using the R2 limb renderer, so new fighters are cheap) -> remaining stages (harbor, temple, forge, coliseum) built to the R3 stage bar -> Phase 6 remaining (story, boss, Final Blow, select/versus) -> audio -> polish. `BUILD_PLAN.md` task IDs still apply; this document supersedes the order.
