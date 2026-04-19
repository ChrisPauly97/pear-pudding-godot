# TID-081: Background Music Loop Integration

**Goal:** GID-023
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

AudioManager has a music channel (GID-004) but nothing calls it. This task wires biome-aware music playback into WorldScene and battle music into BattleScene. Actual audio files are human-provided assets; the integration gracefully no-ops if files are absent.

## Research Notes

- `autoloads/AudioManager.gd` — find the music playback method (likely `play_music(path)` or `play_track(name)`); check if it supports looping and crossfading
- `scenes/world/WorldScene.gd` — on biome change (or chunk load that changes biome), call `AudioManager.play_music("res://assets/audio/music/<biome>.ogg")`
- `scenes/battle/BattleScene.gd` — on battle start, call `AudioManager.play_music("res://assets/audio/music/battle.ogg")`; on battle end, resume world music
- Biome music file paths:
  - `assets/audio/music/grasslands.ogg`
  - `assets/audio/music/forest.ogg`
  - `assets/audio/music/desert.ogg`
  - `assets/audio/music/scorched.ogg`
  - `assets/audio/music/mountains.ogg`
  - `assets/audio/music/battle.ogg`
- Graceful no-op: if the file doesn't exist, `ResourceLoader.exists(path)` returns false — skip the play call and log a warning
- Don't restart the same track if it is already playing (check current track name before swapping)
- Volume: music should default to 0.5 (half) so it doesn't overpower SFX; check if AudioManager has a music volume setting

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
