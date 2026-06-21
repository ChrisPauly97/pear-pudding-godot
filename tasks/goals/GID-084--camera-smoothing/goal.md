# GID-084: Camera Smoothing & Walk Animation

## Objective

Eliminate camera micro-stutter on high-refresh Android displays and modernise the player walk animation to use engine-native sprite frames.

## Context

The isometric camera follow runs in `_process` off a physics-driven `CharacterBody3D` without interpolation (WorldScene.gd:1028). On 90/120 Hz Android displays the camera samples the body position at render rate while the body only moves at the physics tick, producing visible micro-stutter. Separately, the 4-frame walk animation is hand-stepped in `_physics_process` (Player.gd:72-76) instead of using `AnimatedSprite3D`/`SpriteFrames`. (BID-014)

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-303 | Add lerp smoothing to camera follow | agent | pending | — |
| TID-304 | Migrate walk animation to AnimatedSprite3D/SpriteFrames | agent | pending | — |

## Acceptance Criteria

- [ ] Camera position is lerped toward the player body position each `_process` frame (no physics interpolation project-setting required)
- [ ] Isometric camera rotation is never touched (fixed baked rotation preserved per CLAUDE.md rule)
- [ ] Walk animation plays via `AnimatedSprite3D` auto-advance; no manual frame stepping in `_physics_process`
- [ ] Idle and walk states switch correctly on movement start/stop
- [ ] No visible regression on desktop at 60 Hz
- [ ] All existing tests pass headless
