# TID-089: Room Type Framework — Assign Room Types During Dungeon Generation

**Goal:** GID-027
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

DungeonGen currently generates only combat rooms. This task adds a room type system so each room in a procedural dungeon is assigned a type (combat, rest, treasure, event) at generation time, deterministically from the dungeon seed.

## Research Notes

- `game_logic/world/DungeonGen.gd` — this is where dungeon layout and rooms are generated; find how rooms are created and stored
- Add a `room_type: String` field to whatever data structure represents a dungeon room (likely a Dictionary or Resource)
- Room type distribution (suggested): 60% combat, 15% rest, 15% treasure, 10% event
- Use the dungeon seed for deterministic assignment: `rng.randi() % 100 < threshold` pattern — same seed = same room types every visit
- The first room (entry) must always be combat (so the player always has a fight in a dungeon)
- The last room before exit could always be combat (boss-style — or just a harder fight)
- `scenes/world/` — find where dungeon rooms are rendered/shown to the player; room type needs to be visible:
  - Simplest: a colored floor tile or a Label showing the room type name on the dungeon map
  - Or: a different ambient light color per room type
- Room type data must be persisted with the dungeon (DungeonGen already persists dungeons via seed) — if room types are derived deterministically from the seed, no extra persistence is needed

## Plan

- Added `room_types: Array[String]` to DungeonGen.generate() after room layout is computed.
- Room 0 = "start", room 1 = always "combat", rooms 2-3 = 60/15/15/10 distribution (combat/rest/treasure/event), room 4 = always "combat".
- Entity spawning loop (`for i in range(1, rooms.size()-1)`) replaced with a match statement on room type.
- Non-combat rooms get no enemies; rest/event rooms get an NPC (npc_type "rest_site" / "event_room") at the room center; treasure rooms get a chest with 2 cards (id prefix "dtr_").
- Room key for visited tracking encoded in npc's `after_dialogue` field as `<dungeon_name>_room_<idx>`.
- Visual distinction via MapViewOverlay dot colours: teal for rest, amber for event, existing yellow for treasure chest.

## Changes Made

- `game_logic/world/DungeonGen.gd`: Replaced flat middle-room enemy loop with room-type assignment block and match-based entity spawning. Added `room_types: Array[String]`, `npc_uid`, `troom_uid`, and `combat_count` counters.
- `scenes/ui/MapViewOverlay.gd`: Added `_DOT_REST` / `_DOT_EVENT` constants; `_draw_npcs()` now matches npc_type to choose dot colour.

## Documentation Updates

Updated `docs/agent/named-maps-and-dungeons.md` with room type system description.
