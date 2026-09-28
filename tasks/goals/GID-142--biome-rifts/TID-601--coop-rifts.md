# TID-601: Co-op Rifts & Per-Rift Leaderboard

**Goal:** GID-142
**Type:** agent
**Status:** pending
**Depends On:** TID-597

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Co-op Spire and the PvE leaderboard assume one ladder of floors. Make them rift + tier aware.

## Research Notes

- `scenes/world/coop/CoopActivities.gd`: `_start_coop_spire` (L389), co-op draft (L410–561, with NetSync RPCs
  `recv_spire_draft_start` / `submit_spire_draft_choice` / `recv_spire_draft_choice`, NetSync L542–615), guardian
  engage (L580–590), `_submit_pve_score("spire", floors_cleared)` (L1049).
- Leaderboard: `scenes/ui/LeaderboardOverlay.gd` tabs Ranked / Spire / Co-op Clears (L52), `_pve_cache` (L29) —
  change "Spire" to per-rift best tier (rift picker or one row per rift).
- Co-op tier choice: host picks, capped at the *lowest* party member's best + 1 for that rift; first-clear XP per player
  against their own `rift_first_clears`.
- Boons in co-op: each player drafts their own boon (host resolves) — adapt the shared draft flow.
- Smoke tests: `tests/world_scene_smoke.gd` drives all `_route` handlers; update handler names if they change.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
