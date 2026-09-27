# TID-571: Entry Points & Save Migration

**Goal:** GID-138
**Type:** agent
**Status:** pending
**Depends On:** TID-570

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

New Game → overworld at Madrian; interior exit → overworld at its door;
old saves in a stitched town migrate to `main` at translated position.

## Research Notes

- `SceneManager.enter_map/exit_map/_load_world`, map_stack/door_stack.
- `game_logic/save/SaveMigrations.gd`: bump CURRENT_VERSION + one row.
- Dedicated server default map "madrian".

## Plan

## Changes Made

## Documentation Updates
