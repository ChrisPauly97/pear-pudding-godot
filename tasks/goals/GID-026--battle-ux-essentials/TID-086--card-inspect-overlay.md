# TID-086: Card Inspect Overlay (Tap-to-Inspect During Battle)

**Goal:** GID-026
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
