# REDLINE: art requests (rev 4, 2D anime look)

Rev 4 (2026-10-22). The game is now **REDLINE** (it was Pixel Brawlers). The look is **2D anime animation**: flat cel colour, crisp ink lines and painted backgrounds, so every frame reads like a key frame from an anime fight. The setting stays steampunk with no elemental powers. The name comes from a boiler gauge pushed into the red: the brand colour is the gauge's red line.

Use any modern image model (Gemini / Nano Banana, GPT Image, Midjourney). Use Ideogram or GPT Image for anything with lettering (images 1, 6, 7, 8). Generate from text only and never upload third-party art as a reference. Your own earlier generations are fine to reuse or upload as references.

**Paste the style block at the end of every prompt** so the set reads as one game.

> STYLE: 2D anime fighting-game art in the spirit of Guilty Gear Strive and Granblue Fantasy Versus key frames, crossed with Arcane's painted backgrounds. Crisp, confident ink linework with varied weight, flat cel colour with ONE hard shadow tone and a thin bright rim of light, no soft airbrushed gradients on characters, dramatic foreshortened poses, speed lines. Steampunk palette: soot #14121a, brass #c9a14a, copper #b8643a, oxidised teal #2f7f7a, cream steam #efe6d2, and the brand accent REDLINE red #e3262f (gauge needles, glowing vents, the logo), with glowing amber #ffb347 for lamps only. Backgrounds are hand-painted and atmospheric with depth haze. Clean anime faces with big readable expressions. No watermark, no signature, no text unless asked.

**Roster** (four play styles first: rushdown, grappler, zoner, trickster). The tech is gadgets, gauntlets, pistons and steam.
- **KESTREL**: a lean airship duellist in her late 20s. Short swept-back dark hair, brass goggles pushed up on her forehead, a cropped teal coat with brass buttons, piston-assisted gauntlets, and a belt of small gears and pressure gauges whose needles sit in the red. Fast and confident.
- **BRIGGS**: a broad foundry brawler in his 40s. Shaved head, thick moustache, a scarred leather apron over a bare chest, heavy boots, and one oversized hydraulic gauntlet arm with a glowing red vent.
- **ODILE**: a petite inventor in her early 20s. A messy copper-red bob under a leather aviator cap with monocle-goggles, a brass clockwork backpack with two folding mechanical arms, a long patched lab coat over a corset vest, striped stockings, work boots and ink-stained gloves. She fights at range with a steam cannon and spring-loaded arms.
- **ROOK**: a wiry smog-district youth in his late teens. A black undercut with a long fringe, a soot-smudged face scarf, a torn high-collar coat with brass buckles, fingerless gloves, and a chain-and-hook wrapped around one forearm. Low to the ground; controls mid range with the chain.
- Later: **TOBIAS** (an old watchmaker martial artist), **VESPER** (a masked clockwork assassin).

**Delivery:** drop the originals into `C:\Users\0\Downloads\redline-art\` with the file names below. The builder crops, keys out `#00FF00`, downsizes and imports them. Originals stay out of git.

---

## Priority order
Generate these first: **1 logo, 2 title card, 5 stage layers, 3 concept sheets**. The game looks finished on screen once those four are in. The rest can follow.

## 1. Logo `logo.png` (1 item)
Aspect 3:1, at least 1536x512.
> Fighting-game logo wordmark reading exactly "REDLINE" in one line. Heavy, wide, forward-leaning letters cut from riveted brass plate with a thick black ink outline. A pressure-gauge needle sweeps through the "D" and hits a glowing REDLINE red #e3262f zone. The bevelled metal has a hard cel highlight, a red-hot glow seeps from the letter edges, and a burst of white steam and a jagged manga impact slash sit behind the word. Centred on a flat pure green #00FF00 background with nothing else in the frame. STYLE: [style block]

Optional: the same prompt with "a small engraved subtitle plate under it reading 'STEAM-POWERED FIGHTING'" for the title screen.

## 2. Title and loading card `title.png` (1 image, used for 3 crops)
Aspect 21:9, about 2560x1100. The centre 16:9 crop becomes the title screen and the loading card; the full width becomes the store banner.
> Wide cinematic 2D anime fighting-game key art. KESTREL (left) and BRIGGS (right) collide at the centre, her piston gauntlet meeting his hydraulic fist in a white flash of steam and red sparks. Inked impact lines and speed lines radiate out. They fill the middle 55% of the frame, drawn from the knees up with strong foreshortening. Behind them a painted steampunk skyline at dusk: brass towers, airships, copper pipes venting steam, warm windows, a deep teal-violet sky. KESTREL is rim-lit teal and BRIGGS rim-lit red. Leave the top 22% calm and dark for the logo and the bottom 12% calm for a loading bar. No text. [KESTREL and BRIGGS descriptions] STYLE: [style block]

## 3. Concept sheets `sheet-kestrel-briggs.png`, `sheet-odile-rook.png` (2 items)
Aspect 16:9 (2560x1440). These are references for building the fighters, so keep views orthographic and consistent.
> A character design reference sheet in two horizontal rows. TOP ROW: KESTREL in a neutral standing pose in front view, side view and back view at the same scale, plus a face close-up showing three expressions (neutral, shouting, hurt) and a small detail panel of the goggles, gauntlet and gauge belt. BOTTOM ROW: BRIGGS in the same layout, with a detail panel of the hydraulic arm. Plain light grey background, even lighting, flat cel colour with clean ink lines, a colour swatch strip under each row. About 7 heads tall, proportions consistent between views. [KESTREL and BRIGGS descriptions] STYLE: [style block]

Second sheet: the same prompt with ODILE (detail panel: backpack arms, monocle-goggles, steam cannon) and ROOK (detail panel: chain-hook, buckles, scarf).

## 4. Character-select portraits `portraits-1.png` (KESTREL, BRIGGS), `portraits-2.png` (ODILE, ROOK)
Aspect 16:9, two equal cells; each portrait is cropped to 512x512.
> Two fighting-game character-select portraits side by side, each in its own equal cell separated by a thin black gutter. Each is a bust (head, shoulders and one raised fist or weapon) in three-quarter view, the face filling about 45% of the cell, with a bold ink outline, a fierce expression, a coloured rim light, and a solid soot-black background with a faint red gauge-needle motif. Same line weight and light direction in both. No text and no names. [descriptions] STYLE: [style block]

## 5. Stage 1, AIRSHIP DECK, as parallax layers (3 items)
Side view and level camera in every layer, with no perspective tilt and no characters. The layers stack back to front, and the game scrolls them at different speeds.
- **5a `stage1-sky.png`**, 21:9 (3072x1316):
  > A painted side-view backdrop for a 2D fighting game, high above the clouds at golden hour. A huge sky with layered clouds in teal, violet and warm gold, distant airships with spinning propellers and warm windows, a far brass city of towers on floating platforms, shafts of light and depth haze. The lower 30% fades into a calm sea of cloud. Hand-painted Arcane-style texture. STYLE: [style block]
- **5b `stage1-deck.png`**, 21:9 (3072x1316), on green:
  > The deck of a brass-and-timber steampunk airship seen exactly from the side for a 2D fighting game, on a flat pure green #00FF00 background. A long flat wooden plank floor across the whole width in the lower 25%; brass railings with rope lines along the back edge; a large mast with furled canvas and rigging left of centre; a copper boiler with gauges glowing red and a venting pipe right of centre; a few crates and barrels at the far ends only. Keep the middle 60% of the floor clear for the fighters. Painted, with ink outlines and cel shading matching anime fighting-game stages. STYLE: [style block]
- **5c `stage1-front.png`**, 21:9, on green:
  > Foreground silhouette elements for a 2D fighting-game stage on a flat pure green #00FF00 background: hanging ropes and a pulley at the top-left corner, the dark edge of a brass railing post at the bottom-left and bottom-right corners, and a drifting wisp of steam. Mostly empty green in the middle. Near-black soot silhouettes with a thin warm rim light. STYLE: [style block]

## 6. HUD kit `hud.png` (4 items)
Aspect 16:9. Target sizes: bar frames 600x56 per side, timer 160x120, combo badge 280x100, banner plate 900x160.
> A game UI sprite sheet on a flat pure green #00FF00 background, elements spaced far apart and nothing overlapping. (1) A mirrored pair of health bar frames across the top, shaped like long riveted brass pressure tubes with slanted ends and a thin ink outline. Each is empty inside (dark soot fill) so the game can draw the fill, with a small gauge at the outer end whose needle sits at a REDLINE red zone, and two round pips underneath, one empty and one lit red. The left frame has teal trim, the right red trim. (2) In the middle, a round brass pressure-gauge timer plate with a blank face and a red arc at the top. (3) Bottom left, a combo badge: a slanted brass plate with space for a number and the word "HITS" in bold manga lettering. (4) Bottom right, a wide banner plate for ROUND and K.O. announcements, riveted brass with torn-paper manga edges and a red stripe, blank in the middle. Flat front view, no perspective, no shadow on the background. STYLE: [style block]

## 7. Onomatopoeia and effects sheet `fx.png` (2 items)
Aspect 16:9 (3840x2160), on green, in two halves.
> A sprite sheet on a flat pure green #00FF00 background in two halves. LEFT HALF, eight manga sound-effect lettering pieces in separate cells: chunky hand-inked katakana and Latin lettering reading "ドン", "ゴゴゴ", "ドドド", "バキッ", "ズシン", "BAM", "CRASH", "WHOOSH", each with a thick black outline, a white fill, a red drop shadow, speed lines and a slight skew. RIGHT HALF, an anime effect kit: a spiky white impact starburst, a round shockwave ring, a jagged red-and-white crack burst, a diagonal slash streak, a puff of white steam, a halftone screentone square, a diagonal hatching square and a radial speed-line square, all with ink linework. STYLE: [style block]

## 8. Menu UI kit `menu-ui.png` (1 sheet)
Aspect 16:9, on green. The menus, tooltips and pause screen are built from this, and the builder 9-slices the frames.
> A game menu UI kit sprite sheet on a flat pure green #00FF00 background, elements spaced apart: (1) a wide menu button in its normal state, a brass plate with ink outline; (2) the same button highlighted, with a REDLINE red glow edge and a small gauge needle pointing at it; (3) a large rectangular panel frame with riveted brass corners and a soot interior, suitable for 9-slicing; (4) a small tooltip frame with a pointer tail, soot fill and a thin brass edge; (5) a selection cursor shaped like a red gauge needle; (6) a round toggle switch in on and off states; (7) a horizontal slider track with a brass knob; (8) a section divider bar with a small gear at the centre. Flat front view, no text, no perspective. STYLE: [style block]

---

## Item count
| # | File | Items |
|---|---|---|
| 1 | logo.png | 1 |
| 2 | title.png | 1 (3 crops) |
| 3 | sheet-kestrel-briggs.png, sheet-odile-rook.png | 2 |
| 4 | portraits-1.png, portraits-2.png | 2 |
| 5 | stage1-sky.png, stage1-deck.png, stage1-front.png | 3 |
| 6 | hud.png | 1 sheet |
| 7 | fx.png | 1 sheet |
| 8 | menu-ui.png | 1 sheet |
| **Total** | | **12 images** |

Deferred: stage 2 (clocktower interior) layers, and portraits and sheets for TOBIAS and VESPER.
