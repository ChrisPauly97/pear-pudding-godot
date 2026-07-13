# TID-431: Add Timeout to PvP Challenge Handshakes

**Goal:** GID-115
**Type:** agent
**Status:** done
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

1. Audit every pending-state variable across the three flows to find which side
   actually gets stuck when the other never answers:
   - **Duel**: `_pending_challenge_from` (responder-side incoming) is the real
     stuck flag — `_on_battle_requested` drops any further `request_battle` RPC
     while it's set, which is what makes re-challenge attempts silently fail.
     The challenger itself holds no waiting-state variable at all.
   - **Wager**: same shape, `_pending_wager_from` on the responder.
   - **Draft duel**: two independent stuck flags — `_draft_peer` really is the
     challenger's own outgoing state (per its existing comment), and
     `_pending_draft_from` is the responder's incoming state.
   - **Dedicated-server relay**: `_pvp_relay_challenger_id` on the server node
     itself — the most severe case, since a stuck relay blocks *every* future
     challenge for *every* player on that server, not just the two involved.
2. Add `game_logic/net/ChallengeTimeout.gd` — a pure, unit-testable
   `has_expired(armed_at_msec, now_msec) -> bool` against a 30s
   `TIMEOUT_MSEC` constant, mirroring `RatingMath`/`CardInstanceUtil` in style.
3. Add one `*_armed_at: int = -1` companion variable per pending-state variable
   (`_pending_challenge_armed_at`, `_pending_wager_armed_at`,
   `_pending_draft_from_armed_at`, `_draft_peer_armed_at`,
   `_pvp_relay_challenger_armed_at`). Arm with `Time.get_ticks_msec()` at every
   site that sets the corresponding pending var to a real peer id; clear back to
   `-1` at every site that resets it — including `_start_draft`, where
   `_draft_peer_armed_at` must be disarmed the moment the duel goes active so
   the timeout can never fire mid-pick or mid-battle (that var is reused for
   both "awaiting accept" and "duel in progress").
4. Add `WorldScene._check_challenge_timeouts()`, polled once per frame from
   `_process` (alongside `_update_challenge_proximity`, only while
   `_coop_active`). On expiry it calls straight into the flow's own existing
   decline/abort function (`_decline_challenge` / `_decline_wager_challenge` /
   `_decline_draft_duel` / `_abort_draft_duel` / `_on_relay_pvp_response`) so
   the RPC notification, pending-state reset, and armed_at clearing all happen
   through the one already-tested code path — no duplicated reset logic.
5. Symmetric, no new RPCs: each side's stuck flag expires independently on its
   own local timer (armed at essentially the same wall-clock moment: the
   challenger arms right before sending, the responder arms on receipt, so the
   two clocks are within network latency of each other). This sidesteps the
   only real risk flagged in research — a responder accepting a challenge the
   challenger already gave up on — because expiry always calls the panel's own
   dismiss function first, so a timed-out prompt is physically gone before the
   user could click Accept on it. The existing stale-mismatch guards
   (`_on_battle_responded`, `_on_draft_duel_responded`'s `from_id != _draft_peer`
   check, `_on_relay_pvp_response`'s sender/challenger match) remain as a
   backstop for the sub-frame network-latency window where the two sides'
   clocks could theoretically disagree.
6. Add `tests/unit/test_challenge_timeout.gd` for the pure predicate (idle,
   just-under, exactly-at, well-past, freshly-armed).
7. Document the mechanism in `docs/agent/multiplayer-coop.md` (PvP Card
   Battles section, with a cross-reference from Draft Duels).
8. Archive `BID-034` and update `tasks/index.md`.

## Changes Made

- `game_logic/net/ChallengeTimeout.gd` — new pure helper: `TIMEOUT_MSEC = 30000`
  and `has_expired(armed_at_msec, now_msec) -> bool`.
- `scenes/world/WorldScene.gd`:
  - New `_ChallengeTimeout` preload and five `*_armed_at` instance vars.
  - Armed at: `_on_battle_requested`, `_on_battle_wager_requested`,
    `_on_draft_duel_requested`, `_request_draft_duel`, `_on_relay_pvp_request`.
  - Cleared at every existing reset site for the corresponding pending var:
    `_accept_challenge` (both branches), `_decline_challenge`,
    `_accept_wager_challenge` (all three branches), `_decline_wager_challenge`,
    `_on_draft_duel_responded` (decline branch), `_accept_draft_duel`,
    `_decline_draft_duel`, `_start_draft` (disarms `_draft_peer_armed_at` —
    duel now active), `_reset_draft_state`, `_abort_draft_duel_for_peer`,
    `_abort_draft_duel`, `_on_relay_pvp_response`.
  - New `_check_challenge_timeouts()`, called from `_process` right after
    `_update_draft_duel_proximity()`. Expires each flow via its own existing
    decline/abort function, with a toast for the two flows whose function
    doesn't already show one (`_decline_challenge`/`_decline_wager_challenge`/
    `_decline_draft_duel` don't toast; `_abort_draft_duel(reason)` does, so its
    call passes the message as `reason` instead of a separate `_show_tip`).
- `tests/unit/test_challenge_timeout.gd` — new unit test suite (auto-discovered
  by `tests/runner.gd`): idle/just-under/exactly-at/well-past/freshly-armed.
- Archived `tasks/backlog/BID-034--pvp-challenge-handshakes-no-timeout.md` to
  `tasks/archive/backlog/` and updated `tasks/index.md`.

**Beyond the research notes:** also fixed the dedicated-server relay
(`_pvp_relay_challenger_id`), which the task's research notes didn't call out
explicitly but is the same class of bug and arguably the most severe instance
of it — an unanswered relayed challenge blocks every future challenge for
every player on that server, not just the two peers involved.

**Verification note:** same sandbox constraint as the rest of this goal — no
Godot binary and the release-zip download is blocked by the proxy (403), so
`godot --headless --editor --quit` and `tests/runner.gd` could not be run
here. Every arm/clear site was individually re-read post-edit and cross-checked
against `grep` for the corresponding pending-state variable to confirm the
armed-vs-cleared invariant holds everywhere (armed_at != -1 iff the pending
var it tracks holds a real peer id) — recommend a real headless run in CI
before merge, especially to exercise the co-op PvP handshake tests end-to-end.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` — added the challenge-handshake timeout
  mechanism under "PvP Card Battles" (the shared source of truth for the
  duel/wager/relay flows), with a short cross-reference note added to the
  Draft Duels section's Flow step 2.
