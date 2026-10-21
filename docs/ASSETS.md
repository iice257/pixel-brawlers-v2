# Assets: free now, paid drop-ins later (rev 3, 3D)

Rewritten 2026-10-20 for the 3D cel-shaded steampunk direction. The pixel-art kit and `tools/unify` are dropped.

Owner rulings: free assets for now; keep a buy-later list of drop-in replacements; the game is non-commercial so mixed licences are fine, but credit everything. Downloads of the free items below are approved (2026-10-19). Every asset gets a row in the register (section 5) before it is committed.

## 1. Free assets to fetch now (exact list)

Download each into its own new, empty folder under `assets/_source/<name>/` (git-ignored), never run anything from inside it, and record the row in the register.

### Characters
| # | Asset | Source | Licence | Use |
|---|---|---|---|---|
| F1 | **VRoid Studio CC0 sample models**: `base_male.zip`, `base_female.zip`, `avatarsample_d.zip` to `avatarsample_g.zip`, `sakurada_fumiriya.zip`, `sendagaya_shino.zip` (11 zips of about 11 to 17 MB; VRM 0.x) | https://opengameart.org/content/vroid-studio-cc0-models | CC0 (released by VRoid) | A0 placeholder fighters and the fallback base for the launch pair. Fetch `base_male`, `base_female`, `avatarsample_d` and `avatarsample_e` first. |
| F2 | **VRoid Studio** (the app) | https://vroid.com/en/studio | Free app. Check VRoid's terms for models you author. | The owner or an agent with GUI access builds KESTREL and BRIGGS from the concept sheets. Not needed for A0. |
| F3 | **godot-vrm** importer | https://github.com/V-Sekai/godot-vrm (Asset Library: "VRM Importer for 3D Avatars and MToon Shader") | MIT | Imports VRM in the editor. Baked out before shipping (GODOT_PLAN A0 step 1). |
| F4 | **Blender** | https://www.blender.org/download/ | GPL (the tool) | Decimation and accessory kitbashing. Output is ours. |

### Animation
| # | Asset | Source | Licence | Use |
|---|---|---|---|---|
| F5 | **Quaternius Universal Animation Library**, Standard (free, 45 clips, GLB) | https://quaternius.itch.io/universal-animation-library | CC0 | First clip source: locomotion, crouch/crawl, death, emotes. Retarget to Godot humanoid. |
| F6 | **Quaternius Universal Animation Library 2**, Standard (free, 42 clips) | https://quaternius.itch.io/universal-animation-library-2 | CC0 | Melee combos, knockback and shield/block-like idles. Pay-what-you-want; $0 is allowed. |
| F7 | **Mixamo clips** (FBX, "without skin", 30 fps) | https://www.mixamo.com (needs the owner's Adobe login) | Free to use in projects; do not redistribute the raw clips | Fill-in fighting clips. The owner downloads these once; list below. |

Whether UAL1/UAL2 Standard contain real punch and kick clips is unconfirmed from their store pages (UAL2 lists melee hooks, sword combos, throws and KNOCKBACK). The A0 builder lists what is actually in the zips in the register. Anything missing from the A0 clip list in GODOT_PLAN is requested from Mixamo.

**Mixamo list for the owner** (character: "Y Bot", format FBX Binary, Skin: Without Skin, 30 fps, "In Place" on): Boxing Idle, Fight Idle, Standing Walk Forward / Back (or Walking), Crouch Idle, Crouch Walk, Standing Block Idle, Crouching Block Idle, Jab Cross, Hook Punch, Uppercut, Cross Punch, Roundhouse Kick, Front Kick, Low Kick (Leg Sweep), Crouching Punch or similar, Head Hit, Standing React Large From Front, Stand To Roll or Knocked Down, Getting Up, Dying, Victory Idle or Victory, a Taunt. Names on Mixamo vary; the builder maps what the owner downloads to the animation contract.

### Environment kits, textures and props
Pick at G1. Candidate sources, all CC0 unless noted, to be checked at the time of fetching: Kenney 3D kits (https://kenney.nl/assets), Quaternius kits (https://quaternius.com), Poly Pizza (https://poly.pizza, per-model licence), Sketchfab CC-BY steampunk props (credited). The builder proposes a shortlist of exact packs for the airship deck (rails, rigging, crates, pipes, propellers) and the orchestrator approves it before download. Painted far planes are generated (ART_PROMPTS image 5).

### Audio and fonts
| # | Asset | Source | Licence |
|---|---|---|---|
| F8 | Kenney "Voiceover Pack: Fighter" | OpenGameArt | CC0 |
| F9 | Kenney "Impact Sounds", "Interface Sounds"; qubodup "Punch" | OpenGameArt / kenney.nl | CC0 |
| F10 | Music: CC0 or CC-BY orchestral/steampunk/industrial loops from OpenGameArt and Pixabay Music (credited); chosen in G2/G3 | opengameart.org, pixabay.com/music | CC0 / CC-BY / Pixabay licence |
| F11 | Fonts: Bangers (Latin comic), Dela Gothic One and Noto Sans JP Black (katakana onomatopoeia), Cinzel or a similar engraved face for the logo-adjacent UI | Google Fonts | OFL |

### Generated (ours)
Logo, key art, concept sheets, portraits, airship backdrop, HUD kit and onomatopoeia sheet: `docs/ART_PROMPTS.md`.

## 2. Style-control rules for mixed sources
- One skeleton: every fighter is a Godot-humanoid-retargeted VRM-derived model. Never mix rigs inside the sim.
- One shader and one palette-ramp spec for all characters and props, so mixed sources look uniform.
- Props from different kits get re-materialled with the toon shader and share the brass/copper/teal palette from `ART_PROMPTS.md`.
- Check the web budget (GODOT_PLAN) before adding any asset.

## 2b. Making a fighter in VRoid (budget-safe export)
Web budget per fighter: 15,000 triangles or fewer, 6 materials or fewer, textures 1024 px or smaller (GODOT_PLAN A0); the 150 draw-call limit governs (the outline pass doubles the draws).
- In VRoid Studio, before export, use **Export as VRM 0.x** (not 1.0).
- In the export dialog: turn **Polygon Reduction on**, reduce **hair** (fewer hair meshes and bundles), and set **Texture atlas / texture size to 1024**. Turn on the export option to **reduce materials** and aim for 4 to 6 materials (VRoid merges them; we do not merge at bake time).
- Keep the standard humanoid skeleton; no extra bones are needed (spring bones and blend shapes are stripped in the bake).
- Bake it: `tools/bake_fighter.sh <vrm> <id>`. The script prints and writes `fighters/<id>/budget.json` (triangles, materials, source texture size) and exits with code 3 when over budget; the model is still baked so it can be inspected.
- Optional per-character tuning goes in `fighters/<id>/look.json` (shade colours, outline widths, texture flatten boxes, accessories).
- Status at 2026-10-21: `a0` (VRoid Base_Female) is 14,804 triangles and 15 materials, accepted as a sample; `e` (AvatarSample_E) is 26,706 triangles. Real characters take their material count from VRoid's reduce-materials export.

## 3. Buy later (drop-in replacements)
Prices are estimates unless a store page was checked on the date shown. Nothing here is needed before A0.

| # | Item | Estimate | What it replaces or adds | Drop-in? |
|---|---|---|---|---|
| 1 | Booth.pm steampunk or military-fantasy VRoid outfit and accessory packs (goggles, gauntlets, coats, gears) | about $5 to 30 each | Replaces our kitbashed outfits with finished, VRM-ready clothing for KESTREL and the later roster | Yes. Re-run the toon-material pass; check each seller's terms (no redistribution of the raw files). |
| 2 | A paid steampunk 3D environment kit (Unity or Unreal asset-store packs with FBX; check licence allows use in other engines) | about $20 to 60 | Replaces the free airship/clocktower props with a coherent set | Yes. Props swap; re-material with the toon shader. |
| 3 | A fighting-game animation pack (Mixamo replacement, since the owner cannot use Mixamo). Shortlist (2026-10-21, prices from the store listings): **Kubold Fighting Animset Pro** ($80, more than 230 unarmed FBX Humanoid clips covering crouch, punches, kicks, blocks, hits, KO and get-ups; this is the pick); Basic Melee Action Animation ($9.99, 28 clips including a sweep kick and block); Fighting Motions Vol.3 ($12, 50 kicks). Asset Store EULA: use in any engine is fine, but do not redistribute the raw clips. | $10 to 80 | Kicks, uppercut, real blocks, crouch attacks, sweep, get-up, win and taunt (the gaps in UAL1/UAL2) | Yes. Retarget the FBX Humanoid clips; they are addressed by name in the AnimMap. |
| 4 | Commissioned VRoid-based character models with hand-tuned face and hair textures | about $50 to 200 per character | Replaces our own VRoid builds with a polished artist's version | Yes, if delivered as VRM (same skeleton rules). |
| 5 | A commissioned or licensed steampunk/industrial soundtrack and announcer set | about $20 to 100 for a pack; more for a commission | Replaces the free music and voiceover | Yes. Audio bus and id-table swap. |
| 6 | Commissioned key art, logo and select portraits by a human illustrator | about $100 to 500 per piece | Replaces the generated art for the portfolio-grade finish | Yes. Same file slots. |
| 7 | A VFX pack for stylised hits, smoke and slash effects (Godot or Unity textures/atlases) | about $10 to 30 | Replaces our home-made steam/spark/shockwave textures | Yes. FX id-table swap. |
| 8 | Blender add-ons such as a rigging/retargeting helper and Rigify extras (some are paid; most are free) | about $0 to 40 | Speeds up outfit and accessory fitting | Tool only |

Drop-ins work because every fighter animation is addressed by contract names (never file names) and every FX, sound and music cue goes through an id table (`data/fx.json`, `data/audio.json`). A swap is a file replacement plus a re-run of the import step and the box editor. No code changes.

## 4. Rules on generated and third-party assets
- Generate images from text only. Do not feed third-party art, VRoid models or animations into image models.
- Keep VRM models and animation source files out of git unless small. Commit the processed Godot resources and a `README` per `assets/` subfolder listing the sources.

## 5. Register
| Asset | Source URL | Licence | Credit line | Files | Added |
|---|---|---|---|---|---|
| Kenney Pirate Kit 2.1 (props: ship parts, platforms, masts, flags, crates, barrels, cannons, rocks) | https://kenney.nl/assets/pirate-kit | CC0 1.0 (confirmed on the kit page and in its License.txt) | Kenney (www.kenney.nl), optional | `assets/src/kenney-pirate-kit/` (source only, gitignored, GLB under `pkg/Models/GLB format`) | 2026-10-21 |
| Bangers Regular (HUD banners and timer) | https://github.com/google/fonts/tree/main/ofl/bangers | OFL 1.1 (`assets/fonts/OFL-Bangers.txt`) | Vernon Adams, optional | `assets/fonts/Bangers-Regular.ttf` | 2026-10-21 |
