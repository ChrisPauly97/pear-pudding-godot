# TID-313: Migrate battle drag-to-play to native Godot drag-and-drop

**Goal:** GID-088
**Type:** agent
**Status:** done
**Depends On:** TID-312

## Lock

Session: none
Acquired: —
Expires: —

## Context

`BattleScene.gd:329-421` implements drag-to-play via global `_input` mouse tracking with a manually positioned ghost Control. Godot's native drag-and-drop API (`_get_drag_data`, `_can_drop_data`, `_drop_data` on Control nodes) is the correct pattern: it handles both mouse and touch transparently, reduces manual state, and eliminates the ghost positioning logic.

**Critical**: the long-press-to-inspect interaction must be re-verified on Android after migration. Native drag on touch starts on drag threshold, which may conflict with the tap-to-inspect gesture. The migration plan must document how to disambiguate.

## Plan

1. Remove manual ghost state (`_drag_visual`, `_drag_start_pos`, `_drag_moved`) and the global `_input` mouse-tracking loop that positioned it.
2. Wire each hand-card panel with `set_drag_forwarding(get_fn, can_drop_fn, drop_fn)`: `get_fn` returns `{"card": card}` and sets a preview via `set_drag_preview(_make_card_ghost(card))`; the drop/can-drop fns on the panel are no-ops.
3. Wire `_player_board_view` with `set_drag_forwarding` for the drop target: `_board_can_drop` checks `can_play`; `_board_drop` replicates the former drop-zone logic (slot index detection, spell targeting modes, PvP intent encoding).
4. Keep `_hand_drag_card` to drive slot highlighting in `CardViewBuilder`; clear it via `NOTIFICATION_DRAG_END` so highlights reset if drag is cancelled.
5. Long-press-to-inspect disambiguation: native drag starts after the engine drag threshold (typically a few pixels of movement). `LongPressDetector` fires only on finger-hold with <12px movement. These do not conflict — a drag gesture cancels LPD before its 0.5s timer fires.

## Changes Made

- `scenes/battle/BattleScene.gd`: removed `_drag_visual`, `_drag_start_pos`, `_drag_moved` fields and the ghost-positioning code in `_input`. Replaced with `_setup_board_drop_zone()` (called from `_ready`) that wires `_player_board_view` as a drop target via `set_drag_forwarding`. Hand-card panels now declare drag data in their `set_drag_forwarding` get-callback, which sets a ghost preview via `set_drag_preview`. Added `NOTIFICATION_DRAG_END` handler to clear `_hand_drag_card` and refresh highlights on cancelled drags. Fixed `_show_cancel_btn` fallback callable from removed `_cancel_hand_drag` to `_hide_cancel_btn`. Updated `_on_end_turn` to clear `_hand_drag_card` directly instead of calling the removed helper.
- `_input` reduced to keyboard-only (Escape → pause toggle); all mouse/touch drag state is handled by the native API.

## Documentation Updates

None required — the drag-and-drop pattern is standard Godot and does not need a new agent doc entry.
