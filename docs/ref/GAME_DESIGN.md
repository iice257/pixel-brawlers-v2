# Pixel Brawlers: Game Design (fighting system spec)

Target depth: MK1/SF2 arcade (6-button-ish moveset on a 4+1 layout), with a few modern conveniences (input buffer, one meter, training room). Everything here is original. Genre mechanics are homage, content is ours.

Conventions: 60 updates/s, fixed timestep, deterministic (no `Math.random` inside the sim; use a seeded RNG in the world state so replays/tests are repeatable). Units are internal pixels (384x216 screen, 576 px stage). `+x` = toward the fighter's facing. `y` is height above the floor (up = positive) in sim space; render converts to screen (`floorY - y`).

MVP vs stretch is tagged **[MVP]** / **[STRETCH]** on each section.

---

## 1. Controls **[MVP]**

Five buttons: Light Punch (LP), Heavy Punch (HP), Light Kick (LK), Heavy Kick (HK), Block (BL). Directions as numpad notation (facing right): 7 8 9 / 4 5 6 / 1 2 3. 6 = toward opponent, 4 = away.

| Action | Keyboard P1 | Keyboard P2 | Gamepad (standard mapping) | Touch |
|---|---|---|---|---|
| Move | W A S D | Arrow keys | D-pad / left stick (deadzone 0.35) | virtual stick, left |
| LP | J | `.` (Period) | X (index 2) | button |
| HP | K | `/` (Slash) | Y (3) | button |
| LK | U | `;` (Semicolon) | A (0) | button |
| HK | I | `'` (Quote) | B (1) | button |
| Block | L | `,` (Comma) | LB (4) or RB (5) | button |
| Throw | LP+LK together (also gamepad RB if mapped) | same | RB (5) = LP+LK macro | button "THROW" |
| Pause | Esc / P | Esc | Start (9) | pause icon |
| Solo play | P1 OR P2 layout both work in 1-player modes | | | |

- Layout logic: P1 buttons form a 2x2 under the right hand (U I over J K); P2 likewise on the home/lower rows.
- Menus: arrows/WASD move, Enter/J/Space confirm, Esc/K back; gamepad D-pad + A/B.
- **Block**: hold BL, OR hold back (4/1) while the opponent attack is in its startup/active/hit-engaged range (auto-guard like SF). Holding 1+back or BL+2 crouch-blocks.
- **Input processing**: sample once per tick into `{dir, buttons}`; keep a ring buffer of the last 90 ticks per player. Facing-relative: convert 4/6 each tick using current facing.
- SOCD cleaning: left+right = neutral(5); up+down = up (8).
- Button buffer: a button press is held for **5 ticks** and consumed by the first state that can act on it (so pre-inputs during recovery/blockstun work).
- Simultaneous presses: two buttons within **3 ticks** count as pressed together (throw LP+LK; EX = two buttons of same family).
- Prevent browser defaults for arrows/space/slash/quote; ignore input when the window is blurred; clear on blur.
- Gamepads: poll `navigator.getGamepads()` once per tick; hot-plug supported. First gamepad -> P1, second -> P2.
- Touch UI **[MVP for demo reach]**: appears only on `pointer: coarse`; semi-transparent pixel-styled stick (left) + 5 buttons (right) + pause; multi-touch via pointer events; landscape recommended (show "rotate your phone" overlay in portrait).

### 1.1 Command motions **[MVP]**

Recognised from the ring buffer (facing-relative), with leniency:

| Name | Notation | Rule |
|---|---|---|
| QCF | 2,3,6 | consecutive directions within **16 ticks** total; diagonals optional (2,6 accepted if within 8 ticks) |
| QCB | 2,1,4 | same |
| DP | 6,2,3 (or 6,3,2... accept 6,(2),3) | within 14 ticks; button must be pressed within 6 ticks of the final direction |
| HCB | 6,3,2,1,4 | within 24 ticks |
| Charge back-forward | [4]6 | hold 4/1/7 for >= **40 ticks**, then 6 within 8 ticks of releasing; charge persists 10 ticks after release |
| Charge down-up | [2]8 | hold 1/2/3 >= 40 ticks, then 7/8/9 |
| Double QCF | 2,3,6,2,3,6 | within 36 ticks |

Priority when several moves match: super > EX > special > command normal > normal. Motions are checked on the tick a button is pressed (button is the trigger). 

---

## 2. Physics, boxes, and state model **[MVP]**

### 2.1 Constants

| Quantity | Value |
|---|---|
| Stage width | 576; fighters clamped to `[16, 560]` |
| Camera | 384 wide, follows midpoint, clamped to stage |
| Max separation | 296 px (camera width - 88): a fighter at the screen edge cannot be left behind; walls are the screen edges |
| Gravity | 0.41 px/tick^2 (BASALT 0.52) |
| Jump launch vy | 8.0 (apex ~78 px, airtime ~39 ticks) |
| Jump horizontal | fwd +2.6, back -2.2 (x fighter jump mult) |
| Pre-jump | 3 ticks of crouch (jump-squat), can't be hit by throws |
| Walk | per fighter, see section 8 |
| Dash fwd | 14 ticks, 4.4 px/t initial decaying; back dash 16 ticks, 3.6 px/t, **invulnerable (strike) ticks 1-6**; double-tap 6/4 within 12 ticks, no dash from block/hit |
| Knockback decay | multiply vx by 0.86 per tick on the ground |
| Corner push | when attacker is in the corner, defender's pushback is transferred to attacker (attacker is pushed back by 40% of it) |

### 2.2 Boxes

Local space, facing right, origin at feet centre, `y` up. Box = `{x, y, w, h}` where `(x, y)` is the bottom-left corner.

- **Pushbox** (body collision, ground only): stand `{-12,0,24,92}`, crouch `{-12,0,24,60}`, air `{-10,16,20,60}` (airborne fighters do not push on the ground but they cannot pass through the opponent's head either: resolve horizontal overlap by pushing both 1 px/tick apart; if the jumper lands on the opponent's side, use cross-up logic: face updates only on landing).
- **Hurtboxes** (3 for stand, 2 for crouch, 1 for air), per *state* by default, overridden per frame in move data when the pose extends: stand head `{-9,72,20,26}` body `{-14,34,28,40}` legs `{-12,0,24,36}`; crouch head+body `{-14,26,28,34}` legs `{-14,0,28,28}`; air `{-13,18,26,66}`; knockdown `{-30,0,60,16}` (lying; only hittable by launchers/wakeup-specific rules, see 2.5).
- **Hitboxes** per move per active frame range. A move can have several `hits` (multi-hit).
- Boxes drawn in debug overlay (`F2`; in the training room it's the default): blue pushbox, green hurtboxes, red hitboxes, yellow throw box.
- **Hit detection** each tick after all movement: for each attacker hitbox vs defender hurtboxes; first overlap wins; each `hit` of a move can connect once per defender; simultaneous hits = trade (both hit, both get hitstop; if both die, double KO -> draw rule).
- **Throw box**: `{x:0, y:0, w:throwRange, h:80}` (range 42 default, BASALT 48). Throws connect only vs grounded, non-invulnerable, not in hitstun/blockstun... a defender in blockstun *can* be thrown only after blockstun ends (no tick-throw gaps > 0 beyond block recovery). Throw tech: if the defender presses LP+LK within **7 ticks** of being grabbed, both are pushed apart with 0 damage.

### 2.3 Fighter states

`idle, walk_f, walk_b, crouch, jump_up, jump_f, jump_b, dash_f, dash_b, attack(moveId), block_stand, block_crouch, hit_stand, hit_crouch, hit_air(launch), knockdown, wakeup, throwing, thrown, ko, win, intro`.

State machine rules:
- Actionable states: idle, walk, crouch, dash (after tick 8), block (when no attack engaged), jump (air actions only).
- `attack` is committed until its recovery ends, unless cancelled (2.6).
- `hit_*` = hitstun counter decrements each tick; at 0 return to idle/crouch (air -> `hit_air` until landing -> knockdown if launched).
- Hitstop (freeze) applies to attacker and defender (sim pauses those two; the rest of the world, projectiles, particles, continue). Values: light 7, heavy 10, special 11, super 14, throw 12, KO 24. Blocked: -2.
- Facing: auto-turn toward the opponent when grounded and actionable; frozen during attacks and air.

### 2.4 Hit levels and blocking **[MVP]**

| Level | Blocked by | Notes |
|---|---|---|
| High | stand-block only; **whiffs** on crouching opponents (if hurtbox drops under the hitbox) | most jump-ins, standing punches |
| Mid | stand or crouch block | most specials, HP, HK |
| Low | crouch-block only | 2LK, 2HK, sweeps |
| Overhead | stand-block only (and cannot be crouch-blocked) | command normals (f+HP etc.), 20+ startup |
| Unblockable | none | command throws, supers' final hit, boss gimmicks |

- Block requires the right facing (holding away from the attacker's *current* side; cross-ups switch sides, so block direction flips instantly on the tick the sides swap).
- Chip damage: **specials 10%, supers 15%**, normals 0. Chip never kills except supers, but can reduce to 1 HP.
- Blocking gives defender meter 10% of damage; blocked pushback bigger than hit pushback (see tables).
- Air blocking: not allowed (SF style) [except BASALT/VANTA tuning toggled in data later: stretch].
- Guard break: **[STRETCH]** none for MVP.

### 2.5 Knockdown and wakeup

| Type | Behaviour |
|---|---|
| Soft knockdown | hit_air arc small; land, 22 ticks to rise; wakeup invuln 3 ticks |
| Hard knockdown | launched (vy 5.5, vx -2.0), land and lie 34 ticks + 22 getup; cannot be hit by normals while lying except launchers' follow-up/sweep "oki" (defender lying is hittable by *low* hitboxes only; hitboxes at `y < 8`) |
| Quick-rise (tech) | press any 2 buttons (or 4-direction + button) at the tick of landing -> roll back 28 px, lying 8 ticks, wakeup invuln 6 ticks |
| Wakeup | first 3 ticks of getup fully invulnerable; moves with invuln (DP) can be used from the 3rd tick of getup |

### 2.6 Cancels, chains **[MVP]**

- **Chain (MK-style) cancels:** LP -> 2LP -> HP; LK -> 2LK -> HK (each normal once, so LP -> LP is not a chain). Rule: a normal can cancel into a *different heavier or equal-weight different* normal from its first active tick through recovery tick 5 **only on hit or block**. Weight order: LP = LK < HP < HK. Each normal appears at most once per chain. Max chain length 4. Heavy normals are not chainable (they are the chain finisher) unless flagged `cancel:['special']`.
- **Special cancels (SF-style):** flagged normals (`cancel: ['special','super']`) cancel into any special/EX/super during active or the first 6 ticks of recovery on hit or block. All 2HP/HP/2LP/LP/2LK flagged on all fighters (HK/2HK not).
- **Jump cancel:** 2HP (launcher) can be cancelled into jump on hit: allows "launch -> jump -> air combo" (stretch **[STRETCH]**).
- **Super cancel:** specials -> super on hit, costing the super meter.

### 2.7 Combos, juggles, scaling **[MVP]**

- Combo = any sequence where the defender never returned to actionable state. HUD shows "N HITS" and total damage once N >= 2, until the combo ends + 40 ticks.
- **Hitstun rules:** inherently fixed per move (the tables). In a combo, hitstun decays: hit #4+ `hitstun x 0.85`, hit #7+ `x 0.7` (prevents infinites).
- **Damage scaling** applied to each hit by its position in the combo: `[100, 90, 80, 70, 60, 50, 40, 40...]` percent; supers floor at 50%, others 30%. Final damage `round(base * scale * attackerPower)`.
- **Juggle system:** a launcher starts a juggle with **3 juggle points**. Each air hit costs `juggleCost` (light 1, heavy 2, special 2-3, super ignores the pool for its own hits but requires 1 point left). A move can hit an airborne opponent only if remaining points >= cost; when it hits, subtract. 0 points left = opponent falls ("floor bounce" none). This yields combos like `2HP (launch) -> j.. / special`.
- Proximity: same-tick multi-hit moves (supers) count each hit with scaling.
- Throws can't be comboed into/out of (no scaling reset); throw damage is fixed (no scaling) but a throw only starts a "combo" of 1.
- No-combo flags: projectiles cannot link into themselves.

### 2.8 Meter **[MVP]**

- Range 0-300 (3 bars). Persist across rounds? **No**, resets to 0 at match start; carries over between rounds (comeback).
- Gain (attacker): hit: light 6 / heavy 10 / special 18 per hit; blocked `half`; whiff 0. Gain (defender): `damage taken / 8`.
- Spend: **EX special** 100 (use the button-pair; stronger version); **Super** 200 (double motion + HP/HK per character); **Super cancel** 200; **Final Blow** none (see 5).
- Meter shown as 3 pips below health bar; flashes when >= 200.

---

## 3. Frame data **[MVP]**

Notation: `S/A/R` = startup/active/recovery ticks (first active tick is S+1). `dmg` is base damage out of 1000 HP (before character `power` and scaling). `hs/bs` = hitstun/blockstun. `Adv` = advantage = `stun - ((A-1) + R)` (contact on first active tick). `PB` = pushback in px on hit/block. `Lvl` = H/M/L/O. Move total = S+A+R.

### 3.1 Universal normals (template; per-fighter modifiers in 3.3)

| Move | Input | S/A/R | dmg | Lvl | hs/bs | Adv hit/block | PB | Hitbox (x,y,w,h) | Cancels | Notes |
|---|---|---|---|---|---|---|---|---|---|---|
| LP | 5 + LP | 4/2/6 | 30 | H | 11/8 | +4/+1 | 3/5 | 10,62,34,14 | chain, special | jab |
| HP | 5 + HP | 8/3/14 | 70 | M | 20/12 | +4/-4 | 5/7 | 8,58,42,18 | special | straight/hook |
| LK | 5 + LK | 6/3/9 | 40 | M | 15/10 | +4/-1 | 4/6 | 6,44,40,14 | chain, special | |
| HK | 5 + HK | 10/4/18 | 90 | M | KD soft | -/-7 | 8/10 | 6,50,52,22 | none | roundhouse, soft knockdown |
| 2LP | 2 + LP | 4/2/7 | 25 | M | 11/8 | +3/0 | 2/4 | 8,38,34,12 | chain, special | |
| 2LK | 2 + LK | 5/2/8 | 30 | L | 12/9 | +3/0 | 2/4 | 6,0,46,12 | chain, special | |
| 2HP | 2 + HP | 7/4/20 | 80 | M | launch | -/-11 | -/6 | 6,34,30,52 | special, jump | **uppercut launcher**; legs-only hurtbox shrink; juggle 3; anti-air |
| 2HK | 2 + HK | 9/3/22 | 60 | L | KD hard | -/-12 | 6/8 | 4,0,62,14 | none | **sweep** |
| j.LP | air LP | 5/10(or until land)/ - | 25 | H | 10/8 | | 2 | 4,20,30,30 | | |
| j.HP | air HP | 7/6/- | 60 | H | 16/12 | | 3 | 4,14,38,36 | | downward angle |
| j.LK | air LK | 4/10/- | 35 | H | 12/9 | | 2 | 2,10,36,22 | | cross-up friendly |
| j.HK | air HK | 9/6/- | 70 | H | KD soft | | 4 | 2,8,46,28 | | |
| Throw | LP+LK close | 5/2/24 whiff | 100 | T | n/a | | | throw box 42 | | hard KD, forward or back (hold 4 = back throw: swap sides) |

Air normals: recovery is landing lag of 3 ticks (whiffed) or none if they hit; `S` counts from takeoff tick. Jump-ins that land during active frames get "deep hit" +2 hitstun.

Command normals (per fighter, section 3.3): 1-2 each, with 20-26 tick startup overheads (f+HP etc.).

### 3.2 Special properties used in tables

- `inv a-b`: strike invulnerable ticks a..b (relative to move start). `armor n`: absorbs n hits (takes 50% damage, no hitstun) from tick X; EX only on most.
- Projectile fields: speed (px/t), size, `max on screen 1` per player per type, dmg, hs/bs, lifespan 150 ticks (disappears off-screen).
- EX version (cost 100, trigger by pressing both buttons of the family, e.g. LP+HP): +damage ~1.3x, extra property (invuln, armor, 2 hits).

### 3.3 Fighters

Shared stats: all have 1000 HP unless noted. `pwr` = damage multiplier on outgoing; `def` = incoming multiplier. Walk fwd/back in px/tick. Jump mult applies to vy and horizontal speed. Throw range px.

| | HP | pwr | def | walk f/b | jump | dash | throw range | height |
|---|---|---|---|---|---|---|---|---|
| SURGE | 1000 | 1.00 | 1.00 | 2.1 / 1.7 | 1.00 | 14t / fast | 42 | 100 |
| BRICK | 1000 | 1.10 | 1.00 | 1.9 / 1.6 | 0.97 | 14t | 42 | 102 |
| JUNO | 950 | 0.95 | 1.05 | 2.4 / 2.0 | 1.10 | 12t / fastest | 40 | 92 |
| BASALT | 1100 | 1.20 | 0.92 | 1.5 / 1.2 | 0.85 (gravity 0.52) | 18t / slow | 48 | 114 |
| VANTA | 1400 | 1.10 | 0.9 | 2.0 / 1.8 | 1.0 | teleport step | 44 | 112 |

Normals modifiers per fighter (override the template; unspecified = template):

**SURGE** (rushdown): LP 3/2/6 (faster), 2LP 4/2/6, HP "hook" 8/3/13, LK 6/3/9 w/ +reach, HK 10/4/17. Command normals: `6HK` "Axe Kick" overhead: S22 A3 R16, dmg 70, Lvl O, hs 22/bs 16 (adv hit +3 / block -3), hitbox `10,56,34,44`, cancel none. Throw: "Dock Toss" (forward: tosses over head; back: spin throw).
**BRICK** (power): HP 9/3/15 (dmg 80), LP 4/2/7, 2HP 8/4/21 (dmg 90). Command normals: `6HP` "Hammer Blow" overhead S24 A4 R18, dmg 90, Lvl O, hs 24/bs 17; `4HK` "Boot": S12 A3 R14 low-ish? (Lvl M) dmg 70, pushes far (PB 12). Throw: "Suplex" (forward) / "Hip Toss" (back).
**JUNO** (speed): LP 3/2/5 (dmg 25), LK 5/3/8 (dmg 35), HK 9/4/16 (dmg 80, launches on air-hit), 2HP 6/4/19. Command normals: `6LK` "Spin Heel" S14 A3 R15 dmg 50 Lvl M hs 17/bs 12 (+2 / -4), cancel special. Throw: "Rooftop Flip".
**BASALT** (grappler): LP 5/2/8 (dmg 40), HP 11/4/18 (dmg 110), LK 8/3/12 (dmg 55), HK 14/5/24 (dmg 130, KD hard), 2HP 9/4/26 launcher (dmg 110, juggle 3), 2HK 11/4/28 (dmg 80). Command normals: `6HP` "Ground Pound" overhead S26 A4 R22 dmg 120 Lvl O (also crouch-stuns: bonus 12 ticks on hit). Throw range 40: "Pile Driver" (forward, 140 dmg).
**VANTA**: universal template with +1 reach; see 3.4.

### 3.4 Special moves (4 fighters + boss). All dmg listed are base.

Motion legend: QCF 236, QCB 214, DP 623, HCB 41236, [4]6 charge, [2]8 charge, DQCF = 236236.

**SURGE: "Tide Style"**

| Move | Input | S/A/R | Properties | dmg | hs/bs | Adv hit/block | Notes |
|---|---|---|---|---|---|---|---|
| Wave Shot (L/H) | QCF+LP / QCF+HP | 13/-/28 (L), 15/-/34 (H) | projectile cyan wave, speed 3.2 / 4.6, size 18x20, spawn at `(+28,52)`, 1 on screen | 55 / 75 | 18/14 | proj | EX (100): two-hit, speed 5.2, dmg 120 total |
| Rising Tide (L/H) | DP+LP / DP+HP | 3/6/28 (L), 4/7/34 (H) | inv 1-8 (L), 1-10 (H), rises 54/72 px; hits twice (L: 40+40, H: 50+50) launch on 2nd | 80 / 100 | launch | -/-26 / -/-32 | juggle 3; EX: full inv 1-14, 3 hits, dmg 150 |
| Riptide Rush (L/H) | [4]6+LK / [4]6+HK | 10/14/14 (L), 12/18/16 (H) | slide forward 5.0 / 6.4 px/t, Lvl M, hits once | 70 / 90 (H = soft KD) | 18/14 | +0 / -8 (L), -- / -12 (H) | EX: armor 1 hit from tick 4, dmg 110 |
| **Super: Tsunami Barrage** | DQCF+HP | 8 (+30 superflash)/ 24 (7 hits)/ 30 | 7 hits x 40 base, last is hard KD, wave rush forward 4 px/t, Lvl M, unblockable last hit | ~300 total | n/a | | cost 200; inv 1-14 |

**BRICK: "Barroom Style"**

| Move | Input | S/A/R | Properties | dmg | hs/bs | Adv | Notes |
|---|---|---|---|---|---|---|---|
| Pick Shot (L/H) | QCF+LK / QCF+HK | 9/-/18 (L), 11/-/22 (H) | toothpick dart (4x2 px), speed 6.5 / 8.5, 1 on screen, small hitstun | 30 / 45 | 14/10 | proj | H version has slight upward arc (anti-air shot); EX = 3 darts fanned, dmg 30 each |
| Haymaker Lariat (L/H) | QCB+LP / QCB+HP | 12/10/22 (L), 15/12/26 (H) | advances 2.2 px/t, Lvl M, one hit | 70 / 100 | 20/12 | +0 / -13 | EX: armor 1 hit from tick 6, dmg 120, KD |
| Gut Launcher (L/H) | DP+LP / DP+HP | 4/5/28 (L), 5/6/34 (H) | inv 1-6 / 1-8; launch | 80 / 100 | launch | | juggle 3; EX inv 1-12 and 2 hits |
| **Super: Main Event** | DQCF+HK | 10 (+30 flash)/ cinematic 5 hits / 20 | on hit: 4 punches + haymaker uppercut + KD (grab-style; no combo scaling) | 320 | | | unblockable if close (range 40); whiff = long recovery 40 |

**JUNO: "Dawn Style"**

| Move | Input | S/A/R | Properties | dmg | hs/bs | Notes |
|---|---|---|---|---|---|---|
| Sun Disc (L/H) | QCF+LP / QCF+HP | 14/-/30 | projectile fire disc; L horizontal speed 2.4 wobbling +-3 px; H lobbed arc, lands at 140 px; air version (qcf+P in air) fires 45 deg down at 3.0 px/t | 50 / 65 | 17/12 | EX: 2 discs; she can walk after the throw (R is the lockout: 20) |
| Flame Spin (L/H) | QCB+LK / QCB+HK | 7/16/20 (L), 9/22/22 (H) | rising spin kick, moves forward 3.0 / 4.0 px/t, hits twice, Lvl M; ends airborne 6 ticks | 40+40 / 50+60 | 18/12 | ends at -9/-14 on block; EX: 3 hits |
| Phoenix Rise (L/H) | DP+LK / DP+HK | 5/8/32 | inv 1-7; hits 40 then 60 launch, rises 70 px | 100 | launch | juggle 3 |
| **Super: Solar Flare** | DQCF+HP | 6 (+30 flash)/ 40 / 26 | a fire pillar chases forward: 6 pillars spaced 40 px, each 30 dmg, final hard KD, screen tints orange | 270 | | inv 1-12 |

**BASALT: "Forge Style"**

| Move | Input | S/A/R | Properties | dmg | hs/bs | Notes |
|---|---|---|---|---|---|---|
| Magma Hold | HCB+LP | 5/2/32 | **command throw**, range 40, unblockable, can't be teched (but can be jumped/backdashed in startup 1-3), hard KD, stage glow | 140 | | whiffs have 30 R; EX (100): 180 dmg (+80 extra if the opponent is in the corner) |
| Lava Charge (L/H) | [4]6+LP / [4]6+HP | 14/20/20 (L) | armor 1 hit tick 6-14, advances 3.8 px/t, Lvl M | 80 / 110 | 18/12 | EX: armor 2 hits, dmg 130, KD |
| Anvil Drop | [2]8+LK / [2]8+HK | 12 (jump)/ land / 18 | high arc forward (+-70/120 px), stomp hits on landing, shockwave extends 50 px along floor (Lvl L on shockwave) | 110 | 20/12 | very unsafe on block (-20) |
| **Super: Eruption** | DQCF+HP | 12 (+30 flash)/ 40 / 40 | 3 magma columns at +40 / +100 / +160, each 3 hits of 30, last launches; screen shake 60 ticks | 330 | | inv 1-10 |

**VANTA (boss)**: not player-selectable at launch (**[STRETCH]** unlockable after beating story). AI-driven in story; moves:

| Phase | Move | Notes |
|---|---|---|
| 1 | Shadow Bolt | QCF projectile, speed 3.6, dmg 70, 1 on screen, tracks 8 px vertical at launch |
| 1 | Dusk Step | teleport to behind opponent; 8 ticks vanish (invuln), 14 ticks to reappear; telegraphed by purple smoke at destination 12 ticks before |
| 1 | Eclipse Grip | command grab, range 34, 90 dmg |
| 1 | Dive Kick | jumping HK variant, 18 startup, Lvl H, dmg 80 |
| 2 | Triple Bolt | fan of 3 bolts (angles -15, 0, +15) |
| 2 | Ground Wave | shockwave along the floor, range 200, Lvl L, jump over |
| 2 | Meteor Drop | leaps off-screen, 40-tick marker on floor (red circle), lands for 120 dmg |
| 2 | All normals +25% speed (startup -1), heavy normals gain 1-hit armor | |

Boss fight: 2 rounds win (best of 3) but with **HP 1400 and two phases**: phase transition at 50% HP in round 1 (stays unbound for round 2/3 from the start). Transition cinematic 90 ticks: music cuts, mask cracks (frame swap), shake, "UNBOUND" text, gold aura on.

### 3.5 Hit reactions

| Hit type | Stun | Effect |
|---|---|---|
| High/mid stand hit | per move | `hit_stand`: head or body variant by hitbox y (>=70 head) |
| Low hit | per move | `hit_crouch`/`hit_low` |
| Launch | air | vy +7.5, vx -2.0, `hit_air`; land -> hard KD |
| Soft KD | vy +4.5, vx -2.4 | land, lie 22 |
| Block | per move | `block_stand/crouch` ticks = bs; blockstun pushback uses PB[1] |
| KO | | final hit: launch + 24-tick hitstop, slowmo (see FX doc) |

---

## 4. Round and match structure **[MVP]**

- Match = best of 3 rounds (first to 2 wins). Option: best of 1/3/5.
- Round start: announcer "ROUND N" (1.2 s), "FIGHT!" (0.5 s), input unlocked on "FIGHT" tick. Final round: "FINAL ROUND".
- Timer: 99, decrements every 60 ticks, paused during hitstop? **No** (real clock, frozen only during supers/KO cinematics). Option: infinite.
- KO: when HP hits 0. Opponent in hitstop for 24 ticks, then slowmo (0.25x) for 40 ticks, "K.O." text, winner pose.
- Time over: higher HP% wins; equal = **draw** (both get a round win; if both are at 1 win, a sudden-death round with 50 HP each... simplified: draw both -> extra round, max 1 extra then coin-flip by remaining HP percent).
- Double KO (both HP 0 same tick) = draw round.
- "PERFECT" announcement if the winner took 0 damage; bonus score.
- Between rounds: reset positions (distance 80 px apart around stage centre), HP full, meter retained.
- Score (arcade flavour): 10 per damage point on hit, time bonus, perfect bonus, combo bonus; shown on result screen. Stored to `localStorage` high score table (3 initials) **[STRETCH]**.

---

## 5. Finisher: "FINAL BLOW" **[MVP minimal, STRETCH unique per fighter]**

Original, non-gory, flashy. When the last round's KO blow lands (the match-ending hit), the loser enters a 12-tick freeze and the screen dims: "**FINAL BLOW!**" appears with a 3.0 s window. The winner (human) can input their character's 3-input code (e.g. `2,2,6 + HP` for SURGE) to trigger a Final Blow cinematic: a short camera-zoomed sequence where the winner's signature move launches the opponent skyward (stage-themed: off the rooftop, into the harbour, into the lava glow where they pop out as a cartoon star), the opponent turns into a white silhouette that bursts into stars/coins ("KO'd out!"), the camera whips back, and "PERFECT FINISH" with score bonus x2. If the input is missed, normal victory pose. AI winners always do it. No blood, no dismemberment.

Per-fighter codes (MVP: one generic cinematic timeline parameterised by fighter FX colour and move pose set; STRETCH: unique):
SURGE `2,2,6+HP` (wave strike blasts them into the sea); BRICK `6,6,2+HK` (gut-launcher punt to the stars); JUNO `2,3,6+LP` (sun disc ascends the foe); BASALT `4,1,2+HP` (anvil slam through the floor, pops out of lava).

---

## 6. Modes and menus **[MVP]**

State graph: `boot -> title -> mainMenu -> {arcade (story), versus, training, options, credits}`; `characterSelect -> versusScreen -> fight -> {roundEnd -> fight | matchEnd -> result -> (story: next fight/ending | menu)}`.

- **Title**: logo, key art, "PRESS START" blinking, attract mode (demo fight AI vs AI after 20 s idle, loops) **[STRETCH]**.
- **Main menu**: ARCADE, VERSUS, TRAINING, OPTIONS, HOW TO PLAY. Controller-friendly.
- **Character select**: 2x2 grid of 4 portraits (+ boss hidden until unlocked and a "RANDOM" tile); P1 and P2 cursors for versus; stat bars (Power, Speed, Range, Defense), style tag, bio, animated idle preview, name plate; selecting plays a voiceless "stinger" and a flash.
- **Versus screen**: portraits slide in 2x, VS slam, names, stage name; 1.5 s.
- **Pause menu** (Esc / Start): Resume, Move List (shows the selected character's list with inputs), Controls, Restart round, Quit to menu. Freezes sim + music ducks.
- **Move List screen** doubles as in-game docs: normals, specials with notation (numpad + arrow glyphs), meter costs.
- **Options**: Master/Music/SFX volume, Difficulty (1-8 ladder or Easy/Normal/Hard/Arcade), Rounds (1/3/5), Timer (99/60/inf), Screen shake (off/low/full), CRT scanline filter (off/on), Hit boxes (off/on), Keyboard rebinding **[STRETCH]**, Fullscreen. Persist to `localStorage`.
- **Training room [MVP-lite]**: infinite HP/meter, reset position (R), dummy modes: stand/crouch/jump/block-all/block-after-first/CPU, hitbox display, frame data panel (startup/active/recovery/advantage of the last move, damage, combo count, juggle remaining). Cheap because it reuses the engine and the debug overlay. This is a portfolio-grade feature.
- **How To Play**: 1 screen: controls + 3 tips.

---

## 7. AI **[MVP: tiers 1-8 as one parameterised controller]**

AI outputs the same `{dir, buttons}` struct per tick as a human, subject to the same input rules (motions are produced by scripting the right direction sequence over several ticks, so moves have the same recovery and AI can whiff). Architecture: **perception -> intent -> action script**.

**Perception** (each tick, delayed by `reaction` ticks): distance bands (`close <40, mid 40-90, far 90-180, full >180`), opponent state (attacking/startup/air/block/knockdown), opponent move id and frame, projectiles in flight and ETA, own meter/HP, corner awareness, recent opponent history (last 10 actions: counts of jumps, fireballs, blocks).

**Intents** (priority order): 
1. *Defend*: if an opponent attack is in startup within threat range: with probability `blockSkill` block (high/low chosen by the attack's level, learned; at low tiers randomly wrong 30%); `antiAir` response if opponent is airborne approaching: DP (or 2HP) with probability `antiAirSkill`; punish whiffs/blocked heavies with the fastest reaching move (`punishSkill`).
2. *Wakeup*: after knockdown, DP/reversal with probability `reversalSkill`, else block or quick-rise.
3. *Pressure* (when opponent is blocking/just got hit): blockstrings (chain light normals, finish with a low or overhead mix), tick throw attempts (stutter: LP then throw), pushblock-less. Mix randomised by `mixup`.
4. *Neutral*: spacing: walk to `idealRange` (character-specific poke distance), fire projectiles (zoners), jump-in occasionally (less when opponent has anti-air history), approach with dash, poke with the longest safe normal, empty low/jump to bait.
5. *Combo*: on a confirmed hit, run a combo script per character (`LP,LP,2LP > special`, `2HP launch > super`), with execution accuracy `comboSkill` (drops hits at low tiers).
6. *Meter*: spend super when it would kill or when opponent is cornered and blocking.

**Reads/adaptation**: the AI tracks the opponent's habits (EMA of: jumps per second, projectile spam, block frequency, grab tech rate) and counters: lots of jumps -> raise anti-air odds; lots of fireballs -> jump/dash-through; heavy blocking -> more throws; passive -> move in. Adaptation strength = `readSkill`.

**Difficulty ladder** (tier 1-8, selectable "Easy 1-2, Normal 3-4, Hard 5-6, Arcade-Max 7-8"; story ramps automatically):

| Tier | reaction (ticks) | blockSkill | antiAir | punish | reversal | comboSkill | mixup | read | notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 28 | 0.15 | 0.05 | 0.05 | 0 | 0.1 | 0.1 | 0 | wanders, jabs, rarely blocks |
| 2 | 24 | 0.30 | 0.10 | 0.10 | 0.02 | 0.2 | 0.2 | 0 | |
| 3 | 20 | 0.45 | 0.20 | 0.20 | 0.05 | 0.3 | 0.3 | 0.1 | |
| 4 | 16 | 0.55 | 0.35 | 0.30 | 0.10 | 0.45 | 0.4 | 0.2 | |
| 5 | 13 | 0.68 | 0.50 | 0.45 | 0.15 | 0.6 | 0.5 | 0.3 | uses specials correctly |
| 6 | 10 | 0.78 | 0.65 | 0.60 | 0.22 | 0.75 | 0.6 | 0.5 | |
| 7 | 8 | 0.88 | 0.80 | 0.75 | 0.3 | 0.9 | 0.7 | 0.7 | |
| 8 | 6 | 0.95 | 0.92 | 0.9 | 0.4 | 1.0 | 0.8 | 0.9 | beatable: never reads inputs on the same tick (min 6 tick reaction), whiffs 5% |

Anti-cheat for fairness: AI never reads current-tick inputs; it responds to *visible state* after the reaction delay. Boss: tier 7 base, +1 in phase 2, plus scripted patterns (Dusk Step after N seconds of stalling).

Arcade ladder ramp: fight 1 = tier 2, 2 = 3-4, 3 = 5, boss = 7 (8 in phase 2). Rubber banding: if the player loses a round, tier -1 next round (min 1) and gently reduces aggression; if the player wins a round perfect, tier +1.

---

## 8. Arcade story ladder **[MVP]**

World: **The Last Bracket**, a back-alley tournament run by VANTA, a masked patron who "bottles" the spark that makes a fighter great. Lose, and the spark goes dim. Short, punchy lines; no gore.

Structure (arcade): 3 rival fights + boss. Order for each fighter is fixed so each gets distinct pre-fight dialogue; plus a mirror match is **[STRETCH]**. A "Break the Anvil" bonus stage (hit a stack of crates/boulders as hard as you can, charge-meter) after fight 2 **[STRETCH]**.

| Player | Fight 1 | Fight 2 | Fight 3 | Boss |
|---|---|---|---|---|
| SURGE | JUNO | BASALT | BRICK | VANTA |
| BRICK | BASALT | JUNO | SURGE | VANTA |
| JUNO | BRICK | SURGE | BASALT | VANTA |
| BASALT | SURGE | BRICK | JUNO | VANTA |

Stages by *opponent*: fight uses the opponent's home stage (JUNO temple, BASALT forge, BRICK rooftop, SURGE harbor); boss in the Coliseum.

**Intro text (before fight 1; 3 lines each, typewriter on a dark card with the portrait)**
- SURGE: "The docks go quiet when the tide turns. An invitation washed up on my boat. Someone wants a bracket. I'll give them a wave."
- BRICK: "Free beer and a trophy? Count me in. Funny thing about 'The Last Bracket'. Nobody remembers who won."
- JUNO: "The monks call it a trial. I call it a Tuesday. Let's see who brought their spark."
- BASALT: "I forge things that last. A man in a mask says he can bottle what I make. I want to see him try."

**Pre-fight dialogue** (the speaker says line A, the opponent replies B; 1 line each; shown on the VS screen as speech bars):
| Match | A (first named) | B |
|---|---|---|
| SURGE vs JUNO | SURGE: "Your fire won't light wet wood." | JUNO: "Then let's soak the whole dock." |
| SURGE vs BASALT | SURGE: "Heavy things sink." | BASALT: "So do tides." |
| SURGE vs BRICK | SURGE: "Spit out the toothpick." | BRICK: "Make me, Splash." |
| BRICK vs BASALT | BRICK: "Big guy, big hammer, small brain?" | BASALT: "Big hammer. Small talk." |
| BRICK vs JUNO | BRICK: "I don't hit girls. I hit fighters." | JUNO: "Good. Try." |
| JUNO vs BASALT | JUNO: "I can burn iron." | BASALT: "Iron makes the fire." |
| (any) vs VANTA | VANTA: "You are the last spark. Burn bright and be mine." | Player: per-fighter quote (below) |

Fighter quotes vs VANTA: SURGE "The tide takes everything back." BRICK "Nice mask. Looks like a bar stool." JUNO "Dawn comes whether you like it or not." BASALT "I make things that outlast you."

**Endings** (3 lines + final image = the fighter's portrait under a sunrise/etc. over the arena):
- SURGE: "VANTA's mask washed up on the pier at dawn. SURGE sold the boat and kept the tide chart. The docks still hum on stormy nights."
- BRICK: "Trophy under one arm, VANTA's mask on the other. BRICK hung it behind the bar. The toothpick is for the mask now."
- JUNO: "The temple bell rang once when the bracket ended. JUNO took the sunrise, and the trophy, and left the rest to the monks."
- BASALT: "He melted the mask into a single anvil. The forge sang for a week. It still does."

Credits stinger with the all-roster pose.

Boss intro: letterbox, VANTA descending, "THE FINAL BRACKET" title, then banter.

---

## 9. Data model (for the builder) **[MVP]**

```
src/data/fighters/<id>.js  exports {
  id, name, title, bio, stats:{hp,pwr,def,walkF,walkB,jump,gravity,dash,throwRange,height},
  palette, rig, parts, poses (overrides), moves: { '5LP': {...}, ... },
  specials: [ { id, input:{motion:'QCF', btn:'P'}, versions:{L:{...},H:{...},EX:{...}} } ],
  super: {...}, finisher:{code:[...], cinematic:{...}}, ai:{style, idealRange, combos:[...]},
  portrait:{master, hudCrop:[x,y,w,h]} }
```
A move = `{ id, anim:[{pose, ticks}...], startup, active, recovery, moveVx:[{from,to,vx}], hits:[{from,to,box,dmg,level,hs,bs,pbHit,pbBlock,hitstop,kd,launch:{vx,vy},juggleCost,meterHit,meterBlock,fx,sfx}], invuln:[a,b,type], armor:{from,to,n}, cancels:{into:[...], windowFrom,windowTo, on:'hit'|'block'|'both'}, hurtOverride:[{from,to,boxes}] }`.
The engine is pure (no DOM): `step(world, inputsP1, inputsP2)`; render reads the world. Headless tests with `node --test` check: advantage numbers equal the tables, motion detection accepts/rejects sequences, damage scaling table, juggle point accounting, and a seeded AI-vs-AI match completing without exceptions.

---

## 10. Scope summary

**MVP:** everything marked **[MVP]**: 4 fighters + boss, full normals/specials/EX/super, input buffer, chains/cancels/juggles/scaling, meter, rounds, AI 1-8, arcade ladder with intros/endings/dialogue, versus, training-lite, pause + move list, options, keyboard + gamepad + touch, Final Blow generic cinematic, hit-boxes debug overlay.

**Stretch:** unique Final Blows per fighter, boss selectable, mirror match + bonus stage, attract mode, high-score table, key rebinding, jump cancel/air combos, per-character alt palettes, replay of last round, air block variants, guard break.
