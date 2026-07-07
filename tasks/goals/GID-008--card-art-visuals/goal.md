# GID-008: Card Art & Battle Visuals

## Objective

Replace plain coloured rectangles with pixel-art card frames in both the battle hand/board and the inventory deck builder.

## Context

All card rendering in BattleScene and InventoryScene uses `StyleBoxFlat` with a solid background colour. There are no card frames, no illustrations, and no visual distinction beyond colour. For a TCG, card presentation is core to the feel of the game. This goal adds a reusable card frame (painted once with a `CanvasItem` draw or shader) and optional per-card illustration textures wired through `CardData`.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-017 | Pixel-art card frame shader and BattleScene integration | agent | done | — |
| TID-018 | Card illustration textures in InventoryScene | agent | done | TID-017 |

## Acceptance Criteria

**Note:** TID-017's `card_frame.gdshader` approach was superseded by TID-319 (`GID-089`), which delivered the same visual goal — decorative borders + per-card illustration art — through `StyleBoxFlat` borders and a `TextureRect` illustration layer instead of a shader. See TID-017/TID-018 Changes Made for details.

- [x] Cards in the battle hand and on the board display a decorative frame rather than a plain rect (`StyleBoxFlat` border via `CardViewBuilder.apply_card_style`)
- [x] Card frame is consistent across BattleScene and InventoryScene (both use bordered `StyleBoxFlat` panels; both show `CardData.illustration` when present)
- [x] `CardData` has an optional `illustration: Texture2D` field; cards without one show a colour fill
- [x] Card name, cost, attack, and health text remain legible over the frame
- [x] No performance regression — illustrations are generated once and cached (`TextureGen`), not drawn per-pixel per-frame
