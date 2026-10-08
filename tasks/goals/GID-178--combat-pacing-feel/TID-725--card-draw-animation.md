# TID-725: Card draw animation

**Goal:** GID-178
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md (user request 2026-10-08).

## Research Notes

_TBD._

## Plan

The turn-based deal-in (CardMotion) already ran in real time, but flew from the hand's own edge in 0.26 s, so a draw didn't read. Add a visible draw pile and fly from it, slower.

## Changes Made

- `scenes/battle/modules/DeckPile.gd`: stacked card backs + count, placed right of the hand, top back hops on a draw.
- `CardMotion.deal_from` / `deal_time_mult`; `RealtimeVisuals` builds the pile, points the deal at it (×1.7 flight) and updates count / position each frame.
- Verified with `tools/capture_battle_cards.gd` under xvfb (opening hand mid-flight out of the pile).

## Documentation Updates

- `docs/agent/card-visuals.md`: "Real-time draw pile".
