# TID-590: Siege Music — Dedicated Track During Town Sieges

**Goal:** GID-141
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A town under siege plays the same peaceful town track as normal
(`docs/agent/game-appeal.md` §6.5). The siege needs tension.

## Research Notes

- Track choice was left open at goal approval. Recommended: OGA
  `/content/boss-battle-music` (CC0, orchestral). Alternative: `/content/horde-war-drums-loop`
  (CC0, percussive `.wav`, larger file). Add as `assets/audio/music/siege.ogg`
  and credit it in `CREDITS.md`. Set its import to loop, or rely on
  `AudioManager._on_music_finished` restarting it.
- Music routing: `AudioManager.play_music(path)` (no-op when the same path is
  already playing). The town track comes from `RealmRegions._town_music(town)`
  (stitched overworld towns, GID-138) and `WorldScene._named_map_music_track()`.
- Siege lifecycle:
  - Solo: `scenes/world/modules/TownSiege.gd` (`on_map_entered`,
    `_spawn_if_active`, `_spawn_raiders`, `_setup_banner`). Siege state is
    saved via `save_manager.town_siege` (`autoloads/save_manager/`).
  - Co-op: `scenes/world/coop/CoopActivities.gd` `_start_coop_siege`,
    `_on_siege_started_received`, `_finish_coop_siege_victory`,
    `_on_coop_siege_battle_ended`.
  - GameBus: `siege_victory`, `siege_defeated(coins_lost)`.
- Suggested design: a single helper (e.g. `TownSiege.music_for(town) -> String`)
  that returns the siege track while that town's siege is active, else the town
  track. Call it from `RealmRegions` where it currently calls `_town_music`, and
  re-apply on siege start/victory/defeat. The same helper covers co-op. Battles
  swap to `battle.ogg` and back via `WorldScene._on_battle_won`, so make sure the
  return path picks the siege track while the siege is still on.
- Add a test: siege active → the music path is the siege track; after `siege_victory` → the town track.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
