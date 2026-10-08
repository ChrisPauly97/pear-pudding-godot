# TID-705: Bog gameplay: slow, critters, enemies

**Goal:** GID-174
**Type:** agent
**Status:** done
**Depends On:** TID-703

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Bogs should matter to play.

## Research Notes

- Player speed × ~0.5 in bog (`Player._get_move_speed`), squelch footsteps (`FootstepSurface`), no mounting/auto-dismount.
- `TapToMove`/`Pathfinder`: bog = high-cost tile (shares the per-tile cost hook from TID-695 if done).
- Critters (`CritterDef`: frogs, flies) and a bog enemy entry in `EnemyRegistry` / `BiomeDef` pools.
- Tests + docs (world-generation.md).

Shared constraints: chunk-gen code (`InfiniteWorldGen`/`RealmLayout`/`TerrainMath`/`WaterMath`) runs on worker threads (BID-088) — pure, no autoloads/scene tree; lazily built statics go in `InfiniteWorldGen.warm()`. Explicit types (no `:=` on Variant), no unsafe access, preload scripts (no class_name), gdlint 120 cols, run `scripts/unsafe-hits.sh`, headless import, `godot --headless --path . -s tests/runner.gd` and check for `SCRIPT ERROR`. Docs: `docs/agent/world-generation.md`.

## Plan

Hero slowed in bogs (mounted too — deviation: no forced dismount), squelch footsteps, tap-to-move bog cost, bog hags
spawn in bogs (existing enemy), frog + night will-o'-wisp critters (new sprites from the generator script). Tests: unit
+ a bog section in the real-scene smoke.

## Changes Made

- `WaterMath`: BOG_SLOW / BOG_SPEED_MULT / BOG_PATH_COST / BOG_HAG_LEVEL.
- `Player.gd`: `_bog_underfoot()`, bog slow in `_get_move_speed`, squelch in `_surface_underfoot` (file at exactly 500 lines).
- `TapToMove.step_cost`: bog tiles cost 2.
- `InfiniteWorldGen.enemy_type_at`: bog → `bog_hag` (+ WaterMath preload).
- Critters: `scripts/gen_creature_sprites.py` FROG / WISP → `assets/textures/critters/{frog,wisp}_{0,1}.png` (existing
  sprites regenerate byte-identical); `CritterDef` frog / wisp, `night_only`, `glow`, `BOG_CRITTERS`, `species_for_bog`,
  `visible_now`, `fits(.., in_bog)`; `Critter.gd` glow modulate; `Critters` bog spawning and culling.
- Tests: `test_bogs` +1; `tests/swim_smoke.gd` bog section (slow, squelch, path cost). Suite 3086 pass / 0 SCRIPT ERROR;
  world, town, chunk, in-world-battle, menu, swim smokes clean; gdlint + unsafe-hits clean.
- Not verified visually: frog / wisp sprites at game scale.

## Documentation Updates

`docs/agent/world-generation.md` (Bogs → Gameplay); CLAUDE.md map note.
