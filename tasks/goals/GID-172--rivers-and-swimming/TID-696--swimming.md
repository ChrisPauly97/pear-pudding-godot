# TID-696: Swimming state + swim animation

**Goal:** GID-172
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
