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

## Resolution

**Not engine drift — two genuine test-authoring bugs**, confirmed by reading
`game_logic/net/AuctionTransfer.gd` and `autoloads/SaveManager.gd` directly
(Godot 4.6 remained unobtainable in-sandbox: GitHub releases are proxy-blocked
by repo scope, the official itch.io mirror only serves the latest build
(4.7.1), and `downloads.tuxfamily.org`/SourceForge mirrors were unreachable or
404. Root-causing via code reading made the version chase unnecessary).

1. **`test_auction_transfer`** (2 tests): both built the seller record with
   `_member("tokSeller", "unused", _NORMAL_CARD_ID, 0)`, which seeds one
   unrelated pre-existing card. `AuctionTransfer.settle_expired()` correctly
   *appends* the returned auction card to `owned_cards`, so the count became 2
   (1 pre-existing + 1 returned), not the 1 the test expected. Fix: use
   `_bare_member("tokSeller", 0)` (empty `owned_cards`) instead — the returned
   card is then the only one, count == 1 as intended.
2. **`test_mailbox`** (2 tests): both scrapped `owned_cards[0]` expecting to
   free a bag slot. But `SaveManager.new_game()` seeds `owned_cards` with the
   12-card starter deck *first* — `owned_cards[0]` is always a deck card, and
   `get_slot_count()` excludes deck cards from the bag-slot count entirely, so
   scrapping it frees nothing. Fix: added a `_first_non_deck_uid(sm)` helper
   that returns the first owned card *not* in `player_deck`, and scrap that
   instead.

Both bugs were present before GID-118 and are unrelated to it or to the Godot
version — they'd have failed identically on 4.6. Fixed directly rather than
left open, since the fix was a small, well-understood test change once
root-caused. Full suite is green: 2199 passed / 0 failed / 1 pending.

## Evidence

- Clean-tree run 2026-07-16 on branch `claude/work-task-tid-445-va29fc`
  (commit de94e10, TID-446 changes stashed) — 7 assertions failing.
- Fix: `tests/unit/test_auction_transfer.gd`, `tests/unit/test_mailbox.gd`.
