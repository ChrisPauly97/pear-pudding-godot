# TID-751: Crafting station panel + stations

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-748

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

One UI for every profession, opened from a station in the world.

## Research Notes

- `scenes/ui/ProfessionPanel.gd` extends `BaseOverlay`: profession header + level/XP bar, recipe list (greyed if skill too low or inputs missing; colour by difficulty: orange/yellow/green/grey), input list with owned counts, Craft ×1 / ×All. Build widgets with `UiUtil` factories; sizes relative to the viewport; drag scroll is global.
- Stations as entities: cooking fire (reuse `CampfireVisual`), alchemy table and workbench. Place them in the stitched towns (Madrian at least) via `game_logic/world/TownDecor.gd` / `StarterCamps` patterns, and in the player home interior (`PlayerHome` module). Wilderness camps' campfires also act as cooking fires.
- Interaction entry in `INTERACT_PRIORITY` (`crafting_station`) + both chains.
- Existing potion crafting in `scenes/ui/inventory/CraftPanel.gd` (`_potion_row`, `_do_craft_potion`) stays until TID-753 moves it.
- Keyboard + touch parity: station interact via the HUD button; the panel closes on Esc and on its close button.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
