# TID-322: RemotePlayer scene/script + shared AvatarSprite helper

**Goal:** GID-090
**Type:** agent
**Status:** pending
**Depends On:** TID-320

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A remote player needs an on-screen avatar. This task creates a `RemotePlayer`
scene that is a **display-only** representation of another peer — no physics, no
input, no camera — driven entirely by interpolated network state. It follows the
codebase's `init_from_data(data)` entity convention so `WorldScene` (TID-323) can
spawn it through the same path it uses for every other entity. To avoid
duplicating the local player's billboard sprite setup, the shared bits are
extracted into a small `AvatarSprite` helper reused by both `RemotePlayer` and
(optionally) `Player`.

## Research Notes

**Local player for reference:** `scenes/world/entities/Player.gd` (CharacterBody3D)
+ `scenes/world/entities/Player.tscn`. The visual is an `AnimatedSprite3D` child
(4-frame walk at 6 FPS, `billboard = BILLBOARD_ENABLED`) plus a mount `Sprite3D`
and dust `GPUParticles3D`. Facing is done by flipping the sprite horizontally
(`flip_h`). Sprite vertical placement must clear the floor (see CLAUDE.md
"Sprite3D: Depth Clipping Into Floor": `position.y ≈ pixel_height * pixel_size *
0.5 + margin`).

**Entity convention:** every world entity implements `init_from_data(data:
Dictionary)`. `TerrainMath.spawn_entity(scene, data, y_offset, entity_root,
world_scene)` instantiates the scene, sets position (Y from
`world_scene.get_terrain_height`), calls `init_from_data(data)`, and adds it to
the entity root. `RemotePlayer` should be spawnable this way (TID-323 may call it
directly or instantiate manually — either is fine; match `init_from_data`).
`WorldEntityBase` (`scenes/world/entities/WorldEntityBase.gd`) is the minimal base
with a `_make_mi()` helper.

**RemotePlayer design:**
- Extends `Node3D` (NOT CharacterBody3D — no physics/collision; it never collides,
  it just displays). 
- Holds a billboard walk sprite (reuse the player's sprite frames / texture so the
  remote avatar looks like a player; a tint or nameplate Label3D can distinguish
  it — keep minimal for the slice).
- `init_from_data(data)` reads `peer_id` and initial `x/z`.
- Public `set_net_state(x, z, flip_h, moving)` stores the target; `_process(delta)`
  interpolates current → target via `AvatarSync.interp(...)` (preload TID-320's
  script — `const _AvatarSync = preload("res://game_logic/net/AvatarSync.gd")`),
  recomputes Y locally from the world scene's terrain height, and plays/pauses the
  walk animation based on `moving`, applying `flip_h` for facing.

**AvatarSprite helper:** extract the billboard `AnimatedSprite3D` construction
(frames, billboard mode, pixel_size, floor-clearing Y) into
`scenes/world/entities/AvatarSprite.gd` as a `static func build(...) -> AnimatedSprite3D`
(or a small scene). Reuse it from `RemotePlayer`; refactoring `Player.gd` to use
it too is optional and should not change local behavior.

**Files:** `scenes/world/entities/RemotePlayer.gd`,
`scenes/world/entities/RemotePlayer.tscn` (+ `.uid` sidecar — see CLAUDE.md
"Godot Resource .uid Files": generate a 12-char `uid://`),
`scenes/world/entities/AvatarSprite.gd`.

**CLAUDE.md conventions:** preload scripts you reference (no `class_name`
reliance); explicit type annotations; create the `.uid` sidecar for the new
`.tscn`; sprite Y must clear the floor; camera must NOT be added to RemotePlayer.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
