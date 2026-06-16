# TID-199: Victory Rewards + Town Gratitude Discount + Defeat Consequence

**Goal:** GID-054
**Type:** agent
**Status:** done
**Depends On:** TID-197

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Victory payout logic (coins + rare-or-better card), the town gratitude discount system (temporary 20% price reduction), defeat consequences (coin loss + siege end), and GameBus signals for toast notifications.

## Research Notes

- **Victory outcome (all 3 stages won):** Triggered after stage 2 victory in SceneManager._on_battle_won(). After advancing siege stage and detecting stage 2 completion, `_apply_siege_victory_rewards(town)` is called, then `save_manager.end_siege_victory()`.

- **Siege victory rewards:**
  - **Coins:** 150 coins (`SIEGE_VICTORY_COINS = 150`). `save_manager.add_coins(150)`.
  - **Card:** Random card from `CardRegistry.get_all_ids()` at `roll_rarity(3)` (rare-or-better). Uses existing `save_manager.add_card_instance()` API.
  - **Toast notification:** `show_toast("Siege Defeated!", "… +150 coins + rare card")` + emit `GameBus.siege_victory`.

- **Town gratitude discount:** Persists for 3 in-game days after a siege victory.
  - `apply_town_discount(town)` sets `town_discounts[town] = days_elapsed + 3`.
  - `is_town_discounted(town)` returns `town_discounts.get(town, -1) >= days_elapsed`.
  - `increment_day()` removes expired entries from `town_discounts`.
  - ShopScene reads `is_town_discounted(town_name)` and applies 0.8× to all card/weapon/equipment prices; section headers note "(20% off — Town Discount)".

- **Defeat consequence (any stage lost):** 10% coin loss (floored via `int(coins * 0.10)`), `end_siege_defeat()`, `GameBus.siege_defeated.emit(coins_lost)`. Story progress never blocked.

- **Siege timeout cleanup (day rollover):** `increment_day()` checks active siege age; if age >= 1 day, calls `end_siege_defeat()` silently (no coin loss for timeout).

- **GameBus signals (new):**
  - `signal siege_victory`
  - `signal siege_defeated(coins_lost: int)`

- **Tests (headless):**
  - `tests/unit/test_town_discount.gd` — apply discount, verify is_town_discounted, expiry day boundary.
  - `tests/unit/test_siege_timeout.gd` — timeout via increment_day.
  - `tests/unit/test_siege_defeat.gd` — 10% coin loss math, defeat clears siege, no story flags set.

## Plan

1. Add `town_discounts` to SaveManager alongside siege fields (v31 migration).
2. Add `apply_town_discount`, `is_town_discounted` methods.
3. Add discount cleanup in `increment_day()`.
4. Implement `_apply_siege_victory_rewards(town)` in SceneManager.
5. Add defeat consequence in `_on_battle_lost()`.
6. Add `town_name` pass-through in `_on_shop_requested()`.
7. Update ShopScene `_refresh()` with discount multiplier.
8. Add new signals to GameBus.
9. Write test_town_discount.gd, test_siege_timeout.gd, test_siege_defeat.gd.

## Changes Made

- `autoloads/SaveManager.gd` — added `town_discounts: Dictionary = {}` field (initialized in `new_game`, loaded/saved, migrated in v30→v31); added `apply_town_discount(town)`, `is_town_discounted(town) -> bool`; `increment_day()` removes expired entries and times out stale sieges.
- `autoloads/GameBus.gd` — added `signal siege_victory` and `signal siege_defeated(coins_lost: int)`.
- `autoloads/SceneManager.gd` — `_apply_siege_victory_rewards(town)` awards 150 coins + rare-or-better card, shows toast, emits `GameBus.siege_victory`; defeat consequence in `_on_battle_lost()` subtracts 10% coins, calls `end_siege_defeat()`, emits `GameBus.siege_defeated`; `_on_shop_requested()` sets `_shop_overlay.town_name = current_map`.
- `scenes/ui/ShopScene.gd` — added `var town_name: String = ""`; `_refresh()` computes discount and applies 0.8× multiplier to all prices; section headers show "(20% off — Town Discount)" when discounted.
- Created `tests/unit/test_town_discount.gd` + `.uid`.
- Created `tests/unit/test_siege_timeout.gd` + `.uid`.
- Created `tests/unit/test_siege_defeat.gd` + `.uid`.

## Documentation Updates

- `docs/agent/town-siege.md` — Victory Rewards, Town Gratitude Discount, and Defeat sections document reward amounts, discount duration, coin loss formula, and signal names.
- Updated `docs/agent/signals-and-constants.md` indirectly via town-siege.md integration table.
