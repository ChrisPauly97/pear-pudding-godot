# TID-154: Card Shower Event with Particle Burst

**Goal:** GID-039
**Type:** agent
**Status:** done
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

1. Add card shower constants + `_spawn_card_shower` + `_cleanup_card_shower` to `game_logic/WorldEvents.gd`. Scatter 5–10 common WorldItem pickups at `find_spawn_tile(pos, 2, 10, seed+i)`. Each item gets a 60 s `SceneTreeTimer` (via `world_scene.get_tree().create_timer(60.0)`) that calls `queue_free` on timeout. Fire a one-shot `GPUParticles3D` sparkle burst at the player. Play `chest_open` SFX. HUD toast "Cards are falling from the sky!".
2. Add `var _card_shower_items: Array[Node3D] = []` to `WorldScene.gd`. Populate it from `_spawn_card_shower` via `world_scene.set("_card_shower_items", items)`. Add `_tick_card_shower()` called from `_process()` when `_is_infinite`: when all items in the array are no longer `is_instance_valid`, call `wem.end_event("card_shower")` and clear the array.
3. Register event in `WorldEvents.register_all`: 8–15 min interval.
4. Update `docs/agent/world-generation.md` registered-events table.

## Changes Made

- `game_logic/WorldEvents.gd` — added `_WorldItemScene`, `_CardRegistry`, `_CardDropUtil` preloads; added `_SHOWER_*` constants and 31-card `_SHOWER_CARD_POOL` (no legendaries); registered `card_shower` event (8–15 min) in `register_all`; added `_spawn_card_shower()` (scatters 5–10 WorldItems at `find_spawn_tile(pos, 2, 10)`, attaches 60 s `SceneTreeTimer` per item, fires GPUParticles3D sparkle burst, plays `chest_open` SFX, shows HUD toast); added `_cleanup_card_shower()` (force-frees remaining items); added `_spawn_sparkle_burst()` helper (40-particle one-shot yellow burst, auto-freed after 2 s)
- `scenes/world/WorldScene.gd` — added `var _card_shower_items: Array[Node3D] = []`; added `_tick_card_shower()` that polls item validity and calls `wem.end_event("card_shower")` when all items are gone; wired `_tick_card_shower()` into the `_is_infinite` process block

## Documentation Updates

- `docs/agent/world-generation.md` — added `card_shower` row to the Registered Events table
