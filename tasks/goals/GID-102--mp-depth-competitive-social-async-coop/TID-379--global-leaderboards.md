# TID-379: Global leaderboards (Spire + co-op clears)

**Goal:** GID-102
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Single-player has score-y modes — the **Endless Spire** roguelike draft (GID-038) and co-op
**joint boss clears** (GID-099). This task records best results to authority-persisted
leaderboards so the party/session can compete on more than just PvP rating (TID-370 covers
PvP; this covers PvE achievement).

## Research Notes

- **What to rank.**
  - **Endless Spire:** highest floor / longest run per player (GID-038 — grep
    `Spire` in `autoloads`/`scenes` for the run-end signal + the score it already computes).
  - **Co-op boss clears:** fastest clear / highest party size / boss tier defeated (GID-099 —
    `coop_battle_ended` payload + `CoopBattleScaling` tier). Record per-party or per-player.
- **Storage — `game_logic/net/SessionState.gd`.** Add `leaderboards: Dictionary` shaped
  `{spire: Array, coop_clears: Array}` where each entry is `{token, name, value, day}`,
  authority-owned + persisted, kept sorted + capped (top N). Bump
  `CURRENT_SESSION_VERSION` (after the other Phase tasks) with a migration adding the field.
  Add a `SessionState.record_leaderboard(board, token, name, value)` that inserts/updates the
  player's best and re-sorts.
- **Submission path.** Spire and co-op battles already end with signals/handlers
  (`GameBus.coop_pve_battle_ended`, the Spire run-end). On run/clear end:
  - **Authority:** call `SessionState.record_leaderboard` directly via `SessionStore`.
  - **Client:** `NetSync.submit_leaderboard_score(board, value)` (reliable) → authority
    records + broadcasts. (Spire is single-player, so a co-op session may not be active during
    a Spire run — only submit when `NetworkManager.is_active()`; otherwise it's a local-only
    best. Decide in Plan whether to also keep a device-local best in `MpProfile` for offline.)
- **Broadcast/snapshot.** `NetSync.recv_leaderboards(snapshot)` (authority → all, reliable)
  on join + after each update; reuse the party-bounties late-join snapshot pattern.
- **UI.** A Leaderboards overlay (BaseOverlay) with tabs (Spire / Co-op clears / and link to
  the PvP rating board from TID-373 if it lands — consider one unified "Rankings" overlay).
  Viewport-relative, mobile parity.
- **Note vs TID-373.** TID-373 builds the *PvP rating* board; this builds *PvE* boards. If
  both land, unify them into one "Rankings" overlay with tabs to avoid two near-identical
  panels — coordinate ordering.
- **Tests:** extend `test_session_state.gd` (leaderboards field default, record/sort/cap,
  round-trip, migration). Pure `record_leaderboard` sort/cap unit-tested.
- **Docs:** update `docs/agent/multiplayer-coop.md` (new "Leaderboards" subsection + RPC +
  Tests tables); cross-link the GID-038 Spire doc if one exists.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
