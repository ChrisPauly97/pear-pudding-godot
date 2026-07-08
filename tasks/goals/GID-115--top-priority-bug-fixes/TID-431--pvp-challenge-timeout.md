# TID-431: Add Timeout to PvP Challenge Handshakes

**Goal:** GID-115
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Promotes **BID-034**. If a challenge target never answers a normal duel, wagered duel,
or draft duel challenge, the challenger's pending state stays set until the peer
disconnects. While pending, challenge-related buttons stay hidden and no new challenge
can be issued — a soft-lock any player can trigger on another simply by ignoring the
prompt. A ~30 s timeout that resets the pending state and toasts "No response" fixes
all challenge flows at once.

## Research Notes

All pending-state variables live in `scenes/world/WorldScene.gd`:

- **Incoming challenge state:** `_pending_challenge_from: int` (line 192),
  `_pending_challenge_deck: Array` (193), `_pending_challenge_ranked: bool` (194).
  Set at lines 3192–3196 when a challenge arrives; cleared on accept/decline around
  lines 3316–3351.
- **Outgoing draft state:** `_draft_peer: int` (line 319). Set at line 8418 when the
  challenger sends `request_draft_duel` via `_net_sync.rpc_id(...)` (line 8420);
  cleared on decline (line 8444) or duel start (line 8598); peer-disconnect cleanup at
  line 8608.
- There is also `_pending_draft_from` and `_pending_wager_from` (grep for them; wager
  state referenced at line 7713) — the timeout must cover the **challenger-side**
  pending state for all three flows (duel, wager, draft). Audit each flow for its
  outgoing-side variable: the normal duel flow's outgoing state is tracked via
  `_challenge_target_peer` / challenge gating at line 3074
  (`_pending_challenge_from != -1 or SceneManager._state != State.WORLD`).
- **Gating that causes the soft-lock:** line 8403
  (`_draft_peer != -1 or _pending_draft_from != -1 or _pending_challenge_from != -1`),
  line 3074, line 6666 (`_trade_window_mine.visible = ... and _pending_challenge_from == -1`),
  line 7713.
- **Fix shape:** one shared timeout mechanism (e.g. a `_challenge_timeout_timer:
  SceneTreeTimer` or a timestamp checked in `_process`) armed whenever an outgoing
  challenge of any kind is sent, disarmed on answer/start, and on expiry: reset the
  relevant pending vars, notify the target (optional RPC so the *incoming* prompt on
  the other side also closes — otherwise the responder can accept a challenge the
  challenger has already timed out; if skipping this, the accept path must tolerate a
  stale accept gracefully, e.g. the existing "still owns uid / still in WORLD" guards),
  and toast via `GameBus.hud_message_requested.emit("No response to your challenge.")`.
- **Incoming side:** also consider expiring `_pending_challenge_from` on the responder
  after the same window so the two sides can't disagree for long.
- Timeouts must be robust to the challenge being answered mid-flight: on expiry,
  re-check that the pending var still refers to the same peer/challenge instance
  (e.g. a monotonically increasing challenge sequence number captured by the timer
  callback) so a late timer can't clobber a *new* challenge's state.
- Tests: `tests/unit/` has PvP flow tests from GID-104 (grep for `draft_duel` /
  `challenge` under `tests/`). Add a unit test for the reset helper if the logic is
  extracted into a testable function (preferred — WorldScene is huge; put the pure
  "should this pending state expire" logic somewhere unit-testable or keep it minimal).
- After the fix, move `tasks/backlog/BID-034--pvp-challenge-handshakes-no-timeout.md`
  to `tasks/archive/backlog/` and update `tasks/index.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
