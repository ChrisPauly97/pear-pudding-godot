# TID-617: Siege Music — Dedicated Track During Town Sieges

**Goal:** GID-145
**Type:** agent
**Status:** done
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

Ship `siege.ogg`, add `TownSiege.music_for()` with a pure static rule, and apply it at every point that picks town music: entry, siege spawn, co-op start/end, and the return from battle.

## Changes Made

- `assets/audio/music/siege.ogg` (1.8 MB): Juhani Junkala, "Epic Boss Battle"
  (CC0; the recommended option), loudness-matched to `battle.ogg`, `loop=true`.
- `TownSiege.gd`: `SIEGE_MUSIC`, `music_for()`, static `pick_music()`,
  `place_music()`, `refresh_music()` (a no-op unless `SceneManager.is_in_world()`,
  so a siege event mid-battle never steals the battle track); `_spawn_if_active`
  refreshes the music.
- `RealmRegions._town_music` → public `town_music()`; town entry goes through `music_for`.
- `CoopActivities`: refresh on co-op siege start and end.
- `WorldScene._on_battle_won`: in the overworld inside a stitched town, restores
  the town's (siege) track. Previously it always played the biome track, even in
  a town. Named maps go through `music_for` too.
- `tests/unit/test_siege_music.gd` (6 tests).

## Documentation Updates

`docs/agent/audio-soundtrack.md` (Siege Track section); CLAUDE.md TownSiege module row.
