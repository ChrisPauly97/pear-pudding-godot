# TID-136: Card Inspect on Long Press (Battle, Inventory, Shop)

**Goal:** GID-036
**Type:** agent
**Status:** done
**Depends On:** TID-135

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`CardInspectOverlay.gd` already exists but is surfaced only via a small "?" icon button inside the card node. Players on mobile cannot easily hit that button. This task wires `LongPressDetector` (TID-135) onto every card surface in the three places cards appear — battle hand, inventory card grid, and shop — so a 500 ms hold opens the inspect overlay.

## Research Notes

### CardInspectOverlay

- `scenes/battle/CardInspectOverlay.gd` — pure GDScript overlay added to `CanvasLayer` at runtime.
- Public API: `show_card(card_id: String)` — builds and shows the overlay.
- Already used in `BattleScene.gd` when the "?" button on a hand card is pressed.
- Dismiss: backdrop click or "Close" button.

### Where cards are rendered

**1. Battle hand (`scenes/battle/BattleScene.gd`)**
- `_make_hand_card(card_id)` returns a `PanelContainer` node.
- The "?" button is added inside that method.
- Add `LongPressDetector` inside `_make_hand_card()` after the existing button.

**2. Inventory card grid (`scenes/ui/InventoryScene.gd`)**
- `_make_card_thumb(card_id, owned_count)` returns a `PanelContainer`.
- Add `LongPressDetector` there.
- On `long_pressed` → instantiate or reuse `CardInspectOverlay` on the scene's `CanvasLayer`.

**3. Shop (`scenes/ui/ShopScene.gd`)**
- Cards shown as `PanelContainer` rows in a scroll list.
- Add `LongPressDetector` to each row; on `long_pressed` → open `CardInspectOverlay`.

### Overlay access pattern

Each scene that needs the overlay should hold a single instance and reuse it:

```gdscript
const CardInspectOverlay = preload("res://scenes/battle/CardInspectOverlay.gd")
var _inspect_overlay: CardInspectOverlay

func _ready() -> void:
    _inspect_overlay = CardInspectOverlay.new()
    $CanvasLayer.add_child(_inspect_overlay)

func _on_card_long_pressed(card_id: String) -> void:
    _inspect_overlay.show_card(card_id)
```

`BattleScene.gd` already has a `CanvasLayer`; `InventoryScene.gd` and `ShopScene.gd` need to confirm they have one (or add one).

### LongPressDetector usage

```gdscript
const LongPressDetector = preload("res://scenes/ui/LongPressDetector.gd")

func _make_hand_card(card_id: String) -> PanelContainer:
    var panel := PanelContainer.new()
    # ... existing build code ...
    var lpd := LongPressDetector.new()
    panel.add_child(lpd)
    lpd.long_pressed.connect(func(): _on_card_long_pressed(card_id))
    return panel
```

### Files to modify

- `scenes/battle/BattleScene.gd` — `_make_hand_card()`
- `scenes/ui/InventoryScene.gd` — `_make_card_thumb()`
- `scenes/ui/ShopScene.gd` — card row builder

## Plan

1. Fix LongPressDetector to check parent rect before activating (prevents all-cards-fire-together bug).
2. Add `_show_inspect(card_id)` helper to InventoryScene and ShopScene — creates CardInstance from template, instantiates overlay as last child.
3. Add LongPressDetector to `_make_collection_row` and `_make_deck_row` in InventoryScene.
4. Add LongPressDetector to `_make_card_row` in ShopScene.
5. Add LongPressDetector to all card panels in BattleScene via `_bind_card_input`.

## Changes Made

- **`scenes/ui/LongPressDetector.gd`**: Added parent-rect guard — detector only activates when the initial press is within its parent Control's global rect.
- **`scenes/ui/InventoryScene.gd`**: Added `CardInspectOverlay`, `CardInstance`, `LongPressDetector` preloads; `_inspect_overlay` field; `_show_inspect(card_id)` helper; LongPressDetector in `_make_collection_row` and `_make_deck_row`.
- **`scenes/ui/ShopScene.gd`**: Same additions; LongPressDetector in `_make_card_row`.
- **`scenes/battle/BattleScene.gd`**: Added `LongPressDetector` preload; `_bind_card_input` now attaches a LongPressDetector to every card panel (cleaning up old ones via `get_script()` check + `queue_free`).

## Documentation Updates

No agent doc changes needed — pattern is self-contained in code.
