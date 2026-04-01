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

- [ ] Cards in the battle hand and on the board display a decorative frame rather than a plain rect
- [ ] Card frame is consistent across BattleScene and InventoryScene
- [ ] `CardData` has an optional `illustration: Texture2D` field; cards without one show a colour fill
- [ ] Card name, cost, attack, and health text remain legible over the frame
- [ ] No performance regression — frame is a single material/shader, not per-pixel GDScript drawing
