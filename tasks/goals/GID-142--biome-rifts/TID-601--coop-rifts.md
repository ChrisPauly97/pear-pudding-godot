# TID-601: Co-op Rifts & Per-Rift Leaderboard

**Goal:** GID-142
**Type:** agent
**Status:** done
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

Rift + tier in the floor map name (deterministic for every peer); co-op run carries rift/tier; guardian win = tier clear credited to each peer's own save; one leaderboard per rift; overlay tab "Rifts". Tier cap uses the host's best (peers' bests aren't on the host); per-player boons in co-op not done — the co-op draft stays shared cards (noted in docs).

## Changes Made

- `SpireFloorGen`: `map_name_for(floor, seed, rift, tier)`, `parse_map_name()`; WorldScene parses the name.
- `SceneManager`: solo entry/advance/resume + `enter_spire_coop(picker, rift, tier)` use the new names;
  `end_coop_spire_run` stats carry rift/tier.
- `CoopActivities`: next-floor name, guardian win ends the run as a clear, `record_tier_clear` + rift board submit
  on every peer, solo clears posted to rift boards.
- `SaveSpire`: `_record_clear()` shared by solo/co-op, `record_tier_clear()`.
- `SessionState`: rift boards, generic sanitize/snapshot. `LeaderboardOverlay`: Rifts tab.
- Tests: `test_rift_defs.gd` +3; `test_scene_manager_state.gd` / `spire_draft_smoke.gd` updated for the names.
  Suite green; CI smokes + net_coop/session/world_sync/leaderboard smokes clean; lint clean.

## Documentation Updates

`rifts.md` co-op + leaderboard section, run-state naming.
