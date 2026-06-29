# TID-370: PvP rating model + persistence (MMR/ELO)

**Goal:** GID-102
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

PvP duels record a win-streak / Champion status (GID-101 / TID-368) but there is **no skill
rating** — `docs/agent/multiplayer-coop.md` explicitly notes *"there is still no ranked
ladder across sessions."* This task adds a persistent per-player rating updated after every
duel, plus a cross-session leaderboard the authority owns. It is the data foundation TID-373
(ranked UI) builds on.

## Research Notes

- **Pure rating math — new `game_logic/net/RatingMath.gd`** (scene-free, unit-tested, mirrors
  `AvatarSync`/`BattleNetProtocol`). Use a standard ELO update: `expected(a, b) = 1 /
  (1 + 10^((b-a)/400))`; `new_rating = round(r + K * (score - expected))`, K configurable
  (e.g. 32, smaller above a threshold). Keep it integer-stable and JSON-primitive. Start
  rating `1000`. Add a helper for a provisional/placement window (first N games higher K).
- **Persistence — `SessionState` character record** (`game_logic/net/SessionState.gd`). The
  Champion fields (`pvp_wins/losses/streak/best_streak`) were added in the v3 migration; add
  `pvp_rating: int = 1000` and `pvp_games: int = 0` and **bump
  `CURRENT_SESSION_VERSION = 4`** with a v<4 migration backfilling both on existing members
  (follow the exact v3 pattern at lines 114–129). Add the fields to
  `make_starter_character` (lines 176–210) and confirm `to_dict`/`from_dict` carry them via
  the `members` dict (they round-trip automatically as record keys).
- **Cross-session leaderboard.** A session file already holds all members; the simplest
  "across sessions" ladder for the host-authority model is an aggregate the **authority**
  maintains. Add a `leaderboard: Array` to `SessionState` (top-N `{token, name, rating}`
  recomputed from `members` on each duel end) OR keep it derived (sort `members` by
  `pvp_rating` at read time). Prefer **derived** to avoid a second source of truth — add a
  `SessionState.get_leaderboard(limit)` method that sorts `members` by `pvp_rating`. The
  dedicated server (GID-097) naturally becomes the canonical ladder host.
- **Update hook.** `WorldScene._on_pvp_battle_ended_coop(did_win)` already updates the
  champion record via `SessionStore.update_member` (see TID-368 Changes Made). Extend it: the
  **authority** computes both players' rating deltas with `RatingMath` (it knows both tokens
  via the `peer_id → token` map) and writes both records. A client cannot rate itself — only
  the authority owns the update, consistent with the isolation invariant.
- **Isolation invariant:** all persistence via `SessionStore`, never `save_slot_*.json`.
- **Tests:** new `tests/unit/test_rating_math.gd` (expected-score symmetry, win raises /
  loss lowers, zero-sum-ish K math, placement K). Extend `test_session_state.gd` for the new
  fields + v4 migration backfill.
- **Docs:** update `docs/agent/multiplayer-coop.md` (PvP section + Tests table); the
  "no ranked ladder" limitation line is partially closed (rating + leaderboard exist; global
  matchmaking still does not).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
