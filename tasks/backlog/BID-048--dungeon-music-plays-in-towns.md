# BID-048: dungeon.ogg Plays for Every Named Map, Including Peaceful Towns

**Category:** design-inconsistency
**Discovered During:** GID-116 research

## Description

`WorldScene.gd` plays `res://assets/audio/music/dungeon.ogg` for every non-infinite (named) map — this covers actual dungeons (`dungeon_*`) but also the peaceful towns madrian and maykalene. A single "dungeon" track is unlikely to fit both a safe town hub and a procedural dungeon crawl tonally.

## Evidence

- `scenes/world/WorldScene.gd` ~line 693 and ~line 5436: `AudioManager.play_music("res://assets/audio/music/dungeon.ogg")` runs whenever `not _is_infinite`, with no branch on whether `map_name` is a town vs. a dungeon.

## Suggested Resolution

A future goal could split this into a `town.ogg` (or per-town track) and keep `dungeon.ogg` for actual dungeon crawls, gating on `map_name.begins_with("dungeon_")` the same way the existing code already checks that prefix elsewhere (see the `_dungeon_session_ui.reset_hero_hp()` branch right next to the music call). GID-116 deliberately picked a single "calm but mysterious, not scary" track for `dungeon.ogg` to soften this mismatch rather than expanding that goal's scope to add new code paths.
