> **Rev 5 (2026-10-22): the game is REDLINE, and the look is 2D anime animation on 3D rigs with painted 2D stages. `docs/ART_PROMPTS.md` holds the current style block and palette (REDLINE red #e3262f is the brand accent). Where this file disagrees, ART_PROMPTS and GODOT_PLAN rev 5 win.**

# Art direction: steampunk 2.5D anime fighter

Owner decision (2026-10-19): a steampunk fighting game with 3D cel-shaded anime characters and semi-3D environments that move like real places. The pixel-art direction is dropped. That supersedes the fighter kit in `ASSETS.md` and the pixel style in `ART_PROMPTS.md`.

## References, in priority order
1. **JoJo's Bizarre Adventure: All-Star Battle** (top priority). Bold manga ink, heavy black shadow shapes, dramatic poses, on-screen onomatopoeia (ゴゴゴ, ドドド), colour-inverted impact frames, and palette shifts during supers.
2. **Arcane** and **Genshin Impact** (high priority).
   - From Arcane: painterly, hand-brushed environments; a Piltover/Zaun steampunk mood with brass, copper, steam and glowing tech.
   - From Genshin: clean anime faces, soft skies, bloom on elemental effects, readable silhouettes.
3. **Dragon Ball (Goku)** and **Naruto** (secondary). Auras, energy blasts, speed-line dashes, crater impacts and chakra-like elemental effects.

## The look in one paragraph
Anime 3D characters are rendered as if hand-drawn. They use hard two- or three-band cel shading, ink outlines of varying thickness, and hatching or screentone in the deepest shadows. Characters animate at stepped 12-15 fps over a 60 Hz game, with held key poses, the "limited animation" trick ArcSys uses in DBFZ and Strive. They fight in front of steampunk cities and machinery painted in Arcane's brushed style. Hits flash to inverted black-and-white frames with manga sound-effect lettering. Supers cut to a close camera with a palette shift and speed lines.

## Setting (owner decided 2026-10-20)
**Steampunk, no elemental powers.** Brass cities, steam, clockwork and pressure machinery. Power comes from gadgets, gauntlets, pistons and martial skill, not an energy system. DBZ/Naruto-style auras and blasts are rendered as steam, sparks, shockwaves and pressure bursts, with glowing brass-tech accents (Arcane's mood). Stage ideas: an airship deck above the clouds, a clockwork tower interior with turning gears, a smog-district rooftop market, and a foundry with molten channels.

## Gameplay plane (decided)
Gameplay stays on a **2D fighting plane**, like DBFZ, Strive and Street Fighter 6. JoJo ASB's free 3D movement is not used. The camera, characters and stages are 3D, but movement is left and right only. So the existing deterministic 2D sim, its rules and its tests carry over unchanged. JoJo is a visual reference, not a movement model.

## Production pipeline
| Layer | Approach | Tools / sources |
|---|---|---|
| Character bases | Anime humanoids built in VRoid Studio (gives Genshin-quality faces and hair), exported as VRM | VRoid Studio (free); the godot-vrm importer with the MToon shader (MIT) |
| Steampunk outfits | VRoid texture and outfit editing, plus accessories (goggles, gauntlets, gears, coats) kitbashed in Blender | Blender (free); free and paid Booth.pm accessories |
| Animation | Retargeted humanoid clips: stances, punches, kicks, blocks, hit reactions, knockdowns, get-ups, taunts, victories | Mixamo (free with an Adobe account); Quaternius Universal Animation Library (CC0); Godot's built-in humanoid retargeting |
| Anime timing | Play clips stepped at 12-15 fps, hold active frames, add smear frames on big hits | Our AnimationTree setup |
| Shading | A custom toon shader instead of stock MToon for the final look: 2-3 hard light bands, a rim light, inverted-hull outlines plus depth/normal edge lines, and screentone in shadows | Godot shaders |
| FX | Particles and mesh effects for steam bursts, sparks, shockwaves and impacts; 2D sprite overlays for onomatopoeia, speed lines and impact frames | GPUParticles3D; generated lettering sheets |
| Environments | Real 3D scenes seen from a fixed side camera (true parallax for free), modular kits for the near and mid planes, painted backdrops (generated, Arcane style) on the far planes, plus moving parts: airships, steam, gears, crowds, weather | Kenney and Quaternius kits (CC0), Poly Pizza, Sketchfab (CC-BY, credited), generated backdrops |
| Concept art, portraits, key art, UI | Image generation from text, with the prompts rewritten for this style | `ART_PROMPTS.md` (needs rev 2) |

## Engine verdict: stay on Godot 4
Unreal is the industry's choice for this look: DBFZ, Strive and the Naruto Storm games are built in it. It's still the wrong choice here:
- **Unreal assets are binary (.uasset)** and much of the logic is in Blueprints. AI agents can't read, diff or edit them reliably, and this project is built by agents.
- **Iteration is heavy**: a 50-100 GB install, C++ compile cycles and shader compiles.
- **Unreal has no web export at all.**

Godot keeps scenes, resources and scripts as text. It has VRM and humanoid retargeting, and it can do this level of cel shading. Our studio-quality look comes from the shader, the stepped animation and the FX, not from engine features.

**Render target (owner decided 2026-10-20): web first.** This is a browser game, not a download. The Compatibility renderer (WebGL2) is the target and everything must hit its frame budget in the browser. Forward+ extras are optional later and never required. Fidelity comes from the toon shader, inverted-hull outlines, stepped animation and painted backdrops, all of which work in Compatibility.

## Owner answers (2026-10-20)
1. Platform: **web first, full game in the browser.** Desktop builds are not a goal.
2. Setting: **steampunk, no elements** (see Setting).
3. Roster: **2 for the first playable, 6 by G4.**
