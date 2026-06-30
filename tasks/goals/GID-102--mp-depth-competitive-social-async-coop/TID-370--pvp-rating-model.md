# TID-370: PvP rating model + persistence (MMR/ELO)

**Goal:** GID-102
**Type:** agent
**Status:** done
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

1. **`game_logic/net/RatingMath.gd`** (new pure helper, scene-free, mirrors
   `BattleNetProtocol`): `expected_score(a, b)`, `k_factor(games)` (placement K higher
   for the first `PLACEMENT_GAMES`), `updated(rating, opp_rating, score, games)` →
   integer-stable ELO, plus `START_RATING = 1000` and `clamp_rating`. JSON-primitive,
   no engine objects.
2. **`game_logic/net/SessionState.gd`**: add `pvp_rating: int = 1000` and
   `pvp_games: int = 0` to `make_starter_character`; bump `CURRENT_SESSION_VERSION = 4`
   with a `ver < 4` migration backfilling both on existing members (same shape as v3);
   add `get_leaderboard(limit)` that returns members sorted by `pvp_rating` desc as
   `[{token, name, rating, games, wins, losses}]` (derived — no second source of truth).
3. **`scenes/world/WorldScene.gd` `_on_pvp_battle_ended_coop`**: after the existing
   champion update, on the host authority compute **both** combatants' rating deltas via
   `RatingMath` and write both records. Host token = `MpProfile.get_token()`; opponent
   peer = `_pvp_ante_peer1` (set on both `_enter_pvp` and `_enter_pvp_wagered`), opponent
   token via `_session_token_by_peer`. Set `_challenge_target_peer = from_id` in
   `_accept_challenge` so the host-accepts-incoming path also records the opponent peer.
   Increment `pvp_games` for both. Guarded by `is_host()` + `SessionStore.is_open()`.
4. **Tests:** new `tests/unit/test_rating_math.gd` (expected-score symmetry/bounds, win
   raises / loss lowers, zero-sum-ish symmetric K, placement K, start rating). Extend
   `tests/unit/test_session_state.gd` for the new fields + v4 migration backfill +
   `get_leaderboard` ordering.
5. **Docs:** update `docs/agent/multiplayer-coop.md` (PvP section + Tests table); soften
   the "no ranked ladder" limitation line (rating + derived leaderboard now exist; global
   matchmaking still does not).

Complexity is moderate and the task notes are detailed — proceeding directly to Build.

## Changes Made

- **`game_logic/net/RatingMath.gd`** (new, + `.uid`): pure, scene-free, unit-tested ELO
  helper mirroring `BattleNetProtocol`. `START_RATING = 1000`, `MIN_RATING = 100`,
  `SCALE = 400`, `K_BASE = 32`, `K_PLACEMENT = 64`, `PLACEMENT_GAMES = 10`.
  `expected_score(a, b)`, `k_factor(games)`, `updated(rating, opp, score, games)` (integer-
  stable, clamped), `clamp_rating(r)`. `score` 1.0/0.0 (0.5 reserved for a draw → no-op at
  equal rating).
- **`game_logic/net/SessionState.gd`**: bumped `CURRENT_SESSION_VERSION 3 → 4`; added a
  `ver < 4` migration backfilling `pvp_rating` (1000) / `pvp_games` (0) on existing members
  (same shape as v3); added both fields to `make_starter_character`; added
  `get_leaderboard(limit)` — derived top-N sorted by `pvp_rating` desc (ties → games →
  token), returning `{token, name, rating, games, wins, losses}` rows.
- **`scenes/world/WorldScene.gd`**:
  - Added `const _RatingMath` preload.
  - `_accept_challenge`: set `_challenge_target_peer = from_id` before `_enter_pvp` so the
    host-accepts-incoming path records the opponent peer (also benefits spectator tracking).
  - `_on_pvp_battle_ended_coop`: after the champion update, calls new `_update_pvp_ratings`
    on the host authority — resolves the opponent token from `_pvp_ante_peer1` via
    `_session_token_by_peer`, computes both combatants' zero-sum-ish ELO deltas, bumps
    `pvp_games`, writes both records (`update_member` + `mark_dirty`). Guarded by
    `is_host()` + `SessionStore.is_open()`; clients never rate themselves.
- **Tests:** new `tests/unit/test_rating_math.gd` (15 cases); extended
  `tests/unit/test_session_state.gd` (+7 cases: rating fields, v4 backfill, leaderboard
  ordering/limit/record/empty). Full suite 1712 passing; `net_pvp_smoke` and
  `net_session_smoke` green; headless import clean.
- **Backlog:** logged `BID-025` — opponent champion win/loss/streak stats are still
  host-only (TID-368 behaviour); only the rating is updated for both sides here.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: added a "Ranked rating (GID-102 / TID-370)" paragraph
  in the PvP rewards section (RatingMath, the both-records authority update, derived
  leaderboard); softened the "no ranked ladder" limitation line (rating + leaderboard now
  exist; global matchmaking + ranked UI still pending TID-373); added the `test_rating_math`
  row and updated the `test_session_state` row (25 → 32 cases) in the Tests table.
