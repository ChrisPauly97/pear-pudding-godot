# TID-261: Ambient Biome Soundscapes

**Goal:** GID-070
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Outside of discrete SFX (footsteps, chests, battle sounds from GID-004/GID-023), the world is silent — no wind in the grasslands, no birds in the forest, no night crickets. Looping ambient soundscapes per biome are a huge, cheap contributor to AAA feel. Ambient SFX is not music, so this stays within the spec's "no music" out-of-scope line (see BID-002 for the existing narration-audio precedent).

## Research Notes

- `autoloads/AudioManager.gd` — has separate music and SFX AudioStreamPlayers plus narration playback (ScrollRegistry); no ambient channel and no `default_bus_layout.tres`. Add: an ambience AudioStreamPlayer pair for crossfading (two players, tween volumes), an `set_ambience(biome: String)` API, and optionally a proper bus layout (Master → Music / SFX / Ambience) so the existing volume settings map onto buses.
- Ambience should follow the SFX volume setting (or get its own slider in SettingsScene — decide in Plan).
- Biome tracking: current biome is persisted in SaveManager and known to the world/chunk code (5 biomes: Grasslands, Forest, Desert, Scorched, Mountains — see docs/agent/world-generation.md). Emit/listen via GameBus rather than direct references per the architecture rule.
- Day/night variation: WorldScene drives time_of_day (0=midnight … 0.75=sunset); at minimum swap or layer a night variant (crickets) for Grasslands/Forest. Keep it to a simple two-variant swap to bound scope.
- Audio assets: check how GID-004/GID-013 sourced audio (assets/ directory, likely generated or small OGGs). If existing SFX are procedurally generated, ambient loops can be generated with the same approach (noise-based wind, filtered noise for sand, etc.) — investigate `assets/` and any AudioStreamGenerator usage before deciding; avoid committing large binaries.
- Named maps (towns, interiors) need a mapping too — default: town ambience for named maps, muffled/none for dungeons.
- Android: imported audio needs Godot import flow; run the editor-scan step (CI already does `godot --headless --editor --quit`) and include .uid/import sidecars per CLAUDE.md.
- Crossfade on biome change (~2s) to avoid hard audio cuts; also fade ambience out when entering battle overlay and back in on exit (battle push/pop runs through SceneManager/GameBus signals).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
