# TID-644: Stream water ambience loop

**Goal:** GID-152
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

No water sound near streams; only rain and footstep splashes. Part of GID-152 (art motion pass).

## Research Notes

- `game_logic/AmbienceLayers.gd` maps layer keys → `assets/audio/ambience/*.ogg`; `game_logic/AmbienceGen.gd` synthesises loops (see BID-073 for owl precedent). Add a `stream` layer: generate a babbling-water loop (filtered noise + bubble blips) or synthesise at runtime.
- Gain by distance to nearest wet tile: sample `ChunkRenderer.water_at_world(csm, wx, wz, seed)` in a small ring around the player a few times per second (not every frame); fade in/out.
- Hook where ambience layers are driven (`AudioManager.gd`); add unit test for gain curve in a pure helper.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
