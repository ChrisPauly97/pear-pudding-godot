# TID-470: Data-Driven Named-Map Music

Goal: [GID-125](goal.md) · Backlog: BID-048 · Type: agent · Status: done

## Problem

`WorldScene` hardcoded `dungeon.ogg` for *every* non-infinite named map, so
peaceful towns (madrian, maykalene) and the player's own home played dungeon
music.

## Changes Made

- `game_logic/world/WorldMap.gd` — added a `music_track: String` field, read in
  `load_from_resource()` from `MapData.music_track` and written back in
  `to_map_data()` so dungeon saves round-trip. The `MapData` field already
  existed but was dead: exported, always `""`, never read.
- `scenes/world/WorldScene.gd` — new `_named_map_music_track()`. Resolution
  order: the map's own `music_track` override → `_DUNGEON_MUSIC` for
  `dungeon_*` / `spire_floor_*` → `_TOWN_MUSIC_DEFAULT`. Replaced both hardcoded
  call sites (`_ready()`, `_on_battle_won()`).
- `assets/maps/*.tres` — set `music_track` on the 9 hand-authored named maps.
  `main.tres` left empty; it always takes the infinite/biome-music path.

Procedural dungeons are generated at runtime as `dungeon_<seed>` and never set
an override, so they correctly keep dungeon music through the fallback.

## Judgment Call

No dedicated town track exists and licensing new audio was out of scope, so
`grasslands.ogg` ("pastoral, warm, adventurous" per `docs/agent/audio-soundtrack.md`)
is the peaceful default. Per-location tracks — e.g. something tenser for
`marsax_hold` under siege — are now a one-line `.tres` change each.

## Documentation Updates

`docs/agent/audio-soundtrack.md`, `battle-system.md`, `named-maps-and-dungeons.md`.
