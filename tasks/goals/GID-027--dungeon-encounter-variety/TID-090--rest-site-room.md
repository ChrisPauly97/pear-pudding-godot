# TID-090: Rest Site Room

**Goal:** GID-027
**Type:** agent
**Status:** done
**Depends On:** TID-089

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Rest sites give the player resource recovery decisions mid-dungeon: do you heal now or push on? Optionally removing a card from the deck (thinning) adds a deckbuilding layer — a core feature of Slay the Spire's rest system.

## Research Notes

- When a player enters a rest room (room_type == "rest"), show a panel overlay instead of triggering a battle
- Rest site UI options (player picks one):
  - **Rest** — recover 8 hero HP (capped at max HP = 30 or current weapon's starting_hp)
  - **Cull** — remove one card from the current deck (opens a card picker overlay showing all cards in SaveManager.player_deck; player taps one to remove it)
- After choosing, the room is marked visited (add to SaveManager.defeated_enemies pattern or a new `visited_rooms` set keyed by dungeon_id + room_index) so it can't be used again
- Hero HP persists between rooms in the same dungeon session — track in a dungeon session variable (not SaveManager, since dying resets it)
- If hero HP is already at max, disable the Rest option with a tooltip "Already at full health"
- Follow CLAUDE.md UI sizing for the choice panel

## Plan

- Rest site NPC (npc_type = "rest_site") spawned by DungeonGen in rest rooms.
- `WorldScene._handle_interact()` detects npc_type and calls `_show_rest_site_panel(npc_data)`.
- Panel offers "Rest (recover 8 HP)" (disabled if HP already full) and "Cull (remove card)" (disabled if deck < 2 cards).
- Rest choice heals `_dungeon_hero_hp` up to 30; Cull opens a scrollable card picker via `_show_cull_panel()`.
- Room marked used via `SaveManager.mark_dungeon_room_used(room_key)` on any choice made.
- `_dungeon_hero_hp: int = 30` session variable initialized fresh each dungeon entry.

## Changes Made

- `scenes/world/WorldScene.gd`:
  - Added `var _dungeon_hero_hp: int = 30` session variable.
  - Initialised to 30 in `_ready()` when `map_name.begins_with("dungeon_")`.
  - Added `rest_site` / `event_room` npc_type checks in `_handle_interact()`.
  - Added `_show_rest_site_panel()`, `_show_cull_panel()`, `_show_event_panel()`, `_apply_event_outcome()`.
- `autoloads/SaveManager.gd`: Added `visited_dungeon_rooms: Array[String]`, save version bumped to 9, migration, and `mark_dungeon_room_used` / `is_dungeon_room_used` API.

## Documentation Updates

See TID-089 docs update.
