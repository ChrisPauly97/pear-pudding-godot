# TID-449: Bigger Cards + Overlap-Fan Hand + Card-Face Simplification

**Goal:** GID-119
**Type:** agent
**Status:** done
**Depends On:** TID-448

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Battle cards are `vh*0.10 × vh*0.19` — the smallest touch targets in the game, on the
screen where precision matters most. Card size is defined twice: `BattleScene.gd
_make_card_view` and `CardViewBuilder._slot_size()` (plus a third inline copy in
`refresh_board_zone`). The hand is a plain HBoxContainer that overflows off-screen
when card count × card width exceeds the row. Card faces cram name + illustration +
stats + flavor description + keywords into the panel at 1.4–1.8% vh fonts.

## Research Notes

- With TID-448's row heights (board 0.27, hand 0.24) a `0.135 × 0.24` card fits.
  5 board slots × 0.135 vh ≈ 0.73 vh wide ≈ 38% of a 16:9 viewport width — fits the
  0.86-width content column easily.
- Godot draws later HBox children on top, so negative separation produces a
  right-on-top fan; gui_input hits the topmost overlapping panel (standard fan
  behaviour).
- Flavor `description` on minion faces is decorative; ability/emergence text is
  gameplay-relevant and must stay. The inspect overlay (long-press) carries the full
  text either way.
- `_make_card_ghost` and `_trigger_dual_face_flip` read `custom_minimum_size` — safe.

## Plan

1. `CardViewBuilder.card_size() -> Vector2` = `(vh*0.135, vh*0.24)`; use it in
   `_slot_size()`, `refresh_board_zone`, and `BattleScene._make_card_view`.
2. `refresh_zone(zone_id=="hand")`: after add/update, set a `separation` override on
   the HBox — 4px normally; when N × card_w exceeds the available width, negative
   separation so the hand fans, clamped to ≥ −55% of card width.
3. `build_card_vbox` / `update_card_view`: minions no longer show flavor description
   (spells/emergence keep ability text); fonts raised — name 2.0% vh, stats 2.2% vh,
   ability 1.7% vh, keyword badges 2.0% vh; illustration band 0.07 vh.

## Changes Made

- `CardViewBuilder`: new `card_size()`; `_slot_size()` delegates to it;
  `refresh_board_zone` reuses it for revived-card panels; hand fan separation logic in
  `refresh_zone` (`_apply_hand_separation`); minion flavor text dropped from card
  faces (`DescLabel` text set to "" for minions without ability text, autowrap kept
  for spells); fonts raised per plan.
- `BattleScene._make_card_view` uses `_view.card_size()`.

## Documentation Updates

- `docs/agent/battle-system.md`: card sizing + hand fan noted in the GID-119 section.
