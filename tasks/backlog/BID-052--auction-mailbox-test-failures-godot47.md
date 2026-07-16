# BID-052: Auction/mailbox suite failures at HEAD (observed under Godot 4.7.1)

**Category:** code-smell (suspected pre-existing failure or engine-version drift)
**Discovered During:** GID-118 / TID-446 (test run for an unrelated change)

## Description

Running `godot --headless --path . -s tests/runner.gd` at HEAD (before the
TID-446 changes; verified on a clean stash) fails 7 assertions in two suites:

- `test_auction_transfer::test_settle_expired_without_bid_returns_card_to_seller`
  — "card returned to the seller — expected [1] got [2]"
- `test_auction_transfer::test_settle_expired_bidder_who_can_no_longer_afford_it_falls_back_to_seller`
  — same shape
- `test_mailbox::test_claim_mailbox_card_succeeds_once_space_frees_up` (3 asserts)
- `test_mailbox::test_claim_all_stops_at_capacity` (2 asserts)

Total: 2195 passed / 4 tests failed / 1 pending.

## Caveat

The sandbox run used **Godot 4.7.1-stable** (4.6 binaries are proxy-blocked from
GitHub releases; 4.7.1 came from the official itch.io mirror). The failures may
be 4.7 behavioral drift rather than genuinely broken logic — re-run under the
pinned 4.6 in CI to disambiguate. The failing shapes (card counts off by one,
claims returning false) smell like Dictionary/Array iteration-order or
`duplicate()` semantics changes.

## Evidence

- Clean-tree run 2026-07-16 on branch `claude/work-task-tid-445-va29fc`
  (commit de94e10, TID-446 changes stashed).
