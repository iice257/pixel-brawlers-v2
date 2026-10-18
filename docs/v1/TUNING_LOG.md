# Tuning log

Newest first. Record every tuning decision (palettes, sizes, timings) with the final values.

## 1.2 Palettes and heads (2026-10-16)

Final values adopted per orchestrator ratification. Source of truth: `src/data/fighters/*.js` and `tools/gen/emit.mjs`.

| Group | Dark to light |
|---|---|
| Skin (all fighters so far) | `#80433d` `#ee8b75` `#f6b09a` `#fecbb2` `#fdefe1` |
| SURGE hair a-d | `#0c2250` `#0b4c80` `#1e92a0` `#3cbcc2` |
| SURGE hair accent `z` | `#8ff0f0` (sparing 1px accents) |
| BRICK hair a-d | `#9d7a1a` `#d9a82a` `#ffd84a` `#fff59a` (bible ramp; sampled values were JPEG-washed) |
| BRICK hair accent `z` | `#fffbd0` (builder choice, near the brightest sampled pixel `#fcfbce`) |
| BRICK tank (cloth A) | `#60605f` `#a9a9a9` `#d7d7d7` `#fefefe` |
| Toothpick `r` `s` | `#1d3e5d` `#5ea0c1` |
| Iris `y` | SURGE `#3b82c4`, BRICK `#4f8fc0` |
| Outline `O` | `#170c1c` |

Deviations and additions
- New glyph `z` = hair accent (brightest, sparing 1px), mapped from `palette.hairHi`. Added to `GLYPHS` in `src/gfx/palette.js`; the validator picks it up automatically. ART_BIBLE section 1 table should list it.
- Block-in tool is `tools/blockin.mjs` (size-agnostic). Per-part generators live in `tools/gen/`; `tools/gen/emit.mjs` writes the fighter data files. Re-running emit overwrites hand edits, so once a part is hand-edited, treat the fighter file as the source of truth.
- Head refinement used 1 iteration after the first re-author (SURGE: carved back tufts, neck cord; BRICK: narrower far side, taller uneven spikes, toothpick at mouth corner).

## 1.3 SURGE body parts (2026-10-16)

Part sizes (WxH), all within the ART_BIBLE rig table +-3 px. Pivots are `pivots[part] = { joint: [x,y] }`, shown as crosshairs on the viewer parts sheet.

| Part | Size | Part | Size |
|---|---|---|---|
| torso_stand | 44x36 | thigh | 19x28 |
| torso_crouch | 46x31 | shin | 15x26 |
| torso_lean (fwd) | 47x36 | foot_flat | 24x9 |
| torso_lean_back | 47x36 | foot_toe | 24x11 |
| hips | 30x14 | foot_kick | 24x10 |
| arm_upper | 15x22 | hand_fist / hand_guard | 14x13 |
| arm_fore | 13x22 | hand_open | 14x14 |

- Boots use cloth B base index 1 (`j`), so they read grey-blue under the white wraps; trim cuff `n/m/p`.
- `form()` in `tools/blockin.mjs` does the bevel shading (light upper-left); blobs and creases are placed per part in `tools/gen/surge_body.mjs`.
- Viewer: `?view=sheet|compare|parts|palettes` isolates a section, `?fighter=brick` picks the sheet fighter (use the clean URL `/viewer?...`, serve drops the query on the `.html` redirect).

## 1.4 Rig, baker, idle (2026-10-16)

- Pivot changes to hit the 96-104 px standing height (guard stance measures 103-104 px incl. hair): torso `hips` pivot y 34 -> 31 (crouch 29 -> 26), torso `neck` pivot y 3 -> 5, head `neck` pivot y 30 -> 32, thigh knee y 24 -> 22, shin ankle y 22 -> 20. Hips pivots renamed `hipF` / `hipB`.
- Limb angles are WORLD angles (not relative to the torso); upright parts (hips, torso, head) are cumulative. Convention is documented at the top of `src/gfx/rig.js`.
- Baker: alpha threshold 128, per-part 1px outline, back arm/leg x0.82, and every opaque pixel is snapped back to the palette after rotation (blended edge colours otherwise showed up: 22 stray colours -> 0).
- Feet origin = hips root column, floor = row under the lowest foot pixel (`floorGap` 1 = the foot outline row).
- Guard stance: legF h30/k45, legB h-15/k30 (feet apart), armF s45/e120/w-30 guard hand, armB s30/e60 fist poking out in front of the chest, torso variant `lean`. Idle bob is torso dy [1,1,0,0,1,1], each held 8 ticks.

## 1.5 BRICK body parts and idle
- BRICK trim palette changed (was brown/gold set): `['#1c1416','#6a4a2a','#9a6c38','#ffd84a']` = black gloves, brown boots/belt, light brown, gold buckle.
- Same 15 body parts, sizes and pivot names as SURGE except arm_upper 16x22 (bigger bicep; shoulder [8,3], elbow [8,19]) and hand grids 15 wide; torso pivots computed from shear.
- Tank torso: white `h` with grey `g/f` folds, `O` outline at neckline and armholes. Gloves are black with brown sheen row.
- BRICK idle override in poses.js: torso lean r15, head r-15 dx1, armF s30/e105, armB s15/e45, legs wider (legB h-30). Height 104, AA 0, stray colours 0 (same as SURGE).
- Not done: SURGE thigh/shin polish (low priority).

## 1.6 Locomotion poses and anims (+ part polish)
- Polish: `form()` highlight blobs are now one 2x2/2x3 rectangle per form, top-left only (was plus/diamond blobs everywhere). Hips are drawn above the torso (DEFAULT_Z: torso, then hips) so the belt/buckle shows. hand_guard redrawn for both fighters (horizontal finger rolls, knuckle ridge on the leading side, thumb wrap). SURGE feet: white sole + dark edge, toe-cap seam, lace dots, ankle cuff. SURGE thigh/shin: vastus cuts, knee cap, calf cuts, spiral shin wrap.
- Poses (src/gfx/poses.js, library via `poseLibrary(fighterId)`): idle_0..5, walk_f_0..7, walk_b_0..7 (walk_b = walk_f cycle reversed), crouch_in_0/1, crouch_hold_0, crouch_out_0/1, jump_prep/rise/apex/fall_0-1/land, jump_f_0..3, jump_b_0..3, dash_f_0..2, dash_b_0..2. BRICK gets a loco style tweak (torso +15, head -15 dx1, front arm -15).
- Walk: legF phase i*45, h +-30, knee lifts on the forward swing, arms contrapass, torso rocks 15 at passing poses (head counter-tilts -15 to keep height). Heights 103-108 (idle 103-104).
- Crouch hold: hips r45, torso crouch r30, head r-45, legF h105 k135, legB h75 k150. Height SURGE 63, BRICK 58 (target ~62; the root dy idea does not apply because the baker floors the sprite at the lowest foot).
- Timing in src/data/anims.js (walk_f 5 ticks, walk_b 6, crouch 3 per pose, dash_f 5/5/4, dash_b 5/7/4, jump_f/b 9 ticks per pose then hold).
- Rotation: no pre-rotated variant parts yet; 15-45 degree limbs in walk/dash look acceptable at 2x (some stair-stepping on thin parts). Revisit if attacks show jaggies.
- tools/posecheck.mjs: headless silhouette inspector (height, x extent, reach in a hitbox band).

## 1.7 Attack poses, reach checks and smears

- 45 attack poses per fighter (LP/HP/LK/HK, 2LP/2LK/2HP/2HK, jLP/jHP/jLK/jHK, throw) in `src/gfx/poses_attacks.js`; anims, S/A/R and hitboxes in `src/data/anims.js`. The extended pose is held for the active ticks.
- Reach check: tip of the attacking limb group only (`limb` in anim data) vs hitbox far edge, within 4px. Viewer coverage panel shows a PASS/FAIL per attack and per fighter: ALL GREEN. Headless twin: `node tools/reachcheck.mjs`.
- Pre-rotated variant parts (arm_punch / leg_kick): none needed. Everything is reached by rig angles.
- Brick-only fixes (`BRICK_FIX` in poses.js): LK_1 leg h75 (shorter legs vs his 46 box), jLP_1 arm 75/60 (longer arms).
- Root lunges to reach: HK_2 +6, 2LK_1 +6, 2HK_2 +16, 2HP_2 +6. 2LP needed a lean-back torso.
- Throw: GAME_DESIGN range 34 is not reachable with natural grab arms (arm length gives ~59). Throw hitbox far edge set to 59 and flagged for the orchestrator.
- Smears (`pose.fx` arcs) on HP_2, HK_2, 2HP_2, 2HK_2. 2HK_2's arc is mostly clipped by the foot tip and reads as a small blob.
- Contact sheet cells widened (140px) so extended limbs are not clipped. Sheet: `media/qa/phase1-1.7-contact.png`.

## 1.8 Reaction, KO, win and intro poses

- New: `src/gfx/poses_react.js` (block, hit_high/low/body, hit_air, knockdown, lying, getup, ko, thrown, win_a/b, intro, taunt) and the anims in `src/data/anims.js`. `REQUIRED` there lists every ART_BIBLE section 6 animation; the viewer coverage panel prints MISSING rows in red.
- Throw reach now 42 (orchestrator decision): grab arms bent with elbows tucked (armF 0/90, armB -15/90), no lean, root dx 0 -> tip 44/45. Throw hitbox far edge 42.
- Heads: `head_hit` (brow pinched, eyes shut, mouth open with gritted teeth) and `head_ko` (X eyes, slack mouth) for both fighters, derived from the neutral head in `tools/gen/heads_react.mjs`. Head tilts kept to -15 so the face stays readable at 1x.
- Pre-rotated parts: `torso_fallen` and `hips_fallen` (new rig variant `hips.v`). They are the standing parts with every third column dropped (`tools/gen/fallen.mjs`), so a 90 degree rotation gives a lying body about 28px thick instead of the 44px chest. Rotation is lossless at 90.
- `floor: 'body'` on a pose makes the sprite origin the row under the lowest drawn pixel (lying / tumbling poses have no foot on the ground). Used by hit_air, knockdown, lying, getup_0/1, ko_1..4, thrown.
- Lying height: ~48px counting the upright feet (fr 90) and arms; the body itself is ~28px. Engine hurtbox for lying comes from move data (GAME_DESIGN), not the sprite.
- 2HK smear is now a big 3-tone arc ahead of the foot, fully visible. No pre-rotated leg_kick needed: the 60-75 degree jaggies are not noticeable at 3x.
- Weak spots: surge intro_0 "arms crossed" reads as a relaxed stance; true back-turned intro is not possible with front/side-only parts. win_a_2 back arm tucks behind the head.

## 1.9 Viewer player, tuner and sheet export

- Player (`?view=anim`): scrub slider + tick readout, speed 0.25x-2x, loop toggle, flip, onion skin (prev/next frame at 30%), floor line, hurtbox/hitbox overlay (GAME_DESIGN 2.2 placeholder boxes, `boxes=1`), joint dots (`joints=1`).
- Pose tuner (`tuner=1&pose=<name>`): select a pose, click a joint dot, `[` / `]` rotate by 15 degrees, arrows move the root, number keys cycle part variants, "copy pose JSON" yields an object that pastes straight into `poses.js`. Proven once with a test edit (pasted back, rendered identically), then reverted.
- Coverage panel: MISSING anims in red, plus per-animation total-ticks columns for surge and brick. Status: ALL GREEN.
- Contact sheet export button (`export=1`, `only=<regex>`, `cols=N`). Headless recipe: `msedge --headless --dump-dom "<viewer url>&view=contact&export=1&save=0"`, then pull the data URL out of `#sheetData`. Sheet: `media/qa/phase1-1.9-contact.png`.

## 1.10-1.12 Portraits, key art and Phase 1 gate

- Portraits are 96x96 masters in `portrait.rows` of each fighter file (plus `portrait.hudCrop`, a 32x32 face rect), generated by `tools/gen/portrait_surge.mjs` / `portrait_brick.mjs` with helpers in `portrait_lib.mjs` (polygon forms, ASCII stamps, silhouette outline). Authored in the reference's orientation and reference-grid coordinates; SURGE is mirrored at the end so he faces right.
- Reference scale: 1 portrait pixel ~ 5.2 source px, so the reference is roughly a 160x98 grid. `tools/refgrid.py` crops the reference in portrait-grid units with a labelled grid (dev aid for measuring features).
- Viewer: `?view=portrait&fighter=surge|brick` (1x/2x/4x, `grid=1`, `hud=1`, `both=1`) beside the same-height reference crop; `?view=keyart` composes both on a 160x98 grid at 2x with a 4-step dithered additive glow disc each (cyan SURGE, gold BRICK).
- Key art: SURGE is flipped back to face left as in the reference. The reference has SURGE's big near shoulder in FRONT of the blond's tank, so SURGE's body (below the neck) is redrawn over BRICK; heads keep SURGE behind BRICK.
- Phase 1 gate fixes: surge intro_0 is now a guard-up neck crack (arms-crossed moved to intro_5), win_a_2 back arm raised clear of the head, spiky tufts on SURGE's hair.

## 2.1 Input layer

- Pure part in `src/core/buffer.js` (SOCD, numpad dir, facing flip, 90-tick ring, 5-tick press buffer, simultaneous window, double-tap); DOM part in `src/core/input.js`. Buffer state is plain data so the world stays serialisable.
- "Within 3 ticks" is implemented as press ticks at most 3 apart (inclusive). Double tap: two press edges at most 12 ticks apart.
- Gamepad conflict in section 1: RB was listed both as block and as the LP+LK throw macro. Chosen: LB (4) = block, RB (5) = LP+LK. Start (9) = pause. Solo mode lets P1 read both keyboard layouts.
- Test command is `npm test` (= `node --test tests/*.test.mjs`); a bare directory argument (`node --test tests/`) does not work on Node 24.

## 2.2 Moves schema and frame data

- Data: `src/data/moves-template.js` (TEMPLATE + FIGHTER_MOVES), helpers in `src/engine/moves.js`, table at `/framedata.html`. Fighter stats live in `src/data/stats.js` (fighter art files are generated and would be overwritten).
- Block stun for HK 14, 2HP 12, 2HK 12 is derived from the doc's block advantage (-7, -11, -12) because the table gives no bs for them. jHK bs is not in the spec: set to 14 (above jHP's 12, equal to HK).
- Air normals: `recovery: 0` with `landLag: 3` (whiff landing lag), so S/A match the anim tables. Air pushback uses the single table value for both hit and block.
- Throw: throwRange 42; the anim hitbox in `anims.js` is the arm band used by the viewer reach check, so the test only compares its far edge with the range.
- Derived advantages for modified fighters (not in the doc): SURGE HP +5/-3, BRICK HP +3/-5, BRICK 2HP block -12 (doc normal 2HP -11).

## 2.3 Locomotion, boxes and camera

- Engine: `src/engine/{fighter,world,camera}.js`. Debug scene at `/?new=1` (`boxes=1`, `panel=1`, `dummy=1`, `p1=`, `p2=`, `shot=loco` for the QA still); F2 boxes, F3 stats, R reset. Legacy stays at `/`.
- Dash velocity is `v0 * 0.95^st` (`stats.js` dashF v0 4.4, dashB v0 3.6). The decay is not in the spec: it gives about 45px forward in 14 ticks and 40px back in 16. Dash actionable at tick 8; back dash strike invulnerable on ticks 1-6.
- Jump integration `y += vy - g/2; vy -= g` with vy0 8, g 0.41 lands exactly on apex 78 and 39 airborne ticks. Jump x speed forward 2.6, back -2.2 (BRICK x0.97 on vy and vx). Prejump 3 ticks; landing anim 3 ticks and not a lock.
- Crouch in/out 6 ticks each (anim only, never blocks input). Facing turns only when grounded and actionable, so cross-ups hold their facing until landing.
- Pushboxes: grounded overlap splits evenly, a wall-clamped fighter's share goes to the other, airborne bodies push 1px/tick apart. Max separation 296 pulls back whoever moved away. Camera ease 0.18, lift up to 14px (full at height 78), render position rounded.
- Baker: `bakeOp` now processes only a square region around the joint (pixel-identity checked on all 276 poses of both fighters: 0 differences, about 2x faster). The fight scene bakes idle at boot and the other locomotion poses in 5ms slices per frame (boot 150ms instead of 4s); anything not ready yet bakes on demand.

## 2.4 Attacks, hit resolution, blocking, reactions

- Files: `src/engine/combat.js` (hit detection and resolution), attack/reaction states in `fighter.js`, `src/ui/hud.js` (health bars). Tests in `tests/combat.test.mjs` with the scripted-input helper `tests/helpers.mjs` (`run(w, n, p1Frames, p2Frames)`, sparse "hold until next key" inputs).
- Pushback: the table's PB is read as the initial speed in px/tick and decays by 0.86 per tick (GAME_DESIGN 2.1), so LP slides about 16px, HK about 50px.
- Corner push: GAME_DESIGN 2.1 says the attacker is pushed back by 60% of the defender's lost pushback, the Phase 2 brief says 40%. Implemented 40% (`CORNER_SHARE`); one constant to change.
- Hitstop: both fighters freeze for the move's value (light 7, heavy 10); blocked is 2 less. The input buffer keeps recording while frozen, so buffered presses survive hitstop.
- Advantage is measured, not assumed: the test runs every grounded normal for both fighters on hit and on block and compares the tick each fighter leaves its move/stun with `advantage()`.
- Guard: BL held, or holding back; holding back only auto-guards while an attack is in startup/active within 90px (otherwise it is a walk). The side test uses the screen-space stick against the attacker's current side, so cross-ups swap the needed direction on the same tick. H/O need stand block, L needs crouch block, M either.
- Air hits: a jump-in that hits an airborne defender knocks them down softly (vx 2.0, vy 3.0; not in the spec). A defender in a launch arc cannot be hit until juggles arrive in 2.7.
- Air normals: hitbox active S+1..S+A only; the move ends on landing (3 ticks of landing lag if nothing connected). The spec's "deep hit +2 hitstun" is not implemented yet.
- Not done on purpose: per-move hurtbox overrides (2HP legs-only shrink), meter, chip (0 for normals anyway).
- Baker (again): z-order compositing now happens in a pixel buffer instead of through two canvases. Pixel-identical to the previous baker on all 276 poses, about 13 ms per pose (was 23). The fight scene now queues every anim for slice baking, locomotion first.

## 2.5 Throws, knockdown, wakeup, tech

- **Throw input:** LP+LK pressed within `SIMUL_WINDOW` (3 ticks) of each other. A lone LP/LK jab converts to the throw if the other button arrives while the jab is still in its first `SIMUL_WINDOW+1` move ticks (leniency, so a slightly late second button still grabs).
- **Reach:** throw box is `[0,0,42,80]` tested against the defender's pushbox, so it connects up to 53px centre to centre (gap 53 grabs, 54 whiffs). The doc's 42 is a box width, not a centre distance; flagged.
- **Whiff:** startup 5, active 2, 24 total recovery (attacker free on tick index 31).
- **Tech:** defender LP+LK (pressed together, after the grab) within 7 ticks; 8 fails. Both pushed 28px apart (vx 3.5 for 8 ticks), no damage, neutral after 20. Two throws on the same tick tech each other.
- **No throw hitstop.** The data says 12 hitstop, which would swallow the 7-tick tech window; the grab-hold itself is the pause.
- **Damage** is applied at tick 8 after the grab (once the tech window closes): `round(100*pwr*def)`, no combo scaling. Hard knockdown.
- **Timeline:** defender held and locked to the attacker for 14 ticks, then released as a launch (vx 2.0, vy 3.5); attacker free 24 ticks after the grab.
- **Back throw** (hold back): defender lerps from front to behind over ticks 4..13 and lands behind; sides swap. "Swap sides" reads this way.
- **Knockdown:** lie 34 hard / 22 soft, getup 22 ticks. Wakeup invulnerable for the first 3 ticks (6 for quick-rise); the entry tick of getup counts.
- **Quick-rise:** any 2 presses, or direction + 1 press, with age < 3 on the landing tick. Roll back 28px, lie 8.
- **Lying hurtbox** `{-30,0,60,16}`: only hitboxes whose bottom is below y=8 connect.
- **Throw box** shows as yellow in the F2 overlay.

## 2.6 Rounds, timer, KO, announcer, HUD v0

- **State machine** lives in `src/engine/match.js` (pure, in `world.match`): intro 90 → ROUND N 72 → FIGHT 30 (inputs unlock on the first FIGHT tick) → play. Fighters get neutral input in every phase except fight/play. `createWorld({match:true|1|3|5})`; without `match` the bare sim runs as before (all older tests use it).
- **Timer** 99, one per 60 ticks of fight/play (it keeps running through hitstop and throws, stops at KO).
- **KO:** the tick the final blow lands the round ends, both fighters get 24 ticks of hitstop, then 40 ticks of slow-mo (fighters, hits and the throw run every 4th tick; camera every tick). Then 90 ticks of "post" (PERFECT/DRAW text), then the next round.
- **Time over:** higher HP percentage wins, equal is a draw (both +1). "TIME UP" 60 ticks.
- **Double KO** = draw round, both +1. **PERFECT** = winner's `dmgTaken` is 0 for the round.
- **Match end:** a side has `need` wins (1/3/5 → 1/2/3) and the wins differ. 1-1 after a draw plays on. Safety cap: at round `2*need+1` still level → "DRAW GAME" (not in the doc).
- **Between rounds:** fresh fighters 80px apart around the centre, full HP, meter retained (`f.meter`, nothing writes it yet). Round 1 only has the intro.
- **Result screen:** "P1 WINS" + name + PRESS ENTER; Enter starts a fresh match (there is no temp menu yet, so a rematch is the stand-in).
- **HUD v0** (`src/ui/hud.js`): bars with the 28-tick-hold yellow lag bar, names, `need` round pips per side, centre timer (16px, blinks red at ≤10), announcer with the ART_BIBLE 9 gradient text (24px, 2px outline, 2px drop shadow, 150%→100% pop in 8 ticks). "FINAL ROUND" when both sides are one win from the match.
- **Not done:** winner pose and intro animation (no art in the anim set, fighters stand idle), HUD restyle (6.1), round-count picker.
- **`__debug`:** `setHP(p,n)`, `setTimer(n)`, `setMeter(p,n)`, `forceKO(p)`. URL params: `?rounds=1|3|5`, `?match=0` (bare sandbox), QA stills `?shot=hud|ko|over`.

## 2.6b Orchestrator rulings applied
- Throw reach is 46px centre to centre (`throwRange`, box far edge 46); gap 46 grabs, 47 whiffs.
- Throw pair choreography is data (`THROW_PAIR` in `data/anims.js`): victim at +34/28 up (thrown_0), arcing over to +46/40, landing at +60 on release; back throw mirrors the x offset over ticks 4..13.
- KO pacing is config (`KO_PACE` in `config2.js`): normal 24 hitstop / 24 slow / 60 post, match-deciding 24 / 40 / 90.
- Round-1 intro plays the `intro` anim on both fighters; the winner plays `win_a`/`win_b` (picked from the world RNG when the round ends); the loser stays in `ko`/`lying`.
- Sprite bake priority: idle/walk/jump, normals, reactions, rest.

## 2.7 Chains, cancels, combos, juggle, scaling

- **Chain cancel** (`fighter.tryCancel`): the move must have a `chain` cancel (LP, LK, 2LP, 2LK; heavies finish the chain), have connected (hit or block), and be inside first active tick .. recovery tick 5. The next normal must be a *different* one, same weight or heavier, not already in `f.chain`, ground only; max `CHAIN_MAX` = 4 normals. GAME_DESIGN's example "LP -> LP -> 2LP -> HP" repeats LP, which its own "each normal once" rule forbids; I followed the rule (LP > 2LP > HP works, LP > LP does not).
- **Special cancel plumbing** (`engine/specials.js`): moves flagged `special`/`super` look for a registered special whose input matches, within first active tick .. recovery tick 6, on hit or block; meter cost is deducted. The list is empty until 3.x; the test registers a fake special.
- **Combo state** lives on the defender (`f.cb = {n, dmg, juggle, end, t}`). Only hits count (a blocked string is not a combo). It ends when the victim is actionable, lying, getting up or KO'd; a fresh hit afterwards starts a new combo at 100%.
- **Scaling** `[100,90,80,70,60,50,40,40...]%`, floor 30% (supers 50% via `hit.super`), applied to `round(dmg * pwr * def * scale)`. Throws stay fixed damage. Hitstun x0.85 from hit 4, x0.7 from hit 7 (not cumulative).
- **Juggle:** a launching hit gives the victim `juggleStart` (2HP: 3) or 3 for hard-KD launches (2HK); soft-KD launchers (HK, jHK) open no juggle. Hitting a launched victim costs `juggleCost`; a hit needs points >= cost (supers need 1 and spend none). Juggle hits re-launch with the air-hit arc and keep a hard knockdown. A KO'd or thrown victim cannot be juggled.
- **Combo counter UI:** "N" + "HITS" + "DMG n" on the victim's side, pops each hit, holds 40 ticks after the combo ends (fades over the last 10).
- **Not done:** jump cancel (stretch), meter gain from hits (the doc's meter section is not in 2.7).

## 2.8 FX

- Engine stays pure: `combat.apply` / `stepThrow` push `{type:'hit'|'ko', x, y, level, dmg, block, heavy, by, to, dir, tick}` onto `world.events` (cleared at the start of every `stepSim`). Hit point = midpoint of the hitbox/hurtbox overlap; throws use the defender's chest.
- `src/gfx/fx.js` consumes events after each sim step (`tickFx`), so FX are tick-accurate and freeze with hitstop. Fixed pool of 128 slots, recycled oldest-first, no allocation per frame.
- Sparks: light 4 ticks, heavy 8 ticks (+6 sparks), block 5 ticks (+3 shards). Heavy = hitstop >= 10.
- Defender tint: white 2 ticks, then red 4. Blocks do not tint.
- Shake: amp = clamp(dmg/12, 1, 6), ticks = max(2, round(dmg/6)); block 1px/2 ticks; KO 8px/30 ticks. `FX_OPTIONS.shake` = off | low (50%) | full. Applied to stage, fighters and FX, not the HUD.
- Dust (walk start, dash, jump, landing, knockdown slam) and afterimages (3 ghosts, 8 ticks) are derived renderer-side from state changes.
- Measured sim + FX cost: ~0.01 ms per tick in node (budget 4 ms).
- Stills: `media/qa/phase2-2.8-fx.png` (heavy hit), `phase2-2.8-fxblock.png` (block).

## 2.9 Phase 2 gate

- `/` now boots the new engine. Bare `/` shows the temporary menu (`src/ui/menu.js`): VERSUS 2P, VS CPU (dummy), TRAINING (stub, sandbox sim with a dummy), LEGACY GAME (`?legacy=1`). Any QA param (`p1`, `p2`, `shot`, `match`, `dummy`, `rounds`) skips the menu. Esc in a match returns to it.
- `tests/soak.test.mjs`: 300 seeded random-pad matches (best of 3, all four SURGE/BRICK pairings), no exceptions, no non-finite state, every match over within 20000 ticks. Longest run: 18516 ticks. The pad is `src/ui/qa_pad.js`, biased toward the opponent: an unbiased random pad stalls and rounds run out the 99 s clock (a drawn round gives both sides a win), so a 5-round match legitimately passes 20000 ticks.
- `media/gameplay.gif`: 10 s, 12 fps, frames from `?shot=replay&seed=3&tick=N` (headless Edge screenshots, ffmpeg).

## R1 Controls, modes, CPU

- New layout (see README): P1/solo WASD + U I / J K + Space block + O throw; P2 arrows + numpad. Solo modes read every layout and every pad. Bindings are remappable and saved (`src/core/bindings.js`, `src/core/save.js`); conflicts are flagged per profile and across P1/P2. Presets: STANDARD, LEFT-HAND, ARROW-ONLY.
- `src/ui/modes.js` turns the menu config into one raw input pair per tick (versus, cpu, watch, training, qa dummy). Training: Tab swaps the controlled fighter, dummy stand/crouch/jump/block/cpu, infinite health (never below 250, refills after 40 calm ticks), boxes on, input history.
- CPU (`src/ai/ai.js`, `src/data/ai.js`): tiers 1-8 (Easy 1-2, Normal 3-4, Hard 5-6, Brutal 7-8). Perception is the opponent's visible state delayed by `reaction` ticks (28 down to 6); it never reads input buffers. Neutral play comes from the `AI_ACTIONS` registry; reactions: block by hit level, anti-air 2HP, punish by recovery, chain on contact, throw tech, quick rise.
- Measured: 8 beats 2 in 10/10; 3v1 0.70, 5v3 0.67, 7v5 0.92 over 60 matches. `tests/ai.test.mjs` asserts tier 8 beats tier 2 in >= 80% of 30 matches and soaks 8 tier pairs x 20 matches.
- F1 cheat sheet is on for the first 3 finished matches (counter saved). The page hint line is generated from the live bindings.
- Poses now bake behind a loading bar (276 poses for a SURGE/BRICK pair) so the first fight does not hitch.
- Shake: heavy non-block hits now shake at half amplitude (3 px at most); KO still 8 px.
- Stills: `media/qa/R1-*.png` (menu, setup, controls, training, pause).
