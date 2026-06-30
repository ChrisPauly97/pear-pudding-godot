# TID-373: Ranked queue UI + season leaderboard panel

**Goal:** GID-102
**Type:** agent
**Status:** pending
**Depends On:** TID-370

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TID-370 adds the persistent rating + derived leaderboard data. This task surfaces it: a
**leaderboard panel** ranking the session's players, a **rating display** in the roster /
result UI, and a lightweight **"ranked duel"** opt-in so a duel counts toward rating
explicitly (vs a casual/friendly duel that does not).

## Research Notes

- **UI pattern — `scenes/ui/BaseOverlay.gd`.** All overlays extend `BaseOverlay` (or are
  instantiated `.new()` like `MultiplayerLobbyScene` / `SettingsScene`); they are
  viewport-relative and rebuilt on resize (see CLAUDE.md "UI Sizing"). The session roster
  panel already exists in WorldScene (`_build_coop_roster` / `_refresh_coop_roster`,
  `multiplayer-coop.md` → "Session roster"). Add a **rating column / badge** there, and a
  separate full **Leaderboard overlay** opened from the lobby or a HUD button.
- **Data source.** Read `SessionState.get_leaderboard(limit)` (added in TID-370) via the open
  `SessionStore` on the authority. A **client** does not hold the full roster ratings — so
  the authority must push a leaderboard snapshot: add `NetSync.recv_leaderboard(rows: Array)`
  (reliable, authority → all) broadcast on session join and after each duel end, plus an
  on-demand `submit_leaderboard_request()` (client → authority). Mirror the late-join snapshot
  pattern used for party bounties (`recv_party_bounties_snapshot`, see
  `multiplayer-coop.md` → "Late-join snapshot").
- **Ranked vs casual.** Add a "Ranked" toggle to the challenge flow (alongside the existing
  ante toggle from TID-368). A casual/friendly duel sets a flag so TID-370's rating update is
  skipped. Reuse `GameState.friendly_duel` if it already gates rewards (grep — TID-368 notes
  it exists). Thread the flag through `enter_pvp_battle` → `_on_pvp_battle_ended_coop`.
- **Result UI — `scenes/battle/BattleResultUI.gd`.** `show_pvp_result(did_win, coins_delta)`
  exists (TID-368). Add an optional rating-delta line ("+18 rating" gold / "−14 rating" red)
  shown only for ranked duels.
- **Mobile/desktop parity** (CLAUDE.md): the leaderboard + ranked toggle need touch targets,
  not just keys.
- **Tests:** mostly UI (lighter test burden). If a `recv_leaderboard` snapshot helper is
  added as a pure encode/decode, unit-test it. Otherwise a smoke check that the authority
  broadcasts the snapshot on duel end.
- **Docs:** update `docs/agent/multiplayer-coop.md` (ranked UI subsection; new RPCs in the
  RPC table).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
