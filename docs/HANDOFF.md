# Planner handoff (2026-10-19)

This is for a fresh planner/orchestrator session that picks up Pixel Brawlers v2. Read this first, then the docs it points to. Do not re-derive these decisions.

## Roles
- **The planner/orchestrator (you)** plans, reviews gate evidence and gives rulings. It writes no product code.
- **The builder** is the Claude session titled "Pixel Brawlers: Building" (id `local_fbf3fd20-14e2-44d5-b125-0b96fa92832b`). Message it directly with SendMessage. Never ask the owner to relay. (On 2026-10-19 the titles were briefly swapped by mistake; this is the corrected state.)
- The owner reviews at each gate and makes product calls. Owner preferences are in `~/.claude/CLAUDE.md`: be brief, act first, no lectures, ask only when blocked.

## Where things are
- v2 repo: `C:\Users\0\Documents\Projects\Github\pixel-brawlers-v2` (https://github.com/iice257/pixel-brawlers-v2). Godot 4.7.2, GDScript, CI runs the GUT tests, and Pages hosts the web build.
- v1 repo (JS, reference only, to be archived at parity): `C:\Users\0\Documents\Projects\Github\pixel-brawlers`.
- The spec carried from v1 (rules and numbers only) is in `docs/ref/`. TUNING_LOG beats GAME_DESIGN when they conflict.

## Decisions so far (newest first)
0. **2026-10-20 owner answers and plan rev 3.** Web first (full game in the browser, Compatibility renderer), steampunk with no elemental powers, roster 2 then 6. `docs/GODOT_PLAN.md` rev 3 is current: A0 character-pipeline proof, then G1 to G5. Crouch and lows are back; throws, overheads and meter stay deferred. `ART_PROMPTS.md` (7 images, 15 items) and `ASSETS.md` (free fetch list, Mixamo list, 3D buy-later list) are rewritten.

1. **The art direction changed to a steampunk 2.5D anime fighter** (`docs/ART_DIRECTION.md`). Gameplay stays on a 2D plane. Characters are 3D cel-shaded: VRoid + Mixamo, Godot humanoid retargeting, a custom toon shader, stepped 12-15 fps animation. Environments are semi-3D with painted backdrops. Engine stays Godot (Unreal was rejected: binary assets, no web export).
2. **Free assets for now**, with a buy-later list kept for drop-in replacements. The non-commercial project can mix licences, but everything is credited.
3. **The design is simplified to a four-button fighter**: Light, Medium, Heavy, Special, plus hold Block, and Throw only if animated. Crouch, lows and overheads, meter, and command motions are deferred (GODOT_PLAN "Design target"). With Mixamo's large clip library, crouch and lows can come back; decide in plan rev 3.
4. **Plan rev 2** (`docs/GODOT_PLAN.md`): an asset lock (A0) comes before combat, then a real-art vertical slice in G1, and the owner playtests at every gate. **Superseded where it assumes pixel art.**
5. **Superseded:** the pixel-art fighter kit, `tools/unify` and the pixelize pipeline in `docs/ASSETS.md`, and the pixel style block in `docs/ART_PROMPTS.md`. The buy-later list idea survives but needs new items for 3D.

## State of the build
- **G0 is done** (5fb30c8): the 60 Hz deterministic sim (walk, jump, push, facing), the animation contract, rebindable controls (R1 layout), 9 GUT tests, CI and Pages.
- **The builder is on the G1 combat core**, asset-agnostic: hit and block, stun, pushback, chains, KO, rounds and tests. It has been told not to touch rendering or assets until plan rev 3.

## Next steps for the planner
1. Get the owner's answers to the open questions in `ART_DIRECTION.md` (desktop-first, setting, first roster size).
2. Write **plan rev 3**. Re-cut the phases for the 3D pipeline:
   - A0: character pipeline proof. One VRoid character, steampunk-dressed, Mixamo clips retargeted, the toon shader, stepped animation, shown in a side-view test scene.
   - G1: vertical slice with 2 fighters on 1 stage.
   - G2: feel, FX and the CPU.
   - G3: front end.
   - G4: content.
   - G5: ship.

   Keep the 2D sim and the tests. Decide whether to restore crouch and lows.
3. Rewrite `ART_PROMPTS.md` for the new style (concept sheets per fighter, stage paintings, logo, key art, portraits, HUD, onomatopoeia sheet; 15 items, 6-7 images) and rewrite the buy-later list for 3D: Booth.pm outfits, paid steampunk kits, a music pack, an Aseprite-equivalent if any, and commissions.
4. Downloads are approved by the owner (2026-10-19) for the free assets the plan names. List the exact items in ASSETS.md before the builder fetches them.
