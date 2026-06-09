# TID-154: Card Shower Event with Particle Burst

**Goal:** GID-039
**Type:** agent
**Status:** pending
**Depends On:** TID-151

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The lightest event: a sparkle burst scatters 5–10 collectible card pickups around the player for 60 seconds. Pure delight + a small collection trickle; also the simplest event, so it doubles as the framework's reference implementation.

## Research Notes

- **Spawn:** Register `card_shower` with WorldEventManager (TID-151), interval ~8–15 min. Spawn func scatters 5–10 `WorldItem` instances at random walkable tiles within ~10 tiles of the player (reuse `find_spawn_tile` per item with min_dist 2, max_dist 10).
- `scenes/world/entities/WorldItem.gd` / `.tscn` — exists; check what payloads it supports (it's used for item drops). Each pickup carries one random **common** card ID from `CardRegistry` (commons only — rarity comes from the boss and merchant events; the shower is volume, not value).
- **Visuals:**
  - One `GPUParticles3D` burst at the player position when the event fires (sparkle/star texture via `TextureGen`, one-shot, ~1.5 s). No geometry shaders (CLAUDE.md).
  - Each WorldItem gets a gentle bob/spin if WorldItem doesn't already do this — check before adding.
- **Audio:** A chime on fire via `AudioManager` (GID-004) if a suitable SFX exists — check `autoloads/AudioManager.gd` for available sounds; skip if none fits, don't add new audio assets.
- **Collection:** Walking over a WorldItem collects it (existing behaviour) — card goes to the permanent collection via the standard card-grant path (check how chest drops grant cards, `docs/agent/inventory-and-deck.md`). Show the standard pickup feedback.
- **Despawn:** Each item auto-despawns 60 s after spawn (a `Timer` per item or a sweep in the cleanup callable). The event ends when all items are collected or despawned → `end_event("card_shower")`.
- **Edge case:** Items must not spawn on WALL tiles or inside ruins walls — `find_spawn_tile` (TID-151) should already guarantee walkable tiles; verify it checks the tile type via the chunk lookup.
- `docs/agent/world-generation.md` — document the event.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
