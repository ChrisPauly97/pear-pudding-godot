# BID-037: Tournament abort refunds nothing; client antes are not pre-checked

**Category:** design-gap
**Discovered During:** GID-104 / TID-386

A participant disconnecting mid-bracket aborts the tournament without refunding
any antes (v1 documented gap, consistent with the no-refund wager precedent but
harsh for a 6-match bracket). Separately, the host never pre-checks a client's
ante affordability — the client deducts locally in `notify_tournament_start`
and can go briefly negative. A pre-start affordability handshake plus
abort-refund via SessionState member-record writes would close both.

## Resolution

**Part 1 — ante refund on abort.** Added `TournamentSync.refund_payouts(tokens, ante)`
(pure, unit-tested) — every participant token gets back exactly its own ante (flat,
not pooled; unlike `WagerSync.settle()` there's no pool to split, just a plain
refund). `CoopPvP._refund_tournament_antes()` applies it using the same
direct-write pattern as the existing pot payout in `_finish_tournament` /
`_grant_chest_loot_to_token`: the host credited locally via
`SceneManager.save_manager.add_coins`, every other participant credited straight
into its `SessionStore` member record (`rec["coins"] += amount`, `update_member`,
`mark_dirty`). Wired into both places a bracket can die mid-flight:
- `CoopSession._on_coop_peer_disconnected` (the case the BID names directly) —
  refund runs before `_reset_tournament_state()` clears the ante/token
  bookkeeping it needs.
- `CoopSession._on_coop_session_ended` — the whole session tearing down mid-bracket
  is the same kind of interruption; its old comment ("No refunds in v1
  (documented gap)") pointed at this exact BID, so it got the same fix.

**Part 2 — pre-start affordability handshake.** Rather than let the host commit to
a start it might have to partially undo, added a genuine round-trip handshake
before anything is touched: `_start_tournament()` now gathers participants/decks/the
host's own affordability check as before, but instead of deducting coins and
broadcasting immediately, it stashes everything in `_tournament_pending_start` and
sends every client entrant a new `request_tournament_ante_check(ante_coins)` RPC.
Each client answers truthfully via `respond_tournament_ante_check(can_afford)`
(comparing against its own local `SaveManager.coins` — the authoritative source for
*that* client). Only once **every** entrant has confirmed does
`_commit_tournament_start()` actually deduct coins, build the bracket
(`TournamentSync.new_bracket`), and broadcast `notify_tournament_start`. A 30 s
timeout (`_ChallengeTimeout`, the existing challenge/wager/draft-duel precedent) and
a mid-handshake disconnect both cancel the pending start cleanly (nothing was
deducted yet, so there's nothing to refund at that stage).

**Judgment call — reject-the-whole-start vs. kick-and-continue:** the BID's
suggested fix says "the host rejects/kicks a client that can't afford it". A single
"no" answer cancels the **entire** pending start rather than silently dropping just
that one client and continuing with fewer participants: a 3-4 player round-robin
bracket's pairings/decks/indices are all built from the full participant list
up front, so removing one mid-setup would mean rebuilding the whole bracket anyway
— simpler and more predictable to have the host see the tip ("X can't afford the
ante — tournament cancelled.") and manually retry (e.g. once that player has more
coins, or with a different group) than to auto-reshape the bracket underneath
them. This satisfies the BID's core ask — a client can no longer be started into a
tournament it can't afford and go negative — without adding bracket-reshaping
complexity that wasn't asked for.

Added unit tests for `refund_payouts` in `tests/unit/test_tournament_sync.gd`
(flat-per-token refund, ante-count scaling, zero/negative-ante no-ops, empty-token
skip, empty-list no-op, total-conservation sanity check). The ante-check handshake
itself is network/RPC-shaped rather than pure logic, so it isn't independently
unit-tested beyond the pure refund math — it's exercised indirectly by
`tests/world_scene_smoke.gd` (both new RPCs route correctly through `NetSync._route`)
and manually reasoned through above; a live-session integration test for the
full handshake would need a multi-peer harness beyond this fix's scope.

Verified: `godot --headless --editor --quit` parse-clean; full test suite
(`tests/runner.gd`) 2366 passed / 0 failed; `tests/world_scene_smoke.gd` PASS
(79 routed handlers, up from 77 — the two new ante-check RPCs); `tests/net_session_smoke.gd`
PASS.
