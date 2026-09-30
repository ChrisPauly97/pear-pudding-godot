# TID-645: Enemy walk cycles

**Goal:** GID-152
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Every enemy is a single static frame; they wander and chase with only an idle bob (`CharacterPresence._update_idle_life`). Part of GID-152 (art motion pass).

## Research Notes

- `tools/generate_characters.py`: `_walk(frame)` leg/arm swing rig and `WALKERS = {"npc_maiteln"}` (L484) gate which characters write `<name>_walk_1..4.png`. Add all `enemy_*` in `CAST` (plus quadruped/blob rigs: wolf, stag, scarab, spectre float frames, worm, larva-like) — non-humanoid rigs need their own frame functions.
- Runtime: `SpriteRegistry.make_idle_walk_frames(idle_tex, walk_texs, …)` (L378) + `maiteln_walk_frames()` pattern; add a table of walk-frame preloads per enemy texture (preload only, Android rule) and a lookup `enemy_walk_frames(tex_key)`.
- `scenes/world/entities/EnemyNPC.gd`: `_sprite: Sprite3D` built via `make_billboard` (L38). Switch to AnimatedSprite3D when frames exist (see `MaitelnFollower._build_animated_sprite()`), play `walk` while moving (wander/`_chase_player`), `idle` otherwise; flip_h by move x. Keep `_valid_node3d` patterns; CharacterPresence registers sprites for bob — keep working with AnimatedSprite3D. `SpriteOutline.apply()` handles AnimatedSprite3D frame_changed.
- Update `docs/agent/art-sprites.md` Generated characters section.

## Plan

1. Rig enemies → `WALKERS`, frames cropped to a shared box. ASCII roster → derived stride/bob frames.
2. `WalkFrames.gd` preload table + `SpriteRegistry.walk_frames()`.
3. `WalkCycle` node on EnemyNPC (leader + pack followers): swap Sprite3D textures by measured speed.

## Changes Made

- `tools/generate_sprites.py` (`TRIM` switch), `tools/generate_characters.py` (all enemies but mimic walk,
  `walker_frames` shared crop), `scripts/gen_creature_sprites.py` (`walk_frames`, `FLOATERS`).
- 88 new `enemy_*_walk_{1..4}.png`; `enemy_ghoul.png` regenerated 2 px wider.
- New `game_logic/WalkFrames.gd`, `game_logic/WalkCycleMath.gd`, `scenes/world/entities/WalkCycle.gd`.
- `game_logic/SpriteRegistry.gd`: `walk_frames()`. `scenes/world/entities/EnemyNPC.gd`: `_add_walk_cycle()`.
- Test: `tests/unit/test_walk_cycle.gd`.

## Documentation Updates

- `docs/agent/art-sprites.md`: "Enemy walk cycles".
