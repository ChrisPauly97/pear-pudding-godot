# TID-018: Card Illustration Textures in InventoryScene

**Goal:** GID-008
**Type:** agent
**Status:** pending
**Depends On:** TID-017

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-017 adds the card frame shader and `CardData.illustration` field. This task applies the same frame material to InventoryScene's collection and deck panels, and wires up any existing card illustration textures (or placeholder colour fills where none exist).

## Research Notes

**Relevant files:**
- `scenes/inventory/InventoryScene.gd` — `_make_card_entry()` (or equivalent) builds card rows in the collection/deck panels; apply the same `ShaderMaterial` from TID-017
- `resources/cards/*.tres` — individual card resources; set `illustration` if a texture file exists under `assets/cards/`
- `assets/cards/` — destination for any card illustration PNGs (create directory if absent); placeholder solid-colour PNGs are acceptable for now

**Approach:**
1. Extract the `ShaderMaterial` creation from TID-017 into a shared helper (e.g. `CardFrameMaterial.gd` static utility or a helper method in a shared autoload) so BattleScene and InventoryScene both use the same code path
2. Apply the helper in `InventoryScene._make_card_entry()`
3. For cards that have no illustration texture, the shader's colour-fill branch already handles the fallback (from TID-017 design)
4. Create `assets/cards/` directory; add at minimum a `placeholder.png` (8×8 solid colour) so the illustration path is exercised in tests

**No new `.uid` sidecars needed** for `.gd` scripts; only for any new `.gdshader` or `.tres` files (none expected in this task).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
