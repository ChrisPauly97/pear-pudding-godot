# TID-091: Treasure Room

**Goal:** GID-027
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
