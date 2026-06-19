# TID-293: Explicit hand-to-slot placement

**Goal:** GID-079
**Type:** agent
**Status:** pending
**Depends On:** TID-292

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Now that slots are always-visible panels with `slot_idx` metadata, the player needs a way to drop a card into a specific slot. This task wires the drag-to-play and tap-to-play flows to use `play_card_at_slot(card, idx)` instead of the auto-slot `play_card(card)`.

## Research Notes

**Files to edit:**
- `scenes/battle/BattleScene.gd` — update `_finish_hand_drag`, `_input`, and drag-highlight logic

**Current drag-to-play flow (`_finish_hand_drag`):**
```gdscript
var board_rect: Rect2 = _player_board_view.get_global_rect()
if board_rect.has_point(mouse_pos):
    # ... plays card (no slot choice)
    if _do_play_card(played_card, 0): ...
```

**New drag-to-play flow:**
```gdscript
func _finish_hand_drag() -> void:
    var mouse_pos := get_viewport().get_mouse_position()
    # Find which slot panel the mouse is over
    var target_slot_idx: int = _slot_idx_at_point(mouse_pos, _player_board_view)
    if target_slot_idx == -1:
        _cancel_hand_drag()
        return
    var played_card := _hand_drag_card
    # Spell targeting: enters targeting mode as before (no slot needed)
    var is_enemy_targeted: bool = _ENEMY_TARGETED_EFFECTS.has(played_card.spell_effect)
    var is_friendly_targeted: bool = _FRIENDLY_TARGETED_EFFECTS.has(played_card.spell_effect)
    if played_card.card_class == "spell" and (is_enemy_targeted or is_friendly_targeted) ...:
        # existing targeted spell logic unchanged
        ...
        return
    if played_card.card_class == "spell":
        # Non-targeted spells: slot doesn't matter, use existing play_card
        if _do_play_card(played_card, 0): ...
    else:
        # Minions: must drop on a specific empty slot
        if _do_play_card_at_slot(played_card, 0, target_slot_idx):
            AudioManager.play_sfx("card_play")
            ...
    _cancel_hand_drag()
```

**`_slot_idx_at_point` helper:**
```gdscript
func _slot_idx_at_point(point: Vector2, board_view: Node) -> int:
    for child in board_view.get_children():
        if child is Control:
            var ctrl := child as Control
            if ctrl.get_global_rect().has_point(point):
                var idx: int = int(ctrl.get_meta("slot_idx", -1))
                if idx >= 0:
                    # For player board, only accept empty slots for minions
                    return idx
    return -1
```

**`_do_play_card_at_slot` wrapper (mirrors `_do_play_card` for snow discount):**
```gdscript
func _do_play_card_at_slot(card: CardInstance, player_idx: int, slot_idx: int) -> bool:
    var apply_discount: bool = (
        (_battle_weather == "snow" or _battle_weather == "blizzard") and
        not _snow_discount_used[player_idx]
    )
    if apply_discount:
        var saved_cost: int = card.cost
        card.cost = maxi(0, card.cost - 1)
        var ok: bool = _state.players[player_idx].play_card_at_slot(card, slot_idx)
        card.cost = saved_cost
        if ok:
            _snow_discount_used[player_idx] = true
        return ok
    return _state.players[player_idx].play_card_at_slot(card, slot_idx)
```

**Drag-over highlight:** In `_process()` or via `gui_input` on the slot panels: while `_hand_drag_card != null`, each empty slot panel in the player board should brighten its border. Simplest approach: in `_refresh_zone`, if `_hand_drag_card != null` and `can_play(_hand_drag_card)`, set a highlight style on empty player slot panels. Call `_refresh_zone` or just a lightweight `_refresh_slot_highlights()` from `_process()`.

Actually, to avoid full refresh every frame, handle via a flag: in `_start_hand_drag`, mark empty slot panels as "highlight mode" directly (walk the board view children and update their style). In `_cancel_hand_drag` / `_finish_hand_drag`, clear it.

```gdscript
func _highlight_player_slots(active: bool) -> void:
    for child in _player_board_view.get_children():
        if bool(child.get_meta("is_empty_slot", false)):
            var style: StyleBoxFlat = child.get_meta("card_style", null) as StyleBoxFlat
            if style:
                style.border_color = Color(0.3, 1.0, 0.5, 1.0) if active else Color(0.4, 0.4, 0.5, 0.8)
                style.border_width_left = 3 if active else 2
                # etc.
```

Call `_highlight_player_slots(true)` at end of `_start_hand_drag` and `_highlight_player_slots(false)` in `_cancel_hand_drag`.

**Tap-to-play mobile (slot selection mode):**
Currently, tapping a hand card without dragging calls `_show_card_inspect`. With slot selection mode we need a different flow:
- If `_state.players[0].can_play(card)` → enter slot selection mode instead of inspect
- Tap on an empty player slot confirms placement
- A cancel button dismisses the mode

Add `_slot_select_card: CardInstance = null` to track this mode.
```gdscript
func _on_hand_card_tap(card: CardInstance) -> void:
    if _state.players[0].can_play(card):
        _enter_slot_select_mode(card)
    else:
        _show_card_inspect(card)

func _enter_slot_select_mode(card: CardInstance) -> void:
    _slot_select_card = card
    _highlight_player_slots(true)
    _show_cancel_btn("✕ Cancel", _exit_slot_select_mode)
    # Bind empty slot panels to confirm placement
    for child in _player_board_view.get_children():
        if bool(child.get_meta("is_empty_slot", false)):
            var idx: int = int(child.get_meta("slot_idx", -1))
            if idx >= 0 and child.is_connected("gui_input", Callable()):
                pass  # already wired via _bind_card_input
            # Re-bind to a slot-confirm handler
            if child.gui_input.is_connected(_on_empty_slot_input):
                child.gui_input.disconnect(_on_empty_slot_input)
            child.gui_input.connect(_on_empty_slot_input.bind(idx))

func _exit_slot_select_mode() -> void:
    _slot_select_card = null
    _highlight_player_slots(false)
    _hide_cancel_btn()
    _refresh_zone(_player_board_view, _state.players[0].board, "board")

func _on_empty_slot_input(event: InputEvent, slot_idx: int) -> void:
    if _slot_select_card == null:
        return
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
            var card := _slot_select_card
            _exit_slot_select_mode()
            if _do_play_card_at_slot(card, 0, slot_idx):
                AudioManager.play_sfx("card_play")
                _haptic(20)
                _resolve_card_play_effects(card)
                _refresh_all()
                _check_game_over()
```

**Spell cards:** Spells don't occupy a slot, so the existing drag-to-board-area logic should still work. When `played_card.card_class == "spell"`, the drop target is the entire board view (any slot panel will do) — extract slot index but ignore it for non-targeted spells.

**Puzzle mode:** Puzzle mode uses the same drag/tap path, so this will work automatically.

**BasicAI:** Unchanged — `BasicAI.decide_turn` calls `PlayerState.play_card(card)` (auto-slot). No changes needed.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
