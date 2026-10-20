# Generated art: 7 images, 15 items (rev 3, steampunk 2.5D anime)

Rewritten 2026-10-20 for the 3D cel-shaded steampunk direction (`docs/ART_DIRECTION.md`). The pixel-art prompts are gone.

These prompts are for any modern image model (Gemini / Nano Banana, GPT Image, Midjourney; use Ideogram for the lettering in images 1 and 7). Generate from text only. Never upload third-party art as a reference.

**Paste the style block at the end of every prompt** so the set reads as one game.

> STYLE: stylised anime illustration in the spirit of JoJo's Bizarre Adventure: All-Star Battle crossed with Arcane and Genshin Impact. Bold manga ink linework with varied line weight, heavy black shadow shapes, hard two-band cel shading, screentone and hatching in the deepest shadows, dramatic poses. Steampunk palette: brass #c9a14a, copper #b8643a, oxidised teal #2f7f7a, soot #14121a, cream steam #efe6d2, with one hot accent of glowing amber #ffb347. Painterly, hand-brushed backgrounds in Arcane's style. Clean Genshin-style anime faces. No watermark, no signature, no text unless asked.

**Roster used in the prompts.** No elemental powers: the tech is gadgets, gauntlets, pistons and steam.
- **KESTREL** (launch fighter 1): lean airship duellist, late 20s, short swept-back dark hair, brass goggles pushed up on the forehead, a cropped teal coat with brass buttons, piston-assisted gauntlets, a belt of small gears and pressure gauges, fast and confident.
- **BRIGGS** (launch fighter 2): broad foundry brawler, 40s, shaved head, thick moustache, a scarred leather apron over a bare chest, one oversized hydraulic gauntlet arm with a glowing amber vent, heavy boots.
- Later roster (concept sheets come in G4): **ODILE** (gadgeteer with a clockwork backpack), **TOBIAS** (old watchmaker martial artist), **VESPER** (masked clockwork assassin), **ROOK** (smog-district youth with a chain hook).

**Handling after generation:** the builder crops, downsizes to the target sizes (power-of-two for textures, width 2048 or less) and keys out `#00FF00` backgrounds. Originals live in `assets/_source/`. Processed files go in `assets/ui/`, `assets/stages/` and `assets/concept/`. Concept images are references for modelling, not shipped.

---

## Image 1: Logo (1 item)
Aspect 3:1. Target 1024x340.

> Game logo wordmark reading exactly "PIXEL BRAWLERS" on two lines, "PIXEL" smaller above, "BRAWLERS" large and wide below. Heavy engraved brass letters with a thick black ink outline and a bevelled metal highlight, rivets at the corners, small gears and a wisp of steam tucked behind the "B", a slight forward lean, and a jagged manga impact burst behind the whole mark. Centred on a flat pure green #00FF00 background with nothing else in the frame. STYLE: [style block]

## Image 2: Key art, cropped into the banner and the menu background (3 items: key art, banner, menu background)
Aspect 21:9 (about 2560x1100). Crop the centre to 16:9 for the title hero, use the full width for the portfolio banner, and use the darkened right half as the menu background.

> Wide cinematic fighting-game key art. KESTREL (left) and BRIGGS (right) lunge at each other at the centre in a mirror pose, fists meeting in a burst of steam and sparks, with a manga speed-line background and inked impact lines radiating out. They fill the middle 55% of the frame, drawn from the knees up. Behind them is an Arcane-style steampunk city at dusk: brass towers, airships, copper pipes venting steam, warm amber windows, a teal-violet sky. KESTREL is rim-lit teal and BRIGGS rim-lit amber. Keep the top 20% fairly calm for a logo. There is no text. [KESTREL and BRIGGS descriptions] STYLE: [style block]

## Image 3: Character concept sheets (2 items: KESTREL sheet, BRIGGS sheet)
Aspect 16:9 (2560x1440). Two rows, one fighter each, so neither is cramped. These are modelling references for VRoid and Blender, so keep the views orthographic and consistent.

> A character design reference sheet in two horizontal rows. TOP ROW: KESTREL in a neutral standing pose, shown in front view, side view and back view at the same scale, plus a close-up of the face and a small panel of the goggles, gauntlet and belt details. BOTTOM ROW: BRIGGS, the same layout. Plain light grey background, even lighting, flat colour with thin ink lines, a labelled colour swatch strip under each row (no text other than swatch hex codes is needed). Keep proportions consistent between views. [KESTREL and BRIGGS descriptions] STYLE: [style block]

## Image 4: Character-select portraits (2 items: KESTREL, BRIGGS)
Aspect 16:9 (2560x1440), two large cells side by side so each portrait gets full detail. Target 512x512 per portrait after a square crop. The other four portraits are generated in G4.

> Two fighting-game character-select portraits side by side, each in its own equal cell separated by a thin black gutter. Each is a bust (head, shoulders and one raised fist) in three-quarter view, the face filling about 45% of its cell, with a bold ink outline, a strong confident expression, a coloured rim light, and a solid soot-black background with faint gear and steam motifs. Left, KESTREL with teal rim light. Right, BRIGGS with amber rim light. Use the same line weight and the same light direction for both. There is no text and no names. [KESTREL and BRIGGS descriptions] STYLE: [style block]

## Image 5: Stage 1, AIRSHIP DECK far backdrop (1 item)
Aspect 21:9 (3072x1316). Used as the painted far plane. The 3D mid plane (railings, rigging, crates) is built from kits, so keep this image to sky and distance.

> A painted side-view background for a 2D fighting game, with no characters. High above the clouds at golden hour, seen from the deck of a vast brass airship. A huge sky with soft layered clouds in teal, violet and warm gold, distant airships with spinning propellers and glowing amber windows, a far brass city of towers on floating platforms, shafts of light, drifting steam and a few birds. Arcane-style hand-brushed texture, soft painterly edges, strong depth with haze in the distance. The lower 25% fades to calm dark cloud and mist so a deck floor can sit over it. The camera is level with no perspective tilt. STYLE: [style block]

## Image 6: HUD kit (4 items: health bar frames with round pips, timer plate, combo badge, round and KO banner plate)
Aspect 16:9. Targets: a bar frame of 600x56 per side, a timer plate of 160x120, a combo badge of 280x100, a banner plate of 900x160.

> A game UI sprite sheet on a flat pure green #00FF00 background, elements spaced far apart and nothing overlapping. (1) A pair of mirrored fighting-game health bar frames across the top, one per player, shaped like riveted brass-and-copper pressure gauges with slanted ends and a thin ink outline; each is empty inside (a dark soot fill) so the game can draw the fill, and each has two small round brass pips underneath, one empty and one lit amber. The left frame has a teal trim, the right an amber trim. (2) In the middle, a round brass timer plate shaped like a pocket-watch, blank face, with a small gear behind it. (3) At the bottom left, a combo badge: a slanted brass banner with room on its left for a number and the word "HITS" in bold manga lettering. (4) At the bottom right, a wide banner plate for ROUND and KO announcements, riveted brass with torn-paper manga edges, blank in the middle. Flat front view, no perspective, no shadow on the background. STYLE: [style block]

## Image 7: Onomatopoeia and effect sheet (2 items: onomatopoeia sheet, screentone/impact set)
Aspect 16:9 (3840x2160). Both items sit on one flat sheet in two clearly separated halves. Use Ideogram or similar for the lettering.

> A sprite sheet on a flat pure green #00FF00 background in two halves. LEFT HALF, a set of eight manga sound-effect lettering pieces, each in its own cell and nothing overlapping: large chunky hand-inked Japanese katakana and Latin lettering reading "ドン", "ゴゴゴ", "ドドド", "バキッ", "ズシン", "BAM", "CRASH", "WHOOSH", each with a thick black outline, a white inner fill, speed lines and a slight skew. RIGHT HALF, an effect kit: four impact-burst shapes (a spiky white starburst, a round shockwave ring, a jagged crack burst, a diagonal slash streak), a tileable halftone screentone dot pattern in a square, a tileable diagonal hatching pattern in a square, and a set of radial speed-line backgrounds in a square, all black and white with ink linework. STYLE: [style block]

---

## Item count
| Image | Items |
|---|---|
| 1 Logo | 1 |
| 2 Key art, banner, menu background | 3 |
| 3 Concept sheets (KESTREL, BRIGGS) | 2 |
| 4 Portraits (KESTREL, BRIGGS) | 2 |
| 5 Airship deck backdrop | 1 |
| 6 HUD kit | 4 |
| 7 Onomatopoeia and effect sheet | 2 |
| **Total** | **15** |

Deferred to later phases (not in the 15): the clocktower stage backdrop, four more portraits and concept sheets for the later roster (G4), and a loading screen made from a crop of Image 2 or 5.
