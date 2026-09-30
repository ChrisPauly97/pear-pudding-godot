# TID-630: Shared long-press tracking

**Goal:** GID-150
**Type:** agent
**Status:** done

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

MapViewOverlay and RealmMapOverlay each carried `_lp_active/_lp_pos/_lp_elapsed` plus their own threshold and slop
constants for long-press-to-waypoint, and LongPressDetector re-implemented the same timing. The overlays could not
adopt LongPressDetector directly: it also fires on a left-mouse hold and does not report the press position, which
would change map input.

## Plan

Extract the timing/slop state into a pure `LongPressTracker`; keep each owner's own input wiring.

## Changes Made

New `scenes/ui/LongPressTracker.gd` (`press`, `move`, `strayed`, `cancel`, `tick`, `start_pos`). Both map overlays
and LongPressDetector use it; the overlays' duplicated constants and fields are gone. LongPressDetector keeps
`THRESHOLD_SEC` / `SLOP_PX` as aliases. New `tests/unit/test_long_press_tracker.gd`. No behaviour change.

## Documentation Updates

CLAUDE.md (helper pointer).
