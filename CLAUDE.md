# Pixel Brawlers v2: working notes for agents

- Engine: Godot 4.7.2, GDScript, GL Compatibility renderer (required for the web build). Windows binary: `%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe`.
- Roles: an orchestrator session plans and reviews; a builder session builds. They message each other directly; never ask the owner to relay messages.
- Plan: `docs/GODOT_PLAN.md`. Design spec carried from v1: `docs/ref/` (rules and numbers only, never port the v1 JS code).
- Art, UI and audio come from asset packs in `assets/`, each with its licence. Do not draw art in code.
- Game logic runs at a fixed 60 Hz in `_physics_process`; keep it deterministic (no `randf()` without a seeded RNG).
- Before reporting a phase: run `GODOT=<godot exe> sh tools/run_tests.sh` and attach screenshots (`godot --path . -- --shot=<abs png path>` saves a scripted QA frame).
- Commits: no attribution lines.
