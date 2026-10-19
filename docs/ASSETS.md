# Assets: free kit now, paid drop-ins later

> **Superseded in part (2026-10-19):** the art direction is now a steampunk 2.5D anime fighter. See `docs/ART_DIRECTION.md` and `docs/HANDOFF.md`. Anything here that assumes pixel art is void.

Owner rulings (2026-10-19):
- Use free assets for now.
- Combine several free packs, but they must look like one game.
- Fine-tune what's close enough rather than hunting for a perfect pack.
- Keep a list of things to buy later as drop-in replacements.
- The game is non-commercial, so mixed licences are fine. Credit everything anyway.

Every asset gets a row in the register at the bottom before it is committed.

## 1. Fighter kit (free)

**Anchor: Oonquil's free trio.** All three are by the same artist, so the art style matches without any work.

| Fighter | Source | Size | Animations (frames) |
|---|---|---|---|
| Bancho (street brawler) | https://oonquil.itch.io/bancho | ~100-120 px | idle 7, walk 6, attack1 9, attack2 7, attack3 8, jump 10, hurt 4, wakeup 7 |
| Brute Arms (heavy) | https://oonquil.itch.io/brute-arms | ~120 px | idle 8, walk 6, attack1 8, attack2 5, attack3 8, jump 10, hurt 4, wakeup 4 |
| Batting Girl (reach) | https://oonquil.itch.io/batting-girl | ~100 px | idle 15, walk 6, attack1 5, attack2 8, attack3 10, jump 8, hurt 4, wakeup 4 |

The licence allows free and commercial use and modification. It forbids redistributing the assets as assets and **forbids using them in AI creations**. So we never feed these sprites to an image model. Edits are deterministic (scripted) or done by hand in a pixel editor.

### Filling the gaps without new art

| Missing | How we make it from what exists |
|---|---|
| Knockdown (fall) | Play `wakeup` in reverse, plus the first `hurt` frame, with a backward velocity arc. |
| Lying down / KO | Hold `wakeup` frame 0. KO adds slow-mo, a white flash and a bounce. |
| Block | Interim: `hurt` frame 0 held, with a cyan guard flash and no knockback. Final: one hand-edited guard frame per fighter (a pixel-editor job, about 1 frame each). |
| Jump attack | `attack1` (Light) and `attack3` (Heavy) played while airborne, with smaller hitboxes. |
| Win pose | `attack3`'s last frame held, plus an idle loop and a banner. |
| Intro | `walk` in from off-screen, then one `idle` cycle. |
| Special | `attack3` with a particle trail and a projectile from the FX kit. One special per fighter for now. |
| Crouch, lows, throw | Cut (see GODOT_PLAN "Design target"). |

### Unification pipeline (`tools/unify`, a script)
These steps run on every fighter sheet, including future paid ones, so packs from different artists can sit side by side:
1. **Scale:** normalise to one standing height (target 96 px at the 480x270 base). Use integer or nearest-neighbour scaling only, never smooth resampling.
2. **Baseline and pivot:** align the feet to one baseline and the body centre to the pivot in every frame. Record the pivot in the import data.
3. **Palette:** remap each sheet to one master palette (perceptual nearest colour, LAB). Each fighter keeps its own accent ramp, but skin, outline and shadow tones are shared.
4. **Outline:** force a single outline colour (`#140a1c`) and a 1 px weight. Add a 1 px outline where a pack has none.
5. **Lighting:** check the light comes from the top-left in every sheet, and flag any that doesn't.
6. **Timing:** set ticks per frame per move from MOVES.md, not from the pack's GIF timing.
7. **Contact sheet:** the script writes `media/qa/unify-<fighter>.png` (every animation in a grid at 3x). The orchestrator signs it off before import.

Second-tier free sources, used only if a gap can't be filled from the anchor, and always run through `tools/unify`:
- LuizMelo Martial Hero 1/2/3 (CC0, swordsmen).
- Dreamir Characters (has crouch and block, but is small and uses swords).

## 2. Stage, UI, FX and audio (free)

| Need | Source | Licence |
|---|---|---|
| Stage | Generated SKYLINE 88 (docs/ART_PROMPTS.md, image 5) | ours |
| Logo, key art, portraits, HUD, menus | Generated (docs/ART_PROMPTS.md, images 1-4 and 6) | ours |
| Hit sparks and blast | Free FX pack, to be chosen in A0 from itch.io's free "pixel effects" listings. Generated image 7 is the fallback. | to verify |
| Announcer | Kenney "Voiceover Pack: Fighter" (OpenGameArt) | CC0 |
| Hits | Kenney "Impact Sounds" + qubodup "Punch" (OpenGameArt) | CC0 |
| UI sounds and whooshes | Kenney "Interface Sounds" | CC0 |
| Music | Lashman "Pixel Adventure" chiptune; OGA "Fast fight battle music"; OGA "Chiptune Battle Music" | CC0 |
| Pixel editor | Pixelorama or LibreSprite | free |

## 3. Buy later (drop-in replacements)
Prices are as listed on the store pages on 2026-10-19. The commission prices are estimates.

| # | Item | Price | What it replaces or adds | Drop-in? |
|---|---|---|---|---|
| 1 | Oonquil "Batting Girl (full)" (https://oonquil.itch.io/batting-girl-full) | $7.50 | 128 px Batting Girl with 3 jump attacks, an uppercut, a special, intro, win pose and super FX | Yes. Same artist; re-run unify and the box editor. |
| 2 | Oonquil full versions of Bancho and Brute Arms | not out yet (the author says more full versions may come) | The same upgrade as #1 for the other two | Yes. Watch the author's page. |
| 3 | Pozac "Combat Effects 10" (https://pozac.itch.io/combat-effects-10-2d-pixel-art-vfx-pack) | $1.99 (on sale) | 31 animated fighting FX, replacing the free FX | Yes. It's an FX sprite swap. |
| 4 | Aseprite | about $20 | A better pixel editor for the hand-edited frames | Tool only |
| 5 | Commissioned frames: block, KO, win and taunt per fighter, by a pixel artist working from the anchor style | about $5-15 per frame (estimate), roughly $60-180 for 3 fighters | Replaces the gap fillers in section 1 with real art | Yes. They slot into the same animation names. |
| 6 | A synthwave or fighting music pack | about $10-20 (estimate, pick in G3) | Replaces the CC0 chiptune with a matched soundtrack | Yes. Audio bus swap. |
| 7 | Digital Moons "Pixel Town" rooftop night (https://digitalmoons.itch.io/pixel-town) | $4.90 | Only if the generated stage fails review | Yes. Stage layer swap. |

To make the drop-ins work, every fighter is addressed by animation names (the AnimContract), never by file names. Every FX, sound and music cue goes through an id table (`data/fx.json`, `data/audio.json`). Replacing an asset is a file swap plus a re-run of unify and the box editor. No code changes.

## 4. Register
| Asset | Source URL | Licence | Credit line | Files | Added |
|---|---|---|---|---|---|
| (filled by the builder on import) | | | | | |
