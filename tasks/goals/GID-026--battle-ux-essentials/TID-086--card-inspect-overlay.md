# TID-086: Card Inspect Overlay (Tap-to-Inspect During Battle)

**Goal:** GID-026
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

On mobile, players cannot hover over cards to read them. Once a card is played to the board or sits in the enemy's hand area, there is no way to read its stats or effect text. This task adds a tap-to-inspect overlay that works for hand cards, board minions, and enemy board minions.

## Research Notes

- `scenes/battle/BattleScene.gd` — find the card display nodes for hand, player board, and enemy board; add `gui_input` or `pressed` signal connections to each
- Inspect trigger: single tap (touch) or right-click (desktop) on any visible card node
- Overlay design: a centered Panel covering ~60% of the screen showing:
  - Card display_name (large)
  - Card art placeholder or colored background
  - Stats: cost, attack, health
  - magic_type / magic_branch
  - spell_effect description in plain English (map effect IDs to human-readable strings: e.g. `deal_damage_single` → "Deal [power] damage to one enemy minion")
  - Any keywords the card has (from GID-025 when implemented)
- Dismiss: tap anywhere outside the panel, or a close button in the corner
- Must not interfere with drag-to-play: only trigger inspect on a tap that doesn't become a drag (use `InputEventMouseButton` released without significant motion, or a long-press threshold on mobile)
- Follow CLAUDE.md UI sizing (viewport-relative); panel font size ~2.5% vh
- Add a `CardInspectOverlay.gd` scene rather than inlining into BattleScene

## Plan

- Create `scenes/battle/CardInspectOverlay.gd` (extends Control, emits `closed`)
- Centered panel ~60% vp width, dark backdrop dismisses on tap-outside
- Show: name, card color bar, class/type, cost/attack/health, description, spell-effect plain-English, active status effects
- Trigger: right-click on any card in any zone (via `_bind_card_input` generic handler)
- Mobile/touch: left-press + release without drag movement → inspect (tracked via `_drag_moved` flag)
- Wire into BattleScene: add `_drag_moved` tracking, update `_input()` to detect tap-without-drag

## Changes Made

- Created `scenes/battle/CardInspectOverlay.gd` — full-screen overlay, card detail panel
- Modified `BattleScene.gd`:
  - Added `const CardInspectOverlay` and `const SettingsScene` preloads
  - Added `_drag_moved: bool`, `_inspect_overlay`, `_paused`, `_pause_overlay` vars
  - `_start_hand_drag`: sets `_drag_moved = false`; allows unplayable cards to be tracked for tap-to-inspect
  - `_input()`: sets `_drag_moved = true` on mouse motion; on left-release without motion → show inspect
  - `_bind_card_input`: added generic right-click → `_show_card_inspect` for all zones
  - Added `_show_card_inspect(card)` method

## Documentation Updates

Updated `docs/agent/battle-system.md` with card inspect overlay details.
