# GID-110: Mailbox — Overflow Storage for Bag-Full Card Rewards

## Objective

When a card reward can't fit in the player's bag, route it to a persistent Mailbox instead of discarding it; the Mailbox is a physical interactable placed in madrian, maykalene, blancogov, and the player's home (once purchased).

## Context

Confirmed during ad-hoc bug fixing (2026-07-04, pre-dates this goal) that `SaveManager.add_card_instance()` returns `""` and silently drops the card whenever `is_bag_full()` is true. Every automatic reward grant is vulnerable to silent loss: battle wins, chest/dig/burial-mound/world-item loot, landmark discovery, achievements, pack opening, and story/quest rewards.

This is distinct from the existing co-op **Stash** (`game_logic/net/StashTransfer.gd` + `SessionState`, a shared party storage that only exists inside multiplayer sessions). The Mailbox is a **single-player** feature, persisted in `SaveManager`, and exists purely to catch overflow that would otherwise vanish. Do not conflate the two systems or reuse `StashTransfer`'s session-scoped re-keying — the Mailbox has no re-keying/ownership-transfer concept, it's just an overflow queue for the local player.

The closest existing precedent for "world entity opens a UI overlay" is `BountyBoardNPC.gd` (an NPC-type entity → `GameBus` signal → `SceneManager._open_overlay()`), not the Waystone system. Waystones are the precedent for *placing the same entity across multiple named maps*, including a home-purchase-gated case (see `docs/agent/waystone-fast-travel.md`).

Scope boundary (researched call sites of `add_card_instance`, 2026-07-04):
- **Route through Mailbox** (automatic/passive grants): `BattleScene._apply_coop_pve_rewards`, `WorldScene._discover_landmark`, `PackOpenScene`, `DigSpot`, `BurialMound`, `WorldItem`, `SaveManager.grant_achievement_card`/`add_cards_to_deck`/`_check_bestiary_complete`, and the ~7 reward call sites in `SceneManager.gd` (story/quest/duel rewards).
- **Leave blocking as-is** (player-initiated spends where a "bag full" message is the right UX): `ShopScene` purchases, `InventoryScene` crafting, `SaveManager.combine_cards` (nets −2 slots per combine, so the full-bag path is effectively unreachable there anyway — do not migrate it).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-411 | Mailbox persistence & reward routing in SaveManager | agent | done | — |
| TID-412 | Mailbox world entity + interaction wiring across maps | agent | done | TID-411 |
| TID-413 | Mailbox overlay UI (claim/sell/scrap) | agent | pending | TID-412 |

## Acceptance Criteria

- [ ] A card reward that can't fit in the bag is stored in `SaveManager.mailbox_cards` instead of being discarded, and this persists across save/load (with migration default for old saves).
- [ ] All in-scope automatic-reward call sites use the new routing function instead of the old drop-on-full behavior; out-of-scope call sites (shop, craft, combine) are unchanged.
- [ ] A "Mailbox" interactable NPC-type entity exists and can be interacted with on madrian, maykalene, and blancogov.
- [ ] The Mailbox also appears inside the player's home interior map once `SaveManager.home_owned` is true (guarded at map-load time — home purchase always happens at the door before the interior map loads, so no dynamic mid-session re-spawn hook is needed; confirmed via `WorldScene._show_house_door_panel`).
- [ ] Interacting with the Mailbox opens an overlay listing every held card (cube-tile grid, consistent with the current `InventoryScene` backpack presentation) with working Claim, Claim All, Sell, and Scrap actions.
- [ ] A toast/HUD message notifies the player when a reward is routed to the Mailbox during play.
- [ ] `godot --headless --editor --quit` reports no new parse/compile errors.
- [ ] Unit tests cover the mailbox grant/claim logic (mirroring `tests/unit/test_bag_slots.gd`).
