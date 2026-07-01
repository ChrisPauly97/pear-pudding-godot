# BID-030: Card trading never actually enforces the unique-card block

**Type:** bug (logic gap)
**Discovered during:** GID-102 / TID-376 (Shared party stash)
**Severity:** medium

## Context

`docs/agent/multiplayer-coop.md` ("Card trading & gifting") and the original TID-366 task
notes both state that unique cards (`is_unique = true`) are "blocked from trading, same as
crafting/selling" — but the actual code never checks it. `WorldScene._open_trade_offer`
picks `deck[0]` and offers it unconditionally; `_on_trade_offer_submitted` only validates
that the giver still owns the uid (`owned`.has the uid); `_transfer_card_in_session`
(`scenes/world/WorldScene.gd`) performs the move with **no `is_unique` check anywhere** in
the chain. So a unique/signature card can currently be traded away in co-op despite the
documented and intended invariant.

## Evidence

- `scenes/world/WorldScene.gd` — `_open_trade_offer`, `_on_trade_offer_submitted`,
  `_transfer_card_in_session`: none reference `is_unique` or `CardRegistry.get_template`.
- `docs/agent/multiplayer-coop.md` → "Card trading & gifting": "Unique cards (`is_unique =
  true`) are blocked from trading." — currently false.
- Contrast with the new party stash feature (GID-102 / TID-376,
  `game_logic/net/StashTransfer.gd::deposit_card`), which *does* correctly check
  `CardRegistry.get_template(template_id).get("is_unique", false)` before allowing a
  card into the shared stash — proving the check is easy to add and the instance-dict
  shape (no `is_unique` field on the instance itself, only on the template) is already
  understood.

## Suggested Resolution

Add the same template-lookup unique check to `_open_trade_offer` (client-side, so the
initiator can't even pick a unique card to offer) and defensively to
`_transfer_card_in_session` / `_on_trade_offer_submitted` (server-side, so a modified
client can't bypass the block) — mirroring `StashTransfer.deposit_card`'s
`CardRegistry.get_template(template_id).get("is_unique", false)` check exactly.

## Note on ID numbering

Originally filed as BID-025 from an isolated worktree (branched before BID-025 was claimed
elsewhere for an unrelated finding); renumbered to BID-030 during integration.
