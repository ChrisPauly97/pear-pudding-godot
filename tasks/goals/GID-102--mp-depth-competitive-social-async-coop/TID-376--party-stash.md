# TID-376: Shared party stash (deposit/withdraw)

**Goal:** GID-102
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Card trading is **peer-to-peer** (GID-101 / TID-366) and requires both players present. A
**shared party stash** is a session-owned chest any member can deposit cards/coins into and
withdraw from — a persistent communal pool that smooths gearing the whole party. It also
provides the transfer plumbing the auction house (TID-378) reuses.

## Research Notes

- **Storage — `game_logic/net/SessionState.gd`.** Add a shared `stash: Dictionary`
  (authority-owned, persisted) shaped `{cards: Array, coins: int}` where `cards` are full card
  *instances* (same shape as a member's `owned_cards`, built via
  `game_logic/CardInstanceUtil.gd`). Bump `CURRENT_SESSION_VERSION` (coordinate with TID-370 —
  if TID-370 went to v4, this is v5) with a migration adding `stash = {cards: [], coins: 0}`.
  Add to `to_dict`/`from_dict` (lines 63–101).
- **Transfer plumbing — reuse TID-366.** The dupe-proof card move already exists:
  `_transfer_card_in_session` (removes the instance from giver's `owned_cards`/`player_deck`,
  re-keys the UID into the receiver's namespace, adds to receiver's `owned_cards` — see
  `multiplayer-coop.md` → "Card trading & gifting"). Generalise it (or add a sibling) to move
  an instance **member ⇄ stash**: deposit re-keys into a `stash`-namespaced UID; withdraw
  re-keys into the withdrawing member's namespace. Coins are a simple int move
  (`SessionStore` member coins ⇄ `stash.coins`). **Unique cards** (`is_unique`) are blocked
  from the stash, same as trading.
- **RPCs — `scenes/world/NetSync.gd`.** Mirror the trade flow (proximity not required — the
  stash is global to the session):
  - `submit_stash_deposit(payload)` / `submit_stash_withdraw(payload)` (client → authority,
    reliable). Authority validates ownership (deposit: giver still owns it; withdraw: stash
    has it), executes the move, persists via `SessionStore.mark_dirty`, then broadcasts.
  - `recv_stash_update(snapshot)` (authority → all, reliable) — current stash contents, so all
    members' panels stay in sync. Late-join: include the stash in the existing character/world
    snapshot fan-out (`_send_character_to_peer`).
- **HUD panel.** A stash overlay (BaseOverlay pattern) reachable from the world HUD: two
  columns (my deck/collection ↔ stash) with deposit/withdraw buttons + a coins row. Reuse the
  deck-builder card-list widgets if cheap. Viewport-relative, mobile parity.
- **Authority-only writes.** Clients never mutate `SessionState`; only the authority does
  (isolation invariant — all persistence via `SessionStore`, never `save_slot_*.json`).
- **Tests:** extend `tests/unit/test_session_state.gd` (stash field default, round-trip,
  migration, unique-card block); a deposit/withdraw round-trip on the transfer helper. A
  loopback smoke (`net_stash_smoke.gd`) optional, mirroring `net_session_smoke.gd`.
- **Docs:** update `docs/agent/multiplayer-coop.md` (new "Party stash" subsection + RPC table
  + Tests table).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
