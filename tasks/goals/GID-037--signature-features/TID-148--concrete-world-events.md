# TID-148: Three Concrete World Events — Roaming Boss, Traveling Merchant, Card Shower

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** TID-147

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-147 builds the event scheduler. This task implements the three concrete events that make the open world feel alive without requiring hand-authored content: a roaming boss that appears on the minimap, a traveling merchant with rotating rare stock, and a card shower that scatters pickups around the player.

## Research Notes

### Event 1: Roaming Boss
- Spawns a boss-tier EnemyNPC (from EnemyRegistry, boss flag = true) at a random chunk near the player.
- `scenes/world/entities/EnemyNPC.gd` — standard enemy scene; add a `is_roaming_boss: bool` flag that gives it a larger sprite scale and a glowing outline shader param.
- Minimap shows a red dot at boss world position (hook from TID-147 framework).
- On defeat: `world_event_ended("roaming_boss")`, rewards a rare card drop, sets cooldown (e.g. 20 min real time).

### Event 2: Traveling Merchant
- Spawns a MerchantNPC at a random road tile (TILE_PATH or nearest walkable) in a loaded chunk.
- `scenes/world/entities/MerchantNPC.gd` and `scenes/ui/ShopScene.gd` already exist.
- Merchant's stock is seeded from `world_events.traveling_merchant.seed` — rotate 3 random rare/legendary cards from `CardRegistry` for sale.
- Despawns after 5 in-game minutes or on map reload.

### Event 3: Card Shower
- No entity spawn. A burst of `WorldItem` pickups (5–10 random common cards) scatter in a radius around the player.
- `scenes/world/entities/WorldItem.gd` — already exists for item drops.
- Visual: a brief particle burst (`GPUParticles3D`, sparkle texture, no geometry shader needed).
- Each WorldItem auto-despawns after 60 seconds if uncollected.
- Cooldown: 10 min real time.

### Shared
- All three events register themselves with `WorldEventManager` from `TID-147` via `WorldEventManager.register_event(def)` called from their respective `_ready` functions or from a new `WorldEvents.gd` init script.
- `docs/agent/world-generation.md` — update with event descriptions.
- `docs/agent/enemies-and-npcs.md` — document roaming boss variant.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
