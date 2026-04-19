# TID-090: Rest Site Room

**Goal:** GID-027
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
