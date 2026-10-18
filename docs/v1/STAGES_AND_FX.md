# Pixel Brawlers: Stages, FX, Camera, HUD, Screens, Audio

All visuals are code-generated (no external image files required): static layers are painted once at boot into offscreen canvases by seeded painter functions, animated overlays are drawn per frame. Internal res 384x216, stage 576 wide, floor line y=192 (see `ART_BIBLE.md`).

---

## 1. Shared graphics toolkit (`src/gfx/draw.js`) **[MVP]**

The builder writes this first; everything else uses it.

- `rng(seed)` mulberry32, `noise1d/2d` (value noise) for clouds/lava.
- `px(ctx,x,y,col)`, `rect`, `line`, `circle`, `poly` (all hard-edged, no AA: draw via `fillRect` on integer coords or ImageData).
- `ditherGradient(ctx, x,y,w,h, colA, colB, dir)` using a **4x4 Bayer matrix** (banded sky with dither transitions; 3-5 palette steps, not a smooth gradient).
- `paletteRamp(stops, steps)` returns hex arrays.
- `outlineCanvas(canvas, col)`, `tintCanvas(canvas, col, amount)`, `flash(canvas)` (white silhouette), `mirror(canvas)`.
- `bitmapText(ctx, str, x, y, {size, fill, outline, shadow, gradient})`.
- Everything snaps to integers. `ctx.imageSmoothingEnabled=false` always.

Stage architecture: a stage is `{ id, name, width:576, palette, layers:[...], spectators, ambient, music, floor, lighting, intro?(), update(t), drawBack(ctx,cam,t), drawFront(ctx,cam,t) }`. Layers: `{ factor (parallax), canvas (prebaked) | draw(ctx,cam,t) (animated), y, repeatX? }`. Layer x on screen = `-cam.x * factor`. Factors (camera scroll is up to 192 px between extremes; 0 = fixed to screen):

| Layer | Factor |
|---|---|
| Sky / far backdrop | 0.05 |
| Far skyline / mountains / sea | 0.12 |
| Mid-far structures | 0.25 |
| Mid structures + spectators | 0.5 |
| Near background (the "wall") | 0.8 |
| Fighting plane (floor, fighters) | 1.0 |
| Foreground silhouettes/props | 1.25 (drawn after fighters, can overlap the floor band) |

Minimum per stage: **6 layers + floor + 2 foreground elements + 3 independent animations + 1 ambient particle system + 1 lighting effect + a reactive element (reacts to hits/KO/special)**.

Camera vertical: lifts up to 14 px when a fighter jumps (follow the highest fighter, eased); horizon layers shift by factor.

---

## 2. Stages **[MVP: 5 stages]**

Each includes palette (8-16 colours), layers, animations, spectators, ambient, lighting, reactive, music id.

### 2.1 SKYLINE 88: Neon Rooftop (BRICK's home) night

Palette: sky `#0a0620 #1a0e45 #3a1670 #7a2a96 #c24a8a`, building silhouettes `#120a2a #1a1040`, neon pink `#ff3ea5`, cyan `#35e0ff`, amber `#ffb02e`, concrete `#3a3550 #4e4868 #6a6485`.
Layers:
1. Sky dithered 5-band purple->magenta horizon, **stars** (twinkle, 3 phases), a big low moon/sun disc with banded stripes (retro-sun).
2. Far skyline (f 0.12): 20-30 tall silhouettes, tiny lit windows (random, a few blink slowly).
3. Mid skyline (f 0.25): lit buildings with neon signs, **animated billboards** (a looping 4-frame pixel animation: noodle bowl steaming; slot machine; heart pulse; "88" flickering).
4. **Flying vehicles** (f 0.2-0.3): 2-3 cars/blimp crossing slowly on a loop; blimp with scrolling LED text "PIXEL BRAWLERS".
5. Near buildings (f 0.5): rooftops with AC units, water tanks, antennas with red blink lights, a helicopter searchlight sweeping a cone (additive light) every ~12 s.
6. The arena rooftop (f 0.8-1.0): parapet wall with graffiti, string lights swaying (sin offset), a rooftop crowd (section 3) on the far side, steam vents (puffs rising from floor edge props).
Floor: dark concrete with painted lines, puddle reflections (mirrored neon smears with 2-colour dither), expansion joints every 48 px.
Foreground (f 1.25): left/right pipes and a chain-link fence silhouette, a flickering neon sign overlapping the top.
Ambient: slow drifting smog, occasional paper scraps blown across. Lighting: pink/cyan rim light (a faint additive column at each edge of the screen); fighters get a subtle cyan tint on the left side, pink on the right (overlay with `globalCompositeOperation='lighter'` at 12% alpha on a shape of the sprite via a prebaked tinted copy).
Reactive: billboards flash white on heavy hits; string lights swing on big shakes; sign flickers off on KO.
Music: `skyline` (synthwave, 128 BPM, minor).

### 2.2 TEMPLE COURTYARD (JUNO's home) dusk

Palette: sky `#2a1a3a #8a3a5a #e2704a #ffb86a #ffe7a0`, stone `#4a4258 #6e6478 #9a90a0`, wood `#5a2a1a #8a4a2a #c07a3a`, petals `#ffb0c8 #ff7aa0`, lantern `#ffd870`.
Layers: 1 dusk sky (dithered 5 bands) + big setting sun with ring; 2 far mountains (2 ridges, mist band that drifts); 3 distant pagoda silhouette tiers (f 0.25) with a tiny flag animating; 4 **cherry trees** (f 0.5) with sway and falling petals; 5 temple facade (f 0.8): wooden pillars, paper screen doors, red banners (cloth sway), **giant bell** or **gong** hanging at left; 6 courtyard wall with stone lanterns that flicker (light cone on the floor).
Floor: stone tiles in perspective bands with moss pixels; koi pond strip in the foreground (animated ripples, a koi that passes).
Spectators: robed monks and fighters sitting in rows, **drummers** (a taiko drum player animating on the beat) and a few kids waving fans. 8-12 spectators total, 3 colour palettes, 2-3 poses each: idle/cheer/gasp.
Ambient: **falling petals** (80 particles, 3 sizes, sin-wave horizontal drift, wind variation, some land and fade on the floor); light dust shafts (diagonal faint stripes, additive).
Lighting: warm sunset glow from the right (additive orange gradient over the right 40% of the screen, 10-15%), fighters get warm rim.
Reactive: the bell swings on heavy hits and **rings (SFX)** on KO; petals burst upward on knockdown landing; lanterns flare on special/ super.
Music: `temple` (pentatonic, taiko-like noise drums, 110 BPM).

### 2.3 HARBOR (SURGE's home) night rain

Palette: sky `#050a18 #0a1a30 #14304e #1f4a6a`, sea `#0c2a44 #144a6a #1f6a88`, steel `#2a3442 #46566a #6a7c92`, lights `#ffe08a #ff5a4a #5affc8`.
Layers: 1 overcast sky with **lightning** (random every 6-14 s: 3-frame white flash on sky + a forked bolt silhouette, thunder SFX 20 ticks later); 2 far sea band with whitecaps scrolling (f 0.1) and **ships**: 2 cargo ships crossing at different speeds/distances with blinking lights, a lighthouse sweeping (beam additive, rotating); 3 container stacks (f 0.4-0.5) colourful but darkened, **gantry crane** swinging a container slowly (anim); 4 dock buildings + lit warehouse windows; 5 the dock wall with bollards, ropes, **dockworkers** (spectators) with umbrellas and crates, fish crates, barrels; 6 foreground puddles and mooring ropes.
Floor: wet planks/concrete, reflections of light sources as vertical dither streaks, **puddle ripples** where fighters step/land (small expanding rings).
Ambient: **rain** (200 streaks: 2 depth layers, diagonal, speed 6-9; splashes on floor line), fog bank layer drifting (alpha dither), wind shaking tarps.
Lighting: cold blue fill; warm lamp posts with additive halos; lightning flashes the whole screen +40% brightness for 3 frames and shows silhouettes.
Reactive: splash bursts on knockdown, crane container rattles on heavy hits, ships' horns on KO.
Music: `harbor` (slow driving minor, 100 BPM, rain noise bed under).

### 2.4 FORGE (BASALT's home) volcano

Palette: rock `#1a0f12 #2e1a1a #4a2a22`, lava `#ff3a10 #ff7a1a #ffc040 #fff0a0`, ember `#ff9a40`, smoke `#2a2326 #4a3f42`.
Layers: 1 dark red sky with glowing volcano silhouette (f 0.1), **eruption** every ~15 s: plume of ash + sparks arcs; 2 far lava river (f 0.2) with animated flowing bands (palette-cycling 4 colours) and floating dark crust; 3 industrial pillars/chains (f 0.5) with hanging chains swaying, a huge bellows pumping (anim), anvil row; 4 forge wall (f 0.8): furnace mouths glowing (flicker), pipes with steam jets (periodic bursts); 5 stage catwalk with **forge workers** (spectators) hammering in rhythm to the beat (hammer arm swinging; sparks on contact); 6 foreground bars/chains and a heat-shimmer overlay.
Floor: dark basalt plates with glowing cracks that pulse; lava pool gaps at the far edges (not walkable, decorative).
Ambient: rising **embers/sparks** (150 particles, orange->red, upward drift with jitter), ash flakes falling, smoke columns. **Heat distortion**: per-scanline horizontal sine offset (<=1 px) on the far layers only (cheap row copying).
Lighting: strong orange up-light from the bottom, fighters get an orange rim at the feet fading up; furnace flicker modulates a 10% additive overlay.
Reactive: lava surges (brighter, higher) on special/super; ground cracks glow brighter per hit during a combo (combo counter drives glow); chain sway on shake.
Music: `forge` (heavy, low pulse + noise anvil hits, 96 BPM).

### 2.5 VOID COLISEUM (VANTA's arena)

Palette: void `#05030c #0e0a24 #1c1440 #2e2260`, gold `#6a4a08 #b88a14 #ffcf33 #fff0a0`, violet `#7a2ea0 #b060d8`.
Layers: 1 starfield + a **huge eclipse** (black disc with a gold corona that pulses; in phase 2 the corona turns crimson-gold and the disc grows); 2 floating broken pillars drifting (f 0.2-0.3) with slow bob; 3 coliseum tiers (f 0.5) with a crowd of **silhouette spectators with glowing eyes** (yellow pixels blink in waves); 4 gold-trimmed arena rim (f 0.8) with runic glyphs that light up in sequence; 5 floor: black mirror with a gold ring emblem, reflections of the eclipse; 6 foreground chains/pillars in silhouette.
Ambient: gold **motes** drifting upward, occasional falling shards, soft aurora band (animated dither bands).
Lighting: gold rim from the eclipse behind (fighters rimmed on their back sides), violet under-light.
Reactive: runes pulse on each hit, glyph ring ignites on supers; phase transition: floor cracks (new crack sprites revealed progressively), crowd goes silent then roars (eyes flash), eclipse corona flares; KO: the eclipse covers fully for a beat.
Music: `coliseum` (epic minor, 140 BPM; phase 2 `coliseum2` faster with extra arpeggios).

### 2.6 TRAINING ROOM (stretch-light) **[STRETCH after MVP; trivial]**
Grid floor, flat colour walls with 8-px tick marks, minimal. Music `training` (calm loop).

---

## 3. Spectators and background characters **[MVP: at least 3 stages, 8+ spectators each]**

- Spectator sprite = small baked set from the same rig system at 40% scale OR hand-pixeled 16x24 grids with 3 poses (idle bob 2 frames, cheer arms-up 2 frames, gasp 1 frame) + palette swaps (random 6 palettes).
- State driven by the match: idle -> cheer on combos >= 3 hits / supers / KO; gasp on knockdown; silent at "PERFECT"; face the fight.
- Placed on the mid layers with parallax factor, depth-sorted; heads bob slightly on the BPM beat.
- Count budget: <= 24 per stage; draw as prebaked sprites with a per-spectator `frame` and `offsetY`.

---

## 4. Lighting, weather, screen effects **[MVP]**

All hard-edged pixel effects. Implement as a small effect stack drawn after the world and before the HUD.

| Effect | Spec |
|---|---|
| Rim/tint light | prebaked tinted copy of each sprite frame at boot per stage-colour pair: left-edge rim = shifted silhouette minus original; cache per stage |
| Additive glow | `globalCompositeOperation='lighter'`, low alpha, drawn as radial dither discs (4 steps) not smooth gradients |
| Vignette | prebaked 4-step dither darkening at corners, alpha 0.25 |
| Scanlines (option) | every 3rd screen row at 10% black, on the final canvas |
| CRT curve (stretch) | skip |
| Rain/petals/embers/dust | pooled particle system `{x,y,vx,vy,life,col,size}`; fixed pool arrays; no allocation in the loop |
| Lightning | white fill for 2 frames at 45% then 1 frame 20% |
| Heat shimmer | row offset copy, <=1px, far layers |
| Flash | full-screen colour flash, 2-4 ticks (super, KO) |
| Chromatic split on KO | 2-tick red/blue offset copy of the canvas (use 2 extra drawImage with `lighter` and tinted copies) |

---

## 5. Hit FX, particles, sparks **[MVP]**

All sprites are **procedural pixel shapes** drawn in a 2-4 tick animation, origin at the contact point (midpoint of hitbox/hurtbox overlap).

| FX | Look | Duration |
|---|---|---|
| Hit spark light | white + yellow 5-pointed burst, 11 px | 4 ticks |
| Hit spark heavy | large 3-ring burst (white core, yellow, orange), 24 px + 6 flying 2x2 sparks | 8 ticks |
| Block spark | cyan-white hexagon shield flash + 3 small shards pushed back | 5 ticks |
| Special hit | stage-coloured (`Q`) burst + radial lines | 10 ticks |
| Super hit | full-screen radial lines for 6 ticks, big flash | |
| Dust | 3-6 grey 2x2 puffs at feet for walk-start/dash/land/slide/knockdown; larger 6x4 clouds on knockdown | 12-18 ticks |
| Footsteps | tiny dust on every 2nd walk step | |
| Smear/trail | arc of 3 tones along the limb path for the first active tick of heavies | 2-3 ticks |
| Afterimage | 3 ghost copies of the sprite at 70/50/30% alpha, tinted by `Q`, for dashes/supers | 8 ticks |
| Projectile trail | 3-4 fading copies + sparks | |
| KO burst | star-burst + ring shockwave expanding 60 px; screen flash; chromatic split | 18 ticks |
| Damage numbers | optional **[STRETCH]** small white pixel numbers rising from the hit | 20 ticks |
| Combo text | "2 HITS" ... slides in at the screen side, scale pop | |

**Hitstop**: attacker + defender freeze (values in GAME_DESIGN 2.3). **Shake**: `amp = clamp(dmg/12, 1, 6)` px for `dmg/6` ticks; random offset integer, decays linearly; super/KO shake 8 px / 30 ticks; option off/low(50%)/full. **Sprite flash**: defender sprite white silhouette 2 ticks on hit, red-tinted 4 ticks after. **Hit slow-mo**: KO 0.25x for 40 ticks with 1.4x zoom into the loser; the supers' superflash: the world freezes except the attacker, background dims 70%, speed lines.

---

## 6. Camera **[MVP]**

State: `{x, y, zoom}`; sim-driven, not render-driven.
- Target x = midpoint between fighters, clamped to `[0, stageW - 384]`; ease `x += (target - x) * 0.18` per tick, snapped to integer pixels on render (no sub-pixel scrolling jitter). Fighters never leave the screen: a fighter at the edge stops the other from moving away (walls at camera bounds +- 16).
- Look-ahead 0.
- Vertical y: follow the higher fighter, lift max 14 px, ease 0.12.
- Zoom: default 1.0 (crisp integer pixels). Cinematic zoom (super flash, KO, Final Blow) eases to 1.35-1.6 around a focus point and back; implemented by rendering the world to an offscreen 384x216 buffer and `drawImage` it scaled with smoothing off (accept the short-lived uneven pixels; they last < 1 s). In-fight zoom-out when fighters are far: **no** (screen is fixed width).
- Letterbox bars (top/bottom 24 px) slide in for boss intro, phase transition, Final Blow.
- Shake added after smoothing.

---

## 7. HUD **[MVP]**

Top band 0-38 px.
- **Health bars:** two bars 148 px wide x 10 px high from the top corners toward the centre (P1 left filling right-to-left depleting toward the outer edge? Use SF: bars deplete toward the outside; the *lost chunk* in hot yellow lags 20 ticks then drains). Bar body: dark panel with a 2px bevel; fill colour gradient steps (green->yellow->red by hp: >50% `#4ade50`, >25% `#ffd23a`, else `#ff4a3a` pulsing). Gold ticks every 25%.
- **Portrait icon** 32x32 (face crop) in a bevelled frame at the outer top corner; **name plate** under the bar (e.g. `SURGE`) 8px font.
- **Round pips**: under the name, 2 gem icons (empty dark, filled gold with sparkle on win).
- **Timer**: centre, bevelled octagon, 2-digit big number 16px, flashes red <= 10, ticks SFX <= 5.
- **Meter**: bottom corners, 3 segments (each 40 px), fill cyan/ gold, pulses at full, "SUPER READY" text flashes at 200+. Bar glows when a segment completes.
- **Combo counter**: on the *hit* player's side, "3 HITS" big numerals with gold gradient, "DMG 142", scale pop per hit, fade after 40 ticks.
- **Announcer text**: centre: "ROUND 1", "FIGHT!", "K.O.", "PERFECT", "TIME UP", "FINAL BLOW!", "YOU WIN" (big gradient font, scale-in, hold, scale-out, with a stage-coloured flash behind).
- **Input display** (training room only): small ring of arrows/buttons history on the side.
- **Debug**: F2 hitboxes; F3 FPS/state panel.
- Safe margins 6 px; all text integer-aligned.

---

## 8. Screens art direction **[MVP]**

### Title
Black-violet backdrop with a slowly scrolling retro-sun grid horizon (dither bands), the **key art**: SURGE (profile, behind, left) and BRICK (front, right, overlapping) from their 96x96 portraits at 2x, composed back-to-back exactly like the reference (BRICK's shoulder overlapping SURGE's), with a cyan glow behind SURGE and gold behind BRICK (additive discs), sparks drifting. Logo "PIXEL BRAWLERS" top-centre: two lines, chrome gradient letters with a gold/cyan split gradient, 2px dark outline, 3px extruded drop shadow, shine sweep every 4 s. "PRESS START" blinking at 1 Hz. Footer: `PORTFOLIO DEMO · v1.0 · ORIGINAL IP` small. Idle 20 s: attract mode.

### Character select
Dark panel, subtle grid; a **2x2 portrait grid** center-left (portraits 96x96 at 1x in beveled tiles with names), P1 cursor cyan, P2 cursor red, pulsing frame; right side: large idle-animated sprite of the hovered character at 2x on a spotlight, name in big text, title, style tag, 4 stat bars (power/speed/range/defense, 8-step blocks), a 2-line bio; bottom: stage preview thumbnail strip (the opponent's home stage in the arcade, or random/stage pick in versus). Lock-in plays a flash and the sprite does its intro pose. A "RANDOM" tile with `?`.

### Versus screen
Black with diagonal split: P1 portrait 2x slides in from the left (192x192), P2 mirrored from the right, names in big gradient font, a **VS** slams in the centre (scale 3 -> 1, shake, flash), stage name below ("THE HARBOR"), speech-bar quote lines for story. 90 ticks, skippable.

### Story cards
Dark card, portrait left 1x, typewriter text at 8px, "PRESS ANY BUTTON" blink; ending: full-screen illustration composed in code (portrait + sunrise gradient + silhouettes).

### Result
Victory pose of the winner sprite on the stage with the score tallies (time bonus, perfect bonus, combo bonus), "CONTINUE?" countdown optional **[STRETCH]**.

### Menus
Panels bevel style; option rows `< value >` style; icons for controller prompts.

---

## 9. Audio **[MVP]**: WebAudio chiptune engine (`src/audio/`)

Files: `engine.js` (context, master/sfx/music buses, mute, unlock-on-first-input), `synth.js` (voices), `seq.js` (sequencer), `songs.js` (data), `sfx.js` (sound effects).

### 9.1 Voices (4-channel NES-like + 1 extra)

| Channel | Waveform | Use |
|---|---|---|
| P1 | pulse via `PeriodicWave` with duty 12.5% / 25% / 50% (built from Fourier series) | lead |
| P2 | pulse | harmony / arpeggio |
| TRI | `triangle` | bass |
| NOISE | white-noise `AudioBuffer` loop (looped 2 s buffer), through a bandpass/highpass for hats/snares; short-period (metallic) noise via a second pre-filtered buffer | drums / FX |
| EXTRA (optional) | pulse | countermelody |

Each note: `GainNode` envelope (attack 1-2 ms, decay to sustain, release 20-60 ms), optional vibrato (LFO on frequency, 5-6 Hz depth 6-12 cents, starting after 100 ms), pitch slide (`linearRampToValueAtTime`), arpeggio mode (cycle 3 pitches at 60 Hz). Use a pool of oscillators; **never** create >40 live nodes.

### 9.2 Sequencer
- Scheduler: `setInterval` 25 ms, lookahead 120 ms; schedules notes at `ctx.currentTime + t` with sample-accurate timing; time-base in **ticks of 1/4 beat**... define `ppq=4` (16th notes). `bpm`, `swing` (0-0.2).
- Song data format (MML-lite strings per channel, one pattern list):
```js
export const skyline = {
  bpm: 128, ppq: 4, loop: 0,
  channels: {
    p1: { wave: 'pulse25', vol: 0.18, env:[0.002,0.08,0.5,0.06], pattern: 'o4 l8 a4 c e a4 g f e4 .. ' },
    p2: { wave: 'pulse12', vol: 0.12, arp: 'chord', pattern: '...' },
    tri: { wave: 'tri', vol: 0.30, pattern: 'o2 l8 a a a a  f f f f ...' },
    noi: { vol: 0.14, pattern: 'k . h . s . h h' }   // k kick, s snare, h hat, o open hat
  },
  sections: ['A','A','B','A'] // optional
};
```
MML-lite grammar: `oN` octave, `lN` default length (1,2,4,8,16 = whole..16th, dotted `.`), notes `c d e f g a b` with `+`/`-`, `r` or `.` rest, `<` `>` octave down/up, `vN` volume, `tN` tempo change, `[...]N` repeat, `|` bar separator (ignored), `&` tie. Drums: `k s h o` symbols with their own synth (kick = sine/tri pitch sweep 150->40 Hz in 80 ms; snare = noise 120 ms + 180 Hz tri; hat = hp noise 20 ms; open hat 90 ms).
- Songs required (loop points): `title` (heroic, 120 BPM), `select` (tense, 132), `skyline`, `temple`, `harbor`, `forge`, `coliseum`, `coliseum2`, `versus` (stinger 6 s), `win` (jingle 5 s), `lose` (jingle 4 s), `ending` (ballad 90 BPM). Each looping song 16-32 bars with A/B sections; deterministic.
- Dynamic music: final round -> tempo x1.08; low HP (<20%) adds a tension arp channel; pause ducks to 25% with lowpass 800 Hz.

### 9.3 SFX (synth recipes)

| SFX | Recipe |
|---|---|
| light whoosh | noise burst 80 ms, bandpass sweep 2000->800 Hz |
| heavy whoosh | noise 140 ms sweep 1200->300 Hz |
| punch hit light | 60 ms: tri 220->110 Hz drop + noise 25 ms |
| punch hit heavy | 120 ms: sine 160->50 Hz + noise 60 ms + square 8 ms click |
| kick hit | like punch heavy, slightly lower and longer |
| block | pulse 50% 700 Hz 40 ms + noise 20 ms, muffled |
| special / fireball | pulse sweep 400->1200 Hz 160 ms + shimmer arpeggio |
| rising special (DP) | upward sweep 150->900 Hz 220 ms |
| super flash | low rumble 100 Hz 400 ms + rising sine 200->1600 Hz 300 ms + "ding" |
| projectile hit | noise burst + descending pulse |
| jump / land | pulse 300->600 Hz 70 ms / noise puff 50 ms low |
| footstep | tiny noise tick 15 ms (every other step) |
| KO | big noise + descending tri 400->40 Hz 700 ms + cymbal |
| announcer cues | "round", "fight", "ko", "perfect": 3-note pulse jingles (voice via `speechSynthesis` if available, stretch) |
| UI move/confirm/back/error | short square blips (880/1320 Hz, 30 ms), confirm = 2 notes |
| timer tick | 1 kHz 10 ms |
| bell (temple KO) | additive sines 520/780/1040 Hz decaying 1.5 s |
| thunder | long brown noise with lowpass sweep 1 s |
| crowd | filtered noise swell |

Mixing: master 0.7, music 0.45, sfx 0.8; `DynamicsCompressor` on master; polyphony caps per SFX id; a hitstop does not freeze audio. AudioContext is created/resumed on the first user gesture (keydown/pointerdown). `M` toggles mute; options sliders persist.

---

## 10. Performance and robustness **[MVP]**

- Boot: bake sprites and stage layers during a loading screen with a progress bar (target < 1.5 s on a laptop). Bake per stage lazily when first needed.
- Frame budget: 16.6 ms; particle pools; avoid per-frame allocations; `ctx.drawImage` of prebaked canvases.
- Pause the sim when the tab is hidden; resume without catch-up burst (cap accumulated time at 100 ms).
- `devicePixelRatio`: canvas internal 384x216, CSS scaled to integer multiples of the *CSS pixel*; if the DPR makes non-integer device scale, prefer the nearest integer on device pixels (compute `floor(availW*dpr/384)/dpr`).
- Reduced motion option: lowers shake/flash.
