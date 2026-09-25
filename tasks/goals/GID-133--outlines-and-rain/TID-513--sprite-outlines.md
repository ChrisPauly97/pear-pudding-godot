# TID-513: Character Sprite Outlines

**Goal:** GID-133
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
