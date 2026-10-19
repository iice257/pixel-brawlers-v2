# Generated art: 7 images, 15 items

> **Superseded in part (2026-10-19):** the art direction is now a steampunk 2.5D anime fighter. See `docs/ART_DIRECTION.md` and `docs/HANDOFF.md`. Anything here that assumes pixel art is void.

These prompts are written for any modern image model (Gemini / Nano Banana, GPT Image, Midjourney, Ideogram for text-heavy items). Generate from text only, and never upload pack sprites as references; see GODOT_PLAN "Generated art".

**Use the same style block in every prompt** so the set reads as one game. Paste it at the end of each prompt:

> STYLE: 16-bit arcade fighting-game pixel art, 1990s cabinet era. Chunky dark outlines, hard cel shading with 3-5 tones per material, no gradients, no blur, no anti-aliasing, no photo texture. Limited saturated palette on near-black: background #0a0714, panel violet #1a1030, edge purple #46327a, gold accent #ffcf33, player-1 cyan #35c8e0, player-2 red #ff5a4a, neon pink #ff3ea5. Crisp readable shapes, strong silhouettes, dramatic rim light (cyan from the left, pink from the right). No watermark, no signature, no extra text unless asked.

**Roster used in the prompts** (v1's own characters). If the chosen pack's fighters replace them, swap these descriptions for the pack characters' looks before generating:
- **SURGE**, the cyan corner: lean, muscular karate-boxer, bare chest, tall swept-back spiky teal hair, red trunks, white hand wraps, cyan armband, intense squint.
- **BRICK**, the red corner: broad blond brawler, flat-top spiky hair, white tank top, jeans, black fingerless gloves, gold belt buckle, toothpick, cocky grin.
- **JUNO**: agile kung-fu fighter, red-orange high ponytail, ivory crop top and wraps, flared black-violet pants, gold sash, confident smirk, small orange fire at her fist.
- **BASALT**: huge bald bearded grappler, tiny head between massive shoulders, leather apron, iron gauntlets with glowing ember cracks, ember eyes, scar.

**Post-process** (done by the builder with `tools/pixelize`): crop, downscale with nearest-neighbour to the target size, quantise to the palette, and key out the `#00FF00` backgrounds. The target sizes assume the 384x216 base (the 480x270 sizes are in brackets).

---

## Image 1: Logo (1 item)
Aspect 3:1. Target 256x80 [320x100]. An Ideogram-class model is best for the lettering.

> Game logo wordmark reading exactly "PIXEL BRAWLERS", two stacked lines: "PIXEL" smaller on top, "BRAWLERS" large and wide below. Thick blocky arcade letters with a heavy black outline, a gold-to-orange banded fill (hard colour bands, not a smooth gradient), a cyan inner highlight on the top edge, a slight forward italic lean, and a small jagged impact burst behind the "B". Centred on a flat pure green #00FF00 background with nothing else in frame. STYLE: [style block]

## Image 2: Key art, doubling as the page/portfolio banner (2 items)
Aspect 21:9 (about 2560x1100). Uses: the title-screen hero image (crop the centre to 16:9) and the GitHub/portfolio banner (the full width).

> Wide cinematic fighting-game key art. SURGE (left) and BRICK (right) face off at the centre, about to clash, fists cocked and shoulders squared. They are drawn from the waist up, filling the middle 60% of the frame, with an energy spark exploding between their fists. Behind them is a neon city rooftop at night: a purple-to-magenta dithered sky, a big striped retro sun low on the horizon, skyscraper silhouettes with pink and cyan neon signs. SURGE is rim-lit cyan, BRICK rim-lit red. Keep the top 20% fairly calm so a logo can sit there. There is no text. [descriptions of SURGE and BRICK from the roster] STYLE: [style block]

## Image 3: Character-select portraits (4 items)
Aspect 1:1 (2048x2048), a 2x2 grid. Target 96x96 per portrait. These are kept in one image so the four share lighting and line weight. If the quality is soft, run the same prompt four times with "single portrait" and one character each; that is still 4 items.

> A 2x2 grid of four fighting-game character-select portraits, equal square cells separated by thin black gutters. Each is a bust (head, shoulders and one raised fist) facing three-quarters toward the viewer's right, the face fills about 45% of its cell, and each cell has a solid near-black #0a0714 background. Top-left SURGE, top-right BRICK, bottom-left JUNO, bottom-right BASALT. Each character has a strong expression and a coloured rim light in their accent colour (SURGE cyan, BRICK gold, JUNO orange, BASALT ember). Use the same line weight and the same light direction for all four. There is no text and no names. [all four roster descriptions] STYLE: [style block]

## Image 4: HUD kit (3 items: health bars with round pips, timer plate, combo badge)
Aspect 16:9. Targets: a health bar frame of 150x14 per side, a timer plate of 32x24, a combo badge of 64x24.

> A game UI sprite sheet on a flat pure green #00FF00 background, with the elements spaced far apart and nothing overlapping. (1) Across the top, a pair of mirrored fighting-game health bar frames, one per player, slanted parallelogram ends, a thick dark violet frame with a gold trim line. The left bar has a cyan inner edge and the right bar a red one. Each bar is empty inside (a dark #1a1030 fill) so the fill can be drawn by the game. Under each bar sit two small round-win pips: one empty and one lit gold. (2) In the middle, a small octagonal timer plate, dark violet with a gold rim, with the digits "99" in chunky pixel numerals. (3) At the bottom left, a combo badge: a slanted banner reading "HITS" in bold pixel letters with an empty space to its left for a number, gold on dark violet with a pink highlight edge. Flat front view, no perspective, no shadows on the background. STYLE: [style block]

## Image 5: SKYLINE 88 stage (1 item)
Aspect 16:9 (wider is fine, up to 2.4:1 for camera scroll). Target 576x216 [720x270]. The builder slices it into a sky layer and a rooftop layer for parallax.

> A side-view background for a 2D fighting game, with no characters in it. A neon city rooftop at night. The sky is a dithered band gradient from deep indigo #0a0620 at the top through purple to magenta #c24a8a at the horizon, with small twinkling stars and a large retro sun disc with horizontal stripes sitting low on the horizon. Behind it is a far skyline of dark skyscraper silhouettes with tiny lit windows. In the mid-ground are lit buildings with neon signs in pink #ff3ea5, cyan #35e0ff and amber #ffb02e, one billboard showing a steaming noodle bowl, and one showing a flickering "88". On a near rooftop sit a water tank, AC units and an antenna with a red light. The fighting floor is a flat, wide strip of dark concrete across the bottom 18% of the image, with painted lines and puddles reflecting neon smears; it is empty and unobstructed. A low parapet wall with graffiti and swaying string lights runs behind the floor. The camera is perfectly level and orthographic, with no perspective tilt. STYLE: [style block]

## Image 6: Menu background + loading screen (2 items)
Aspect 16:9, two panels side by side (left: menu, right: loading). Target 384x216 [480x270] each. Each panel is cropped out as its own file.

> Two separate 16:9 panels side by side, divided by a thin black line. LEFT PANEL, a main-menu background: a dark arcade atmosphere with a close-up of a cracked concrete wall lit by a pink and cyan neon glow from off-screen, faint retro grid lines receding into the distance, drifting smoke. The left 45% of the panel is darker and calm for menu text; on the far right, a large faded silhouette of a fighter's raised fist wrapped in tape. RIGHT PANEL, a loading screen: the two silhouettes of SURGE (cyan rim light) and BRICK (red rim light) walking toward each other along a rooftop edge at night, small in the frame, with a large empty dark area in the lower third for a loading bar. Neither panel has any text. STYLE: [style block]

## Image 7: Hit FX sheet (2 items: hit sparks, energy blast)
Aspect 16:9. Targets: 32x32 per spark frame, 48x24 per blast frame.
**Recommendation:** buy Pozac "Combat Effects 10" ($1.99, 31 animated fighting FX) instead. Image models draw poor animation frames. If you buy the pack, use this image slot for a second stage instead (prompt below).

> A sprite sheet on a flat pure green #00FF00 background, laid out in a strict grid with equal spacing. TOP ROW: a hit-spark impact animation in 6 frames left to right: a white-yellow star burst that grows, breaks into sharp shards and fades, with gold and white streaks and a cyan variant. BOTTOM ROW: an energy-blast projectile in 4 frames: a horizontal fireball moving right, an orange and yellow core with a white centre and a trailing tail of flame chunks. Every frame sits centred in its own cell, with nothing overlapping. STYLE: [style block]

**Alternative Image 7: a second stage, TEMPLE COURTYARD at dusk (1 item).**
> A side-view 2D fighting-game background with no characters. A temple courtyard at dusk. The sky is dithered bands from violet through rose and orange to pale gold, with a large setting sun with a ring. There are distant misty mountains and a pagoda silhouette. Cherry trees drop pink petals. Behind the floor is a wooden temple facade with red banners, paper screen doors and a big bronze gong on the left. The floor is a flat, wide band of stone tiles across the bottom 18% of the image, empty and unobstructed, with a thin koi pond strip at the front edge. The camera is level and orthographic. STYLE: [style block]

---

## Item count
| Image | Items |
|---|---|
| 1 Logo | 1 |
| 2 Key art + banner | 2 |
| 3 Portraits | 4 |
| 4 HUD kit | 3 |
| 5 SKYLINE stage | 1 |
| 6 Menu + loading | 2 |
| 7 FX sheet (or stage 2) | 2 (or 1) |
| **Total** | **15** |
