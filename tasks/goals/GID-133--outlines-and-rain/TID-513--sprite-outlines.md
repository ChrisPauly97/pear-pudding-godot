# TID-513: Character Sprite Outlines

**Goal:** GID-133
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Characters blend into grass/mist/fog.

## Research Notes

`Sprite3D.material_override` does NOT receive the sprite texture (verified in TID-504), so an outline ShaderMaterial must be fed the texture explicitly — once for Sprite3D, on `frame_changed`/`animation_changed` for AnimatedSprite3D. Mesh UVs already carry flip/region; vertex COLOR carries modulate. Billboard must be done in the vertex shader. Keep depth-prepass behaviour (rider over mount, CLAUDE.md learning).

## Plan

Per-sprite outline ShaderMaterial (texture fed manually, billboard in vertex, depth_prepass_alpha); applied to all character sprites.

## Changes Made

- New `assets/shaders/sprite_outline.gdshader` (+ .uid), `game_logic/SpriteOutline.gd`.
- Applied in Player (rider + mount), RemotePlayer, MaitelnFollower, EnemyNPC, MerchantNPC, TownspersonNPC, ScoutAmbush.
- Tests: new `test_sprite_outline.gd`. Visual check: isolated (flip + tint) and in world.

## Documentation Updates

visual-polish.md Character Outlines section; CLAUDE.md learning.
