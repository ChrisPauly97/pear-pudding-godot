# TID-517: Hide Debug Labels

**Goal:** GID-134
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Raw `tile (x, z)` coords and raw map ids (`dungeon_1`) read as unfinished.

## Research Notes

WorldHUD `update_coords`; door/entrance name tags built via `SpriteRegistry.make_name_label()` with the map id.

## Plan

PlaceNames helper for map ids; door labels + HUD use it; tile coords behind a hidden setting.

## Changes Made

New game_logic/PlaceNames.gd (+test_place_names); Door.gd label; WorldScene map label (biome name in the wilds); WorldHUD coord label gated on show_tile_coords.

## Documentation Updates

ui-and-scene-management.md HUD section.
