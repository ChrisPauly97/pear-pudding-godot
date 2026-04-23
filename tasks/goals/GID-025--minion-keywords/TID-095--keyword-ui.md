# TID-095: Keyword UI — Display Keyword Badges on Cards

**Goal:** GID-025
**Type:** agent
**Status:** done
**Depends On:** TID-093

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players need to see at a glance which minions have keywords. This task adds keyword badges to card display in both the hand and the board, and handles Shroud's badge disappearing when it is consumed.

## Research Notes

- Find the card display node used in BattleScene for hand cards and board cards — likely a Control with attack/health Labels; add a keyword badge area
- Badge design: a small rounded Label or Panel per keyword, positioned along the bottom edge of the card
  - Ward → dark blue badge, text "Ward"
  - Surge → orange badge, text "Surge"
  - Shroud → silver/white badge, text "Shroud" (removed when `shroud_active` becomes false)
- Badge area: an HBoxContainer of badge Labels, sized relative to the card width
- On board cards: badges must remain visible alongside attack/health numbers — position carefully so they don't overlap
- Shroud badge removal: connect to the signal emitted by TID-094 when Shroud is consumed (`GameBus.emit_signal("shroud_consumed", zone_index, player_side)` or similar); find the board card display for that zone and hide/remove the Shroud badge
- Card inspect overlay (TID-086): also show keywords there in plain text with a one-line description:
  - Ward — "Enemy attacks must target this minion first."
  - Surge — "Can attack the turn it is summoned."
  - Shroud — "Absorbs the first hit. (Active / Consumed)"
- Follow CLAUDE.md UI sizing; badge font ~1.8% vh, badge height ~2.5% vh

## Plan

**Card badges** (`BattleScene.gd`):
- Add `_update_keyword_badges(hbox, card)` — clears and rebuilds one colored Label per active keyword. Shroud badge omitted when `card.shroud_active == false` (consumed). Colors: Ward=dark blue, Surge=orange, Shroud=silver. Font 1.8% vh.
- `_build_card_vbox()`: always append a "KeywordRow" HBoxContainer (centered) at the bottom, populated by `_update_keyword_badges()`. Empty for cards with no keywords (collapses to zero height).
- `_update_card_view()`: find "KeywordRow" by name and call `_update_keyword_badges()` on it (or trigger a full rebuild if missing).

**Ward visual feedback** (`BattleScene.gd`):
- `_apply_card_style()` for `"enemy_board"`: when an attacker is selected, dim (darken) enemy minions that are not in `_get_ward_valid_targets()` (i.e. non-Ward while Ward exists). Valid targets keep their normal style (the player clicks them to attack).
- `_refresh_hero()`: `is_attack_targetable` set false when any enemy Ward minion is alive, removing the red-border attack highlight from the hero.

**Card inspect overlay** (`CardInspectOverlay.gd`):
- Add `const Keywords = preload(...)`.
- After the spell-effect section, if `_card.keywords` is non-empty, add a separator and one Label per keyword: "Ward — Enemy attacks must target this minion first." / "Surge — Can attack the turn it is summoned." / "Shroud — Absorbs the first hit. (Active)" or "(Consumed)". Font 2.0% vh.

## Changes Made

- **`scenes/battle/BattleScene.gd`**:
  - Added `_update_keyword_badges(hbox, card)` — typed parallel arrays for keys/labels/colors; Shroud badge omitted when `shroud_active == false`. Font 1.8% vh.
  - `_build_card_vbox()`: always appends a centered "KeywordRow" HBoxContainer populated by `_update_keyword_badges()`.
  - `_update_card_view()`: finds "KeywordRow" by name and refreshes it (Shroud badge disappears automatically on next refresh after `shroud_active` is cleared).
  - `_apply_card_style()`: new `"enemy_board"` branch when `_dragged_card` non-empty — calls `_get_ward_valid_targets()` and darkens non-Ward cards by 0.45.
  - `_refresh_hero()`: computes `ward_blocks_hero` by scanning enemy board; sets `is_attack_targetable = false` when Ward is present, removing the red attack-target highlight from the hero.
- **`scenes/battle/CardInspectOverlay.gd`**: added `const Keywords = preload(...)`. Added keyword descriptions section (separator + one Label per keyword) before the status-effects section. Shroud label appends "(Active)" or "(Consumed)" based on `_card.shroud_active`.

## Documentation Updates

- Updated `docs/agent/battle-system.md` — added Keyword UI section covering badge display, Ward dimming, and inspect overlay keywords.
