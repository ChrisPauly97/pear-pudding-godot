# TID-304: Migrate walk animation to AnimatedSprite3D/SpriteFrames

**Goal:** GID-084
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`Player.gd:72-76` manually advances a frame index each `_physics_process` tick to simulate a 4-frame walk animation. Godot's `AnimatedSprite3D` with a `SpriteFrames` resource handles frame timing natively and is the correct pattern.

The migration should preserve the existing sprite sheet layout and frame count; only the driving code changes.

## Plan

1. Change `var _sprite: Sprite3D` → `var _sprite: AnimatedSprite3D`.
2. In `_build_sprite()`: build a `SpriteFrames` resource with two animations — `"idle"` (1 frame, `_WalkTex1`) and `"walk"` (4 frames, all four textures, looped at `ANIM_FPS`). Swap `Sprite3D.new()` for `AnimatedSprite3D.new()`, assign the `SpriteFrames`, start `play("idle")`.
3. In `_physics_process()`: replace the manual `_anim_timer / _anim_frame / _sprite.texture =` block with `_sprite.play("walk")` / `_sprite.play("idle")` guarded by current animation name so we don't restart the animation every frame.
4. Remove unused fields: `_anim_timer`, `_anim_frame`, `_walk_frames` and the `WALK_FRAMES` constant.
5. The four `const _WalkTex*` preloads and `ANIM_FPS / PIXEL_SIZE` are kept — they feed the SpriteFrames.

## Changes Made

- `scenes/world/entities/Player.gd`: Replaced `Sprite3D` with `AnimatedSprite3D`.
- Removed fields `_anim_timer`, `_anim_frame`, `_walk_frames` and constant `WALK_FRAMES` — all now handled natively by the engine.
- `_build_sprite()`: creates a `SpriteFrames` resource with `"idle"` (1 frame, `_WalkTex1`, looped) and `"walk"` (4 frames, all four textures, looped at `ANIM_FPS`); removes the default `"default"` animation created by `SpriteFrames.new()`; calls `_sprite.play("idle")` on construction.
- `_physics_process()`: replaced the manual timer/frame-swap block with `_sprite.play("walk")` / `_sprite.play("idle")` guarded by `_sprite.animation != &"walk"` so the animation is not restarted each frame. Flip-h logic is unchanged.
- `_ready()`: removed `_walk_frames` initialisation (no longer needed).

Pre-existing test failures (12) unchanged — caused by Godot 4.4.1 vs 4.6 import format mismatch (BID-013 / GID-087).

## Documentation Updates

None — camera-and-player.md documents the overall camera and player architecture; this is a drop-in replacement of the driving mechanism for walk animation, not a design change.

## Documentation Updates
