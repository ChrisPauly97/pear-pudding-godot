# TID-378: Async card auction house

**Goal:** GID-102
**Type:** agent
**Status:** done
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

1. `game_logic/net/SessionState.gd` — bump `CURRENT_SESSION_VERSION` 7→8, add
   `auctions: Array` field (defensive to_dict/from_dict + migration backfill).
2. `game_logic/net/AuctionSync.gd` (new) — pure encode/decode for list / bid /
   buyout / cancel intents and the listings snapshot, mirrors `TradeSync.gd`.
3. `game_logic/net/AuctionTransfer.gd` (new) — pure business logic mirroring
   `StashTransfer.gd`: `list_card`, `place_bid` (record-only, no escrow),
   `buyout` (moves card + coins between two member records), `cancel` (returns
   the escrowed card), `settle_expired` (host-tick sweep for `days_elapsed >=
   expires_day`, settling to the highest bidder or returning to the seller).
   Unique cards blocked, same as trade/stash. Listing ids are deterministic
   (`auc_<n>`, derived from existing ids — no wall-clock/random dependency).
4. `scenes/world/NetSync.gd` — 4 new RPCs mirroring the stash section:
   `submit_auction_list`, `submit_auction_bid`, `submit_auction_buyout`,
   `submit_auction_cancel` (client→authority, reliable) and
   `recv_auction_update` (authority→all, reliable, full snapshot).
5. `scenes/world/WorldScene.gd` — host-side handlers (validate via
   `AuctionTransfer`, persist, broadcast), an "Auction" HUD button beside
   Stash/Ghost Duels, late-join snapshot fan-out (alongside stash/leaderboard),
   and a `_tick_session_persist`-hooked expiry sweep (closest existing
   periodic host tick — see note below on `days_elapsed`).
6. `scenes/ui/AuctionHouseOverlay.gd` (new) — mirrors `PartyStashOverlay.gd`:
   a "List a Card" row (price stepper + List button) over my sellable
   collection, an "Active Listings" column (bid-stepper + Buyout per row),
   and a "My Listings" column (status + Cancel for my own active listings).
7. Tests: `tests/unit/test_auction_sync.gd`, `tests/unit/test_auction_transfer.gd`
   (new), extend `tests/unit/test_session_state.gd` for the `auctions` field.
8. Docs: `docs/agent/multiplayer-coop.md` — new "Auction house" subsection +
   RPC/Tests table rows.
9. Run the full unit suite + headless editor import; fix anything red.

**Known limitation (documented, not fixed here):** `SessionState.days_elapsed`
is not currently advanced by any co-op tick — it is only ever read (e.g. for
the dungeon-crawl seed), never incremented, so listing expiry is effectively
dormant until a future goal wires a synced day/night clock across co-op
(the gap GID-103 "Shared World Life — Synced Clock" exists to fill). The
sweep is still implemented and unit-tested against `days_elapsed` so it
activates automatically once that clock lands — logged as a backlog item
mirroring the BID-024 pattern (a correctly-built system dormant pending
another goal), not worked around here.

## Changes Made

- `game_logic/net/SessionState.gd` — bumped `CURRENT_SESSION_VERSION` 7→8, added
  `auctions: Array` field with defensive `to_dict`/`from_dict` + a v8 migration
  backfilling `auctions = []` for pre-v8 session files.
- `game_logic/net/AuctionSync.gd` (new) — pure encode/decode for list/bid/id
  (buyout+cancel) intents, `normalize_listing` (full-shape defaults + garbage
  tolerance), `decode_snapshot`; owns `LISTING_DURATION_DAYS = 3` and the status
  constants.
- `game_logic/net/AuctionTransfer.gd` (new) — pure business logic:
  `list_card` (escrow + unique-card block + deterministic `auc_<n>` ids),
  `place_bid` (record-only, no escrow), `buyout` (moves card + coins between two
  member records), `cancel` (returns the escrowed card, a standing bid doesn't
  block it), `settle_expired` (host-tick sweep over the full member roster: sells
  to an affordable highest bidder or returns to the seller), and a
  `_prune_completed` cap (30 completed listings, mirrors `PVE_LEADERBOARD_CAP`).
- `scenes/world/NetSync.gd` — 4 new client→authority RPCs
  (`submit_auction_list/bid/buyout/cancel`) + `recv_auction_update` (authority→all,
  full snapshot), all reliable, mirroring the stash RPC section.
- `scenes/world/WorldScene.gd` — host-side `_on_auction_*_submitted` handlers,
  `_sweep_expired_auctions()` hooked into the host branch of the existing
  `_tick_session_persist` tick, `_broadcast_auction_update`/`_on_auction_update_received`,
  an "Auction" HUD button beside Stash/Ghost Duels, late-join snapshot fan-out in
  `_send_character_to_peer` (alongside stash/PvE-leaderboards), and
  `_peer_for_token`/`_apply_updated_member_to_peer_by_token` (new — resolves a
  token to its currently-connected peer, needed because a buyout/settlement can
  touch a member who isn't the RPC sender, e.g. the seller on a client's buyout,
  or any party during an expiry sweep).
- `scenes/ui/AuctionHouseOverlay.gd` (new) — 3-tab overlay (Sell / Browse / My
  Listings), tab-button pattern mirrored from `LeaderboardOverlay`, price/bid
  steppers mirrored from `PartyStashOverlay`'s coin steppers.
- Tests: `tests/unit/test_auction_sync.gd` (13 cases), `tests/unit/test_auction_transfer.gd`
  (23 cases, new files); extended `tests/unit/test_session_state.gd` with 6 cases
  for the `auctions` field (default, round-trip, garbage, v8 migration backfill +
  preserves-existing, versionless-dict default) — 66 cases total in that file.
- Logged `tasks/backlog/BID-039` — `SessionState.days_elapsed` is never advanced
  by any co-op tick today, so the expiry sweep is correctly built but dormant
  until GID-103 (Shared World Life — Synced Clock) lands; mirrors the BID-024
  "system built correctly, dormant pending another goal" pattern. Not a bug
  introduced by this task, not fixed here (out of this task's scope).

**Verification caveat**: this sandbox's egress policy blocked the GitHub release
download needed to install the `godot` 4.6 headless binary (403, not retried per
`/root/.ccr/README.md` guidance), so the unit suite and headless editor import
could not actually be run this session. All new/changed GDScript was reviewed by
hand instead: balanced-bracket check on every touched file, a full read-through
of every new/edited function, and a deliberate cross-check against the
already-shipped, CI-green `StashTransfer`/`TradeSync`/`PartyStashOverlay`/
`LeaderboardOverlay` patterns this task mirrors line-for-line (including the
CLAUDE.md `:=` Variant-inference pitfall — no indexed/`max`/`min`/`clamp` RHS
was ever assigned via `:=`). Flagged in `goal.md`'s last acceptance-criteria
line; recommend an actual `godot --headless` run in a follow-up session (or CI)
before fully trusting this box.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` — new "Auction house" subsection (storage
  shape, id scheme, record-only-bid rationale, `AuctionTransfer`/`AuctionSync`
  API, RPCs, authority flow, the expiry-sweep hook + its `days_elapsed`
  limitation, late-join, HUD) inserted between "Party stash" and "Shared party
  bounties"; added `test_auction_sync.gd`/`test_auction_transfer.gd` rows and
  updated the `test_session_state.gd` row's case count/coverage description in
  the Tests table.
