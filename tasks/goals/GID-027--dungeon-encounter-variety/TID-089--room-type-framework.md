# TID-089: Room Type Framework — Assign Room Types During Dungeon Generation

**Goal:** GID-027
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
