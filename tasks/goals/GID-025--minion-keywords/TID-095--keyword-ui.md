# TID-095: Keyword UI — Display Keyword Badges on Cards

**Goal:** GID-025
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
