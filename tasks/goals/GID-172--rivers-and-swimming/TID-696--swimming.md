# TID-696: Swimming state + swim animation

**Goal:** GID-172
**Type:** agent
**Status:** done
**Depends On:** TID-694

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Deep water should be swum, not blocked.

## Research Notes

- Add a shared `deep_at(wx, wz)` (sea `Coast.is_deep` OR river depth ≥ WADE_DEPTH, minus piers/bridges) in WaterMath or a new `game_logic/world/WaterDepth.gd`.
- Replace `Coastline._physics_process` slide-back with swimming; keep its teleport/load 'wade ashore' branch.
- `scenes/world/entities/Player.gd`: swim state → speed × ~0.55 (`_get_move_speed`), sprite lowered to chest (crop with `region_rect` like Coastline crew, or shift down + water clip), gentle bob. Anim chosen in `HeroAnim.pick` — add `swim` / `tread` (idle in water). Frames rendered procedurally by `game_logic/character/PaperDoll.gd` (`build_frames`, `render_pose`) — add swim poses (arm strokes). Mind `HeroAnim.BACK_OF` for back-facing.
- While swimming: auto-dismount (`Mounts` module / `SaveManager.is_mounted`), disable Dig/Phase (`Cantrips`), no interactions, no enemy engage. Ripple ring + splash particles (AmbientTouches has wet footstep splashes to reuse).
- Footsteps: `_surface_underfoot` → water stroke sounds.

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

1. Pure tuning `game_logic/world/Swimming.gd` (speed, sink, stroke frames, path cost).
2. PaperDoll `swim` (4-frame crawl) / `tread` (2) + back views; HeroAnim.pick(..., swimming), BACK_OF, is_swim.
3. Player (at its 500-line cap → first move the dust-material boilerplate into `AmbientParticles.dust_material`):
   `swimming` + `set_swimming`, swim speed, sprite sink, no jump, splash dust, stroke sfx.
4. Coastline: replace the slide-back with the swim switch (dismiss mount on entry). WorldScene stays under its ceiling.
5. Mounts.toggle and Skeleton Dig refuse while swimming.
6. Pathfinder optional `cost_lookup` (+ cost-aware smoothing); TapToMove.step_cost → deep water `PATH_COST`.
7. Tests: `test_swimming`.

## Changes Made

- New `game_logic/world/Swimming.gd`.
- `PaperDoll.ANIMS` swim / tread, `BACK_ANIMS` swim_back / tread_back; `HeroAnim.pick(.., swimming = false)`, `is_swim`.
- `Player.gd`: `swimming`, `set_swimming()`, swim speed in `_get_move_speed`, sink in `_update_mount_visuals`, jump blocked,
  splash dust, stroke sfx in `_on_sprite_frame_changed`. Dust materials now from `AmbientParticles.dust_material()` (−32 lines).
- `Coastline._physics_process`: swim switch instead of slide-back / teleport wade-ashore (`_last_safe`, `TELEPORT_DIST` removed).
- `Mounts.toggle`, `Cantrips.activate_skeleton_dig`: refuse while swimming.
- `Pathfinder.find_path(.., cost_lookup)`, cost-aware `_has_line_of_sight` / `_smooth_path`; `TapToMove.step_cost`; deep water no longer a wall.
- `tests/unit/test_swimming.gd` (4 tests). Suite 3067 pass / 0 SCRIPT ERROR; world, chunk, town, in-world-battle smokes clean; gdlint + unsafe-hits clean.
- Not verified visually: swim sprite sink / stroke frames should be eyeballed in a real run.

## Documentation Updates

`docs/agent/camera-and-player.md` (new Swimming section); `world-generation.md` (Rivers + eastern-sea table: swim instead of block); CLAUDE.md map note + Coastline row.
