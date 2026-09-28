# TID-591: Starter Zone — Madrian Outskirts

**Goal:** GID-141
**Type:** agent
**Status:** pending
**Depends On:** TID-536

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

New games spawn in Madrian at the overworld origin. Flesh out the area around it into a gentle starter zone for levels 1–~10
with a trainer hub, safe paths, and enemy camps that ramp in level away from town.

## Research Notes

- Madrian is stitched into `main` by `game_logic/world/RealmLayout.gd` (crop Rect2i(4,4,91,56), offset (-37,-33));
  story sites like `madrian_south_road` (13,30) live in its site table (L67+). Use `RealmLayout.to_world_tile()` and
  `WorldScene.story_place()`; authoring source `assets/maps/madrian.tres` (see `docs/agent/named-maps-and-dungeons.md`,
  CLAUDE.md "Map Storage").
- Zone levels come from TID-536 (enemy level on name tag, XP by level colour). Author an outskirts ring: L1–2 critters
  near the gates, L3–5 camp, L6–9 ruin/graveyard (home of the gravedigger + burial mounds for Dig at L10), a haunted
  spot with a wall only Phase can pass (teases L12).
- Enemy spawns in the overworld are chunk-streamed (`docs/agent/world-generation.md`, `ChunkRenderer._spawn_entities`);
  starter-zone camps need deterministic authored spawns near origin that override random biome pools within a radius
  (check how RealmLayout story sites spawn entities, e.g. `StoryCast.gd` wilderness camp). Weak enemy types:
  `EnemyRegistry` tier 1 (`undead_basic`, etc.) — may need a couple of new low-tier critter enemies (data only in
  `EnemyRegistry._ensure_loaded()`; no .tres enemies).
- Respawn: `GID-009` enemy respawn — camps must respawn so quests can't strand the player.
- Keep the stitched realm rules: interiors door-entered only; don't break `test_realm_layout*` tests.
- Visual: this zone is the first impression — use the newest prop/lighting systems (GID-129..134) consistently; feeds TID-593.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
