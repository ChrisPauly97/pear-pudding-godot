# TID-432: Enforce Unique-Card Block in Co-op Trading

**Goal:** GID-115
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Promotes **BID-030**. `docs/agent/multiplayer-coop.md` ("Card trading & gifting") and
the TID-366 task notes state that unique cards (`is_unique = true`) are blocked from
trading, same as crafting/selling — but no code in the trade chain checks it. A player
can irreversibly trade away a unique/signature story card in co-op. Verified still
live at HEAD: `is_unique` appears nowhere in `scenes/world/WorldScene.gd`.

## Research Notes

- **The trade chain (all in `scenes/world/WorldScene.gd`):**
  - `_open_trade_offer` (line 7028) — picks the card to offer (`deck[0]` per BID-030)
    and submits unconditionally; local short-circuit to `_on_trade_offer_submitted`
    at line 7052.
  - `_on_trade_offer_submitted(sender, payload)` (line 7058) — authority-side
    validation; currently only checks the giver still owns the uid.
  - `_transfer_card_in_session(st, giver_token, target_token, card_uid)` (line 7131)
    — performs the move with no `is_unique` check.
- **The proven pattern to copy:** `game_logic/net/StashTransfer.gd::deposit_card`
  (GID-102 / TID-376) already does this exact check correctly:
  `CardRegistry.get_template(template_id).get("is_unique", false)`. Note the card
  *instance* dict has no `is_unique` field — only the template does, so the template
  lookup is mandatory.
- **Fix in three layers, mirroring StashTransfer:**
  1. `_open_trade_offer` (client-side): skip/refuse unique cards when picking the
     offer card, with a toast (`GameBus.hud_message_requested`) if the only candidate
     is unique.
  2. `_on_trade_offer_submitted` (authority-side): reject payloads whose uid resolves
     to a unique template — a modified client must not bypass the block.
  3. `_transfer_card_in_session` (defense in depth): same check before the move.
- `Object.get()` takes ONE argument in Godot 4.6 — the `.get("is_unique", false)`
  pattern above is on a **Dictionary** returned by `CardRegistry.get_template()`;
  don't accidentally call the 2-arg form on a Resource (see CLAUDE.md / BID-023).
- Resolving the uid → template id: follow whatever `_transfer_card_in_session` /
  `StashTransfer.deposit_card` do today to look up the instance's `template_id` from
  the giver's owned-cards store (`SessionStore` / save data).
- Tests: `StashTransfer` has unit coverage from TID-376 (grep `tests/` for
  `stash`). Add an equivalent unit test for the trade path — if the check is
  extracted into a small pure helper (e.g. on `StashTransfer` or a shared
  `TradeRules.gd`), both stash and trade can share it and the test is trivial.
- Update `docs/agent/multiplayer-coop.md` "Card trading & gifting" — it currently
  claims the block exists; after this task the claim becomes true (note the fix).
- After the fix, move `tasks/backlog/BID-030--trading-unique-check-not-enforced.md`
  to `tasks/archive/backlog/` and update `tasks/index.md`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
