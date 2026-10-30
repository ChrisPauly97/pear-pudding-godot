# TID-801: Setting + FramesLayout: frames, target cast bar, warning lane, unit rows, corners

**Goal:** GID-189
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Opt-in WoW-style frames for real-time fights (user-approved mockup). RealtimeVisuals is at the 500-line cap.

## Plan

New `FramesLayout` module owned by RealtimeVisuals; thin hooks; reuse the existing hero tokens / board rows so every tap target stays.

## Changes Made

- `scenes/battle/modules/FramesLayout.gd` (new): `enabled()` (setting `battle_layout`), `adopt_token` (token → horizontal frame, portrait outermost), pure `frames_layout(vp, …)`, `apply` (re-run every frame — frames grow as cast bars / pips appear), board rows scaled to `UNIT_SCALE` 0.6 as left-to-right unit frames under each frame, Ally row hidden while minions are locked (no locked plates), Pause / Effects to the bottom-left, warnings on a plate in the top-centre lane (`toast`).
- `RealtimeVisuals`: hooks in build / `_make_token` / `apply_layout` / `update` / `lunge_token` / `token_center` / `toast`; no wind-up lean on frames. Player cast bar moved to `PlayerCastBar.gd` (file now 489 lines).
- Settings › Battle › **Battle Layout**: Classic (default) / Frames (new). Next fight.
- `SwingFx.cast_label`: a free enemy cast reads "Casting Heavy Blow" (no "(0)" — BID-110).

## Documentation Updates

- `docs/agent/battle-system.md`: Frames layout section. CLAUDE.md BattleRealtime row.
