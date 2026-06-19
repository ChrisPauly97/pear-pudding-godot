# TID-292: Always-visible centred slot UI

**Goal:** GID-079
**Type:** agent
**Status:** pending
**Depends On:** TID-291

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The board currently renders only occupied cards. This task makes all 5 slots permanently visible as outlined panels, centred horizontally in the board area, so the player always sees where minions can go and enhanced slots can show a coloured border.

## Research Notes

**Files to edit:**
- `scenes/battle/BattleScene.gd` — rewrite `_refresh_zone` and related board rendering
- `scenes/battle/BattleScene.tscn` — change board view node types to allow centering

**Current `_refresh_zone` flow:**
```
_refresh_zone(zone_node: HBoxContainer, cards: Array[CardInstance], zone_id)
  → adds/removes PanelContainer children to match occupied card count
```
It never creates panels for empty slots.

**Target `_refresh_zone` flow:**
```
_refresh_zone(zone_node, zone_state: ZoneState, zone_id)
  → ensures exactly SLOT_COUNT (5) PanelContainer children
  → for each slot i:
      if slots[i] != null → render card content (existing logic)
      else                → render empty slot outline (slot number, subtle border)
      if slot_enhancements[i] non-empty → coloured border on the panel
```

**Node structure change:** The board views need a CenterContainer parent so the 5 fixed-width slots are centred. Two options:
1. Change `EnemyBoardView` / `PlayerBoardView` in .tscn from `HBoxContainer` to `CenterContainer`, add a child `HBoxContainer` named `SlotsRow` at runtime or in the tscn.
2. Keep the node names as HBoxContainer but set `alignment = ALIGNMENT_CENTER` (HBoxContainer supports this via `alignment = 1`).

Option 2 is simpler — set `alignment = BoxContainer.ALIGNMENT_CENTER` at runtime in `_apply_ui_sizes()`.

**Empty slot styling:**
```gdscript
func _make_empty_slot_panel(slot_idx: int, zone_id: String) -> PanelContainer:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.15, 0.15, 0.2, 0.6)
    style.border_color = Color(0.4, 0.4, 0.5, 0.8)
    style.set_border_width_all(2)
    style.set_corner_radius_all(4)
    panel.add_theme_stylebox_override("panel", style)
    panel.custom_minimum_size = _slot_size()
    panel.set_meta("slot_idx", slot_idx)
    panel.set_meta("is_empty_slot", true)
    var lbl := Label.new()
    lbl.text = str(slot_idx + 1)
    lbl.add_theme_font_size_override("font_size", int(_vh * 0.025))
    lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
    lbl.modulate = Color(0.5, 0.5, 0.6)
    panel.add_child(lbl)
    return panel
```

**Enhanced slot border:** If `slot_enhancements[i]` is non-empty, override the border color:
```gdscript
match enh.get("type", ""):
    "atk_bonus": style.border_color = Color(1.0, 0.6, 0.15)  # orange
    "shroud":    style.border_color = Color(0.8, 0.8, 1.0)   # pale blue
```
Both empty and occupied enhanced slots show this border (apply via `_apply_card_style` for occupied, and in `_make_empty_slot_panel` for empty).

**Slot size helper:**
```gdscript
func _slot_size() -> Vector2:
    # 5 slots must fit in (vp.x * 0.8) minus side panel; allow small gaps
    # Rough: each slot ~13-15% vh tall, fixed-width cards
    return Vector2(_vh * 0.12, _vh * 0.19)
```

**`_refresh_zone` new signature:**
```gdscript
func _refresh_zone(zone_node: Node, zone_state: ZoneState, zone_id: String) -> void:
```
Callers in `_refresh_all()` change from:
```gdscript
_refresh_zone(_enemy_board_view, _state.players[1].board.get_cards(), "enemy_board")
_refresh_zone(_player_board_view, _state.players[0].board.get_cards(), "board")
```
to:
```gdscript
_refresh_zone(_enemy_board_view, _state.players[1].board, "enemy_board")
_refresh_zone(_player_board_view, _state.players[0].board, "board")
```
Hand zones still use the old pattern (they don't have fixed slots): factor the hand render into `_refresh_hand_zone`.

**Slot panel identity:** Each panel gets `set_meta("slot_idx", i)` so TID-293 can read which slot was dropped on.

**Drag-over highlight:** When `_hand_drag_card != null`, empty slot panels in `_player_board_view` should show a brighter border to indicate they're valid drop targets. This is a style-only change triggered by `_process()` or by reading `_hand_drag_card` in `_refresh_zone`.

**Targeting mode highlight (spell targeting):** Existing targeting uses cyan highlight on board slots — make sure this still works. The existing `_apply_card_style` applies `_targeting_active` checks. Empty slot panels created here need a similar targeting highlight when `_targeting_active` is true.

**`_find_panel_for_card` and snapshot code:** Several places in BattleScene iterate board zone children to find a panel matching a CardInstance. Since we now always have 5 children (some empty), these lookups need to check `get_meta("is_empty_slot", false)` and skip them, or check `get_meta("slot_idx")` against `board.slots.find(card)`.

**Enemy board:** Enemy board always shows 5 slots too, but empty slots on the enemy side have no interactive function for the player (they're informational). They should be slightly dimmer.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
