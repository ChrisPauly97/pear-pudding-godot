# TID-153: Traveling Merchant Event with Rotating Rare Stock

**Goal:** GID-039
**Type:** agent
**Status:** pending
**Depends On:** TID-151

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A merchant who appears in the wilderness with rare cards the town shops don't carry, then leaves. Gives coins a high-end sink and rewards players who happen upon him — the world offering something instead of the player taking it.

## Research Notes

- **Spawn:** Register `traveling_merchant` with WorldEventManager (TID-151), interval ~10–20 min. Spawn `scenes/world/entities/MerchantNPC.tscn` at `find_spawn_tile(player_pos, 15, 30)`.
- `scenes/world/entities/MerchantNPC.gd` + `scenes/ui/ShopScene.gd` — exist from GID-007 (and inn merchants from GID-011). Study how a merchant's stock is defined — likely a stock array/resource on the NPC. The traveling merchant needs a stock override.
- **Rotating stock:** 3 cards rolled from `CardRegistry` filtered to rare/legendary rarities (GID-028 rarity field), seeded from the event's fire-time so the stock is stable for the event's duration. Prices: meaningfully above town-shop levels (premium for convenience) — check existing shop pricing in ShopScene/GID-028 economy docs before picking numbers.
- **Distinct look:** Tint the merchant sprite (modulate) and/or add a simple `GPUParticles3D` smoke puff so he reads as special at a distance. No new textures needed — `TextureGen` patterns if a variant sprite is wanted.
- **Despawn:** 5 minutes of overworld time after spawn, or after the player closes the shop having bought all 3 cards. Emit `end_event("traveling_merchant")` via the TID-151 cleanup callable. If the player is mid-shop when the timer expires, let them finish — despawn on shop close.
- **Discovery aid:** Unlike the boss, NO minimap marker — finding him by chance is the charm. But a brief HUD toast on spawn ("You hear distant wagon wheels...") gives a hint. Check `AchievementToast.gd` for a reusable toast pattern.
- **Mobile parity:** Shop interaction is already touch-friendly via ShopScene; just verify the interact prompt works with the tap-prompt pattern from CLAUDE.md.
- `docs/agent/enemies-and-npcs.md` — document the traveling merchant variant; `docs/agent/world-generation.md` — note the event.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
