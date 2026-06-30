# TID-378: Async card auction house

**Goal:** GID-102
**Type:** agent
**Status:** pending
**Depends On:** TID-376

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Trading (TID-366) and the party stash (TID-376) require coordination. An **auction house**
lets a player list a card for coins, with other members buying or bidding **asynchronously**
(the seller need not be online). The authority/dedicated server settles trades. This is the
heaviest async task — consider it the lowest-priority of the goal.

## Research Notes

- **Reuses TID-376 transfer plumbing.** Listing escrows a card instance into an
  authority-held holding area (same re-key mechanic as the stash deposit), and settlement
  moves it to the buyer + coins to the seller. Build TID-376 first.
- **Storage — `game_logic/net/SessionState.gd`.** Add `auctions: Array` (authority-owned,
  persisted) shaped per listing: `{id, seller_token, card_instance, buyout: int, bid: int,
  bidder_token, expires_day, status}` where `status` ∈ {`active`, `sold`, `cancelled`,
  `expired`}. Bump `CURRENT_SESSION_VERSION` (after TID-370/TID-376) with a migration adding
  `auctions = []`. Use the existing `days_elapsed` field for expiry (no real-time clock
  needed). Escrowed card instances live inside the listing dict (removed from the seller's
  `owned_cards` on list, like a stash deposit).
- **Wire helper — new `game_logic/net/AuctionSync.gd`** (pure, unit-tested, mirrors
  `TradeSync.gd`): encode/decode for list / bid / buyout / cancel intents and a listings
  snapshot. Validate buyout/bid > 0, coerce ids to strings, fully-defaulted decode.
- **RPCs — `scenes/world/NetSync.gd`** (all reliable; mirror the trade/stash flow):
  - `submit_auction_list(payload)` — authority validates seller owns the card, escrows it,
    creates the listing, persists, broadcasts `recv_auction_update`.
  - `submit_auction_bid(payload)` — authority validates buyer has coins ≥ bid > current bid,
    holds the bid (escrow buyer coins or just record highest bidder — recommend **record-only
    + charge on settle** to keep it simple), persists, broadcasts.
  - `submit_auction_buyout(payload)` / `submit_auction_cancel(payload)` — settle/cancel.
  - `recv_auction_update(snapshot)` (authority → all) + late-join snapshot via the existing
    character/world fan-out.
- **Settlement.** On buyout or expiry-with-highest-bid: authority moves the escrowed instance
  to the winner (re-key UID into their namespace), credits the seller's `coins`, debits the
  buyer, marks `sold`, persists. On cancel/expiry-no-bid: return the instance to the seller.
  Expiry is checked when `days_elapsed` advances (hook the day-tick the session already runs).
- **Dedicated server fit.** The authority owns all of this; on a dedicated server (GID-097)
  the server is the persistent auctioneer even when no listing player is connected — this is
  the natural home for a long-running market. Confirm the persist/settle paths run without a
  local player (the server already runs co-op ticks without a player, per GID-097).
- **Unique cards** blocked (`is_unique`), same as trade/stash.
- **UI.** Auction house overlay (BaseOverlay): browse active listings (card, seller, current
  bid/buyout, expiry), bid/buyout buttons, a "List a card" flow from your collection, and a
  "My listings" tab. Viewport-relative, mobile parity.
- **Tests:** `tests/unit/test_auction_sync.gd` (intent + snapshot round-trip, defaults,
  garbage); extend `test_session_state.gd` (auctions field, round-trip, migration, escrow
  no-dupe). Optional loopback smoke for list→buy settle.
- **Docs:** update `docs/agent/multiplayer-coop.md` (new "Auction house" subsection + RPC +
  Tests tables).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
