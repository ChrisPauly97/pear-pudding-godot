# TID-018: Card Illustration Textures in InventoryScene

**Goal:** GID-008
**Type:** agent
**Status:** done
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

1. Create `game_logic/CardFrameMaterial.gd` — static helper with `make(base_color, illustration)` that creates a ShaderMaterial from `card_frame.gdshader`; preloaded by both scenes.
2. Update `scenes/battle/BattleScene.gd` — replace inline ShaderMaterial creation in `_add_card_frame_children` with `CardFrameMaterial.make()`; remove now-redundant `_CardFrameShader` preload constant.
3. Update `scenes/ui/InventoryScene.gd` — preload `CardFrameMaterial`; replace the plain `ColorRect swatch` in `_make_collection_row` and `_make_deck_row` with a shader-material swatch using `CardFrameMaterial.make()`.
4. Create `assets/cards/.gitkeep` to mark the directory for future illustration PNGs.

## Changes Made

- **`game_logic/CardFrameMaterial.gd`** (new) — static helper; `make(base_color, illustration)` preloads `card_frame.gdshader` and returns a configured `ShaderMaterial`; shared by BattleScene and InventoryScene
- **`scenes/battle/BattleScene.gd`** — replaced inline `ShaderMaterial`/shader preload with `CardFrameMaterial.make()`; removed `_CardFrameShader` constant
- **`scenes/ui/InventoryScene.gd`** — preloads `CardFrameMaterial`; replaced plain `ColorRect swatch` in `_make_collection_row` and `_make_deck_row` with a shader-material swatch (doubled swatch size to `_vh * 0.06` for legibility of the frame detail); reads `illustration` from card template for optional texture blending
- **`assets/cards/.gitkeep`** (new) — marks directory as home for future per-card illustration PNGs

## Documentation Updates

- **`docs/agent/battle-system.md`** — updated "Card Frame Rendering" note to reference `CardFrameMaterial.gd` as the shared helper
