# TID-199: Victory Rewards + Town Gratitude Discount + Defeat Consequence

**Goal:** GID-054
**Type:** agent
**Status:** pending
**Depends On:** TID-197

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Victory payout logic (coins + rare-or-better card), the town gratitude discount system (temporary 20% price reduction), defeat consequences (coin loss + siege end), and GameBus signals for toast notifications.

## Research Notes

- **Victory outcome (all 3 stages won):** Triggered after stage 2 victory in SceneManager._on_battle_won() (line 253–308 of **autoloads/SceneManager.gd**). Add a check after all standard reward logic (around line 302, before `save_manager.clear_pending_battle()` on line 303):
  ```gdscript
  var siege = save_manager.get_active_siege()
  if not siege.is_empty() and siege.get("stage", 0) == 2:
      # This was the final gauntlet stage
      # Dispatch victory rewards before calling end_siege_victory()
      _apply_siege_victory_rewards(siege.get("town", ""))
      save_manager.end_siege_victory()
  ```

- **Siege victory rewards:**
  - **Coins:** Award ~150 coins (tune balance; compare to standard enemy rewards from `EnemyRegistry.get_coin_reward()` line 291 of SceneManager which returns 5–15 coins per enemy for context). Store in a constant `SIEGE_VICTORY_COINS: int = 150` in a helper. Call `save_manager.add_coins(SIEGE_VICTORY_COINS)`.
  - **Card:** Roll a rare-or-better card using **game_logic/CardDropUtil.gd** (cite the `roll_rarity()` and `roll_stats()` methods).
    ```gdscript
    const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
    const CardRegistry = preload("res://autoloads/CardRegistry.gd")
    var rarity: String = CardDropUtil.roll_rarity(3)  # tier 3 = weighted toward rare/epic
    var card_id: String = CardRegistry.get_random_card()  # static method (verify or add if missing)
    var stats: Dictionary = CardDropUtil.roll_stats(card_id, rarity)
    save_manager.add_card_instance(card_id, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)), int(stats.get("cost", -1)))
    ```
    Cite **autoloads/SaveManager.gd** lines 513–530 for the `add_card_instance()` API.
  - **Toast notification:** After adding the card, emit `GameBus.siege_victory` (new signal) so the HUD can show a toast.

- **Town gratitude discount:** Persists for 3 in-game days after a siege victory.
  - **SaveManager fields (added in TID-197):** `town_discounts: Dictionary = {}` — structure: `{ town_name: expiry_day }`. Example: after winning a siege in madrian on day 10, set `town_discounts["madrian"] = 10 + 3 = 13`.
    - Add to SaveManager around line 100, after the siege fields.
    - Add to `_migrate()` with default `{}`.
    - Add method: `apply_town_discount(town: String) -> void` — sets `town_discounts[town] = days_elapsed + 3`, marks dirty.
    - Add method: `is_town_discounted(town: String) -> bool` — returns `town_discounts.get(town, -1) >= days_elapsed`.
    - Add cleanup in `increment_day()` (line 877 of SaveManager.gd): iterate `town_discounts`, remove any with expiry <= days_elapsed.
  - **ShopScene price application:** The shop must know which town it is selling in. On shop open, pass the current map name to ShopScene.
    - **SceneManager._on_shop_requested()** (lines 342–348 of **autoloads/SceneManager.gd**): add `_shop_overlay.town_name = current_map` after instantiation.
    - **ShopScene.gd:** Store `town_name: String = ""`. In `_make_card_row()` (around line 210 where the price is displayed), apply discount:
      ```gdscript
      var card_price: int = CARD_PRICE
      if save_manager.is_town_discounted(town_name):
          card_price = int(card_price * 0.8)  # 20% discount
      ```
      Also apply to `_make_weapon_row()` (around line 198) and `_make_equipment_row()` (around line 164) using the same 0.8 multiplier.
    - Cite **scenes/ui/ShopScene.gd** line 12 for the base CARD_PRICE constant (value: 15). Search for where prices are compared/enforced (disabled-button check when coins < price, e.g., lines 184, 244).

- **Defeat consequence (any stage lost):** Triggered in SceneManager._on_battle_lost() (lines 310–324 of **autoloads/SceneManager.gd**). Add a check after line 316 (`save_manager.clear_pending_battle()`):
  ```gdscript
  var siege = save_manager.get_active_siege()
  if not siege.is_empty():
      # Player lost a gauntlet stage
      var loss_coins: int = int(save_manager.coins * 0.10)  # lose 10% of current coins, floored
      save_manager.add_coins(-loss_coins)
      save_manager.end_siege_defeat()  # clears the siege, updates last_siege_day
      GameBus.siege_defeated.emit(loss_coins)  # signal for toast
      # DO NOT block story progress — siege loss is purely economic
  ```
  - The `add_coins()` method already clamps to 0 (cite in SaveManager if true; search for add_coins implementation).

- **Siege timeout cleanup (day rollover):** Add a check in SaveManager.increment_day() (line 877) after the existing respawn logic:
  ```gdscript
  # Timeout any siege that hasn't been engaged in 1 day
  var siege = get_active_siege()
  if not siege.is_empty():
      var age_days: int = days_elapsed - siege.get("day_started", 0)
      if age_days >= 1:
          end_siege_defeat()  # town held out, siege ends silently (no coin loss here)
  ```
  This ensures that if the player never touches a siege for a full day, it clears itself on the next day rollover.

- **GameBus signals (new):** Add to **autoloads/GameBus.gd**:
  - `signal siege_victory` — emitted after all 3 stages won.
  - `signal siege_defeated(coins_lost: int)` — emitted after any stage lost, with the coin penalty.
  - Update **docs/agent/signals-and-constants.md** signal table with these two entries.

- **Achievement integration:** After a siege victory, the `GameBus.siege_victory` signal can be hooked by existing achievement checking code. Check if **game_logic/AchievementRegistry.gd** or another pattern already listens to similar signals; if not, ensure the signal is emitted so future achievement code can consume it.

- **Tests (headless):**
  - `tests/test_siege_victory.gd` — verify coins + card awarded, `end_siege_victory()` called, discount applied to town for 3 days, `siege_victory` signal emitted. Test discount expiry on day rollover.
  - `tests/test_siege_defeat.gd` — verify ~10% coin loss (floor), `end_siege_defeat()` called, siege cleared, no story flag changes, `siege_defeated` signal emitted.
  - `tests/test_town_discount.gd` — SaveManager: apply discount to a town, verify `is_town_discounted()` true for 3 days, false on day 4. Verify ShopScene applies 0.8 multiplier to card/weapon/armor prices when discounted.
  - `tests/test_siege_timeout.gd` — mock a siege started on day N, call `increment_day()` twice (N+1, N+2), verify siege is cleared on day N+2 (1-day timeout).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
