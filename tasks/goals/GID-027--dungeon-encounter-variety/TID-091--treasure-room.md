# TID-091: Treasure Room

**Goal:** GID-027
**Type:** agent
**Status:** done
**Depends On:** TID-089

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Treasure rooms provide guaranteed reward moments with no risk — a pacing tool that feels generous and rewards dungeon exploration.

## Research Notes

- When a player enters a treasure room (room_type == "treasure"), spawn a chest entity in the room with no enemy present
- The chest uses the existing `scenes/world/entities/Chest.gd` — trigger it immediately (or show a "Open Chest" prompt) rather than requiring a battle first
- Treasure room chest loot is better than standard world chests: guaranteed 2 cards (instead of 1) OR a 40% chance of a weapon drop
- Mark room visited after chest is opened (same visited_rooms pattern as TID-090) so the chest cannot be re-opened
- If the player exits and re-enters the dungeon, the treasure room shows an empty chest (already looted) with a "You've already claimed this treasure" message
- Visually: treasure rooms could have a golden floor tint (shader parameter on the floor mesh) to signal "safe room"

## Plan

- DungeonGen spawns a chest (id prefix "dtr_") with 2 random cards and no enemy in treasure rooms.
- WorldScene chest open handler checks if cid starts with "dtr_" → uses 40% weapon drop chance instead of standard 15%.
- Chest state persistence uses existing SaveManager.opened_chests (same as all chests).
- Visual distinction: yellow chest dot on map overlay (pre-existing _DOT_CHEST colour).
- `export_presets.cfg` include_filter updated to add `*.json` for dungeon_events.json inclusion in APK.

## Changes Made

- `game_logic/world/DungeonGen.gd`: Added "treasure" match arm in entity loop; spawns chest id "dtr_N" with 2 cards.
- `scenes/world/WorldScene.gd`: `_maybe_drop_weapon_from_chest` refactored to accept `chance: float = 0.15` parameter; treasure room chests pass `0.40`.
- `export_presets.cfg`: `include_filter` extended with `*.json`.
- `data/dungeon_events.json`: Created with 5 starter events.

## Documentation Updates

See TID-089 docs update.
