# TID-432: Enforce Unique-Card Block in Co-op Trading

**Goal:** GID-115
**Type:** agent
**Status:** done
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

1. Add `TradeSync.is_card_instance_unique(card_inst: Dictionary) -> bool` — a pure,
   scene-free helper resolving `template_id -> CardRegistry.get_template().is_unique`,
   mirroring `StashTransfer`/`AuctionTransfer`. Shared by all three call sites and unit
   testable without a scene.
2. `_open_trade_offer` (client-side): scan the deck for the first non-unique card
   instead of blindly taking `deck[0]`; if every card is unique (or deck empty of
   tradeable cards), show a tip and refuse to submit an offer.
3. `_on_trade_offer_submitted` (authority-side): once the offered uid is resolved to
   an owned card instance, `valid` is only set true if that instance is not unique —
   a modified client offering a unique card's uid directly is rejected the same way
   an unowned uid already was (cancelled update back to the initiator).
4. `_transfer_card_in_session` (defense in depth): resolve the card instance first
   (without mutating `g_owned`/`g_deck` yet), bail out before any removal if it is
   unique, then perform the move as before.
5. Add `tests/unit/test_trade_sync.gd` covering `is_card_instance_unique` (normal vs.
   unique vs. missing template_id) plus encode/decode roundtrips (previously
   untested).
6. Update `docs/agent/multiplayer-coop.md` "Card trading & gifting" to describe the
   three enforcement layers instead of the previously-false one-line claim.
7. Archive `BID-030` and update `tasks/index.md`.

No scene/UI changes needed — `_show_tip` already existed and is reused for the new
"no tradeable cards" message.

## Changes Made

- `game_logic/net/TradeSync.gd` — added `_CardRegistry` preload and the static
  `is_card_instance_unique()` helper.
- `scenes/world/WorldScene.gd`:
  - `_open_trade_offer` — picks the first non-unique card in the deck; shows
    "No tradeable cards — unique cards can't be traded." if none qualify.
  - `_on_trade_offer_submitted` — `valid` now also requires the resolved card
    instance to be non-unique (authority-side bypass block).
  - `_transfer_card_in_session` — resolves `found_idx`/`card_inst` first, returns
    early on a unique card before any mutation, then removes/transfers as before.
- `tests/unit/test_trade_sync.gd` — new unit test suite (auto-discovered by
  `tests/runner.gd`): `is_card_instance_unique` (normal/unique/missing-template
  cases) + `encode_offer`/`decode_offer`/`encode_update`/`decode_update` roundtrips.
- Archived `tasks/backlog/BID-030--trading-unique-check-not-enforced.md` to
  `tasks/archive/backlog/` and updated `tasks/index.md`.

**Verification note:** No Godot binary is available in this sandbox and the 4.6-stable
release download is blocked by the outbound proxy (403), so `godot --headless
--editor --quit` and the unit test runner could not be executed here. The three edits
were re-read in full post-edit to confirm brace/tab structure and type-correctness by
hand; the new test file follows the exact structure of `test_stash_transfer.gd`
(already passing in CI). Recommend running the headless import + `tests/runner.gd`
in CI or a Godot-enabled environment before merge, per the goal's acceptance
criteria.

## Documentation Updates

- `docs/agent/multiplayer-coop.md` — "Card trading & gifting" now documents the three
  enforcement layers (client-side pick, authority-side reject, defense-in-depth on
  transfer) instead of the previously-inaccurate one-line claim.
