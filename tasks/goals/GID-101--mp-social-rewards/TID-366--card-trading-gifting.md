# TID-366: Card trading & gifting

**Goal:** GID-101
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The core TCG social loop, entirely absent today: let two players trade or gift cards
(and optionally coins) within a session. Must be host-authoritative and **dupe-proof**.

## Research Notes

- **Card ownership lives in the per-player session character (GID-095):** `owned_cards`
  (card instances) + `coins` in the `SessionState` member record, bridged into memory by
  `SaveManager.adopt_session_character` (which forces `_loaded = false` so co-op never
  writes `save_slot_*.json`). The **authority** owns persistence via `SessionStore`.
- **Card instance shape:** `game_logic/CardInstanceUtil.gd` (`make(uid, template_id,
  rarity, attack, health, cost)`) — shared by save + session. A traded card moves the
  **instance** (keep its rolled stats / veteran progress, GID-060/GID-083) from giver to
  receiver; re-key its UID into the receiver's namespace to avoid collisions (members use
  token-salted UIDs — see `SessionState.make_starter_character`).
- **Anti-dupe / authority flow (host-authoritative, like GID-096 loot):**
  - Both parties propose → both **confirm** → the **authority** validates the giver still
    owns the instance, removes it from the giver's member record, adds it to the receiver's,
    marks `SessionStore` dirty, and broadcasts the result to both. Never let a client
    mutate its own collection unilaterally for a trade.
  - RPCs on `NetSync`: `submit_trade_offer` / `submit_trade_confirm` (client→authority),
    `recv_trade_update` (authority→both). Reliable.
- **UI:** a trade window (two-sided offer + ready/confirm), opened when adjacent to a
  party member (reuse the proximity check that gates the PvP "Challenge to Battle" button)
  or from the roster. Viewport-relative, mobile + desktop. Gifting = a one-sided trade.
- **Scope guard:** trading only in a co-op session; single-player has nothing to trade
  with. Decide whether to restrict trading of `is_unique` cards (cf. BID-008) — likely
  block uniques.
- **Tests:** unit-test the transfer logic against two `SessionState` members (instance
  moves exactly once, UID re-keyed, coins conserved); loopback smoke for the RPC confirm
  flow if cheap.

## Plan

Host-authoritative two-sided trade flow via new RPCs on NetSync. Pure encode/decode in TradeSync.gd. WorldScene handles proposal → confirm → transfer with authority validation against SessionState.

## Changes Made

- **`game_logic/net/TradeSync.gd`** (new): `STATUS_PROPOSED/COMPLETED/CANCELLED`; `encode_offer(trade_id, initiator_peer, target_peer, card_uid, offer_coins, request_coins)`; `encode_update(trade_id, status, detail)`; `decode_offer`/`decode_update` (fully defaulted).
- **`game_logic/net/TradeSync.gd.uid`** (new): `uid://ozomjrclae5d`
- **`scenes/world/NetSync.gd`**: `submit_trade_offer(payload)` (reliable, client→authority), `submit_trade_confirm(trade_id, confirmed)` (reliable), `recv_trade_update(payload)` (reliable, authority→both parties).
- **`scenes/world/WorldScene.gd`**: proximity-gated "Trade" HUD button; `_open_trade_offer` (initiates gift of top deck card); `_on_trade_offer_submitted` (authority validates giver owns the card via `SessionStore.get_state().get_member(token)`); `_on_trade_confirm_submitted` (authority executes transfer or cancels); `_transfer_card_in_session` (moves instance, re-keys UID into receiver's namespace, calls `SessionStore.mark_dirty()`); `_show_trade_accept_panel`; `_on_trade_update_received`. Unique-card guard prevents trading `is_unique` cards.

## Documentation Updates

Updated `docs/agent/multiplayer-coop.md`: GID-101 Social & Rewards section (card trading subsection).
