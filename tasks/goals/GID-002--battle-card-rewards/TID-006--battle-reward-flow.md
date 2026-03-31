# TID-006: Implement Post-Battle Reward Flow + BattleScene Reward UI

**Goal:** GID-002
**Type:** agent
**Status:** done
**Depends On:** TID-005

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With `EnemyData.drop_pool` available, this task adds the logic to pick a reward card, grant it, and show the player a brief reward overlay before the world restores. The reward must be communicated via `GameBus.battle_won` so `SceneManager` can persist it without BattleScene directly touching SaveManager.

## Research Notes

**Where battle win is declared** (`game_logic/battle/GameState.gd`):
- `battle_ended(winner)` signal is emitted when a hero hits 0 HP.
- `BattleScene.gd` listens to `GameBus.battle_ended`; when winner == 0 it eventually calls `GameBus.battle_won.emit(result)`.
- Check exact flow in `BattleScene.gd` — find where `battle_won` is emitted and what goes into `result`.

**Reward card selection:**
```gdscript
# In BattleScene, when winner == 0 (player wins):
var enemy_type: String = enemy_data.get("type", "undead_basic")
var enemy_res: EnemyData = EnemyRegistry.get_enemy(enemy_type)  # or get_drop_pool()
var pool: PackedStringArray = enemy_res.drop_pool if enemy_res else PackedStringArray()
var reward_card_id: String = ""
if pool.size() > 0:
    reward_card_id = pool[randi() % pool.size()]
```

**GameBus.battle_won result dict:**
- Currently emitted as `{ }` or with a minimal result. Extend to include `"card_reward": reward_card_id`.
- `SceneManager._on_battle_won(result)` reads `result` — add:
  ```gdscript
  var reward: String = str(result.get("card_reward", ""))
  if reward != "":
      save_manager.add_cards_to_deck([reward])  # or add_card_to_collection()
  ```
  Note: `add_cards_to_deck` appends to `owned_cards` (check the method signature; it may be `add_cards_to_deck(Array[String])` — wrap in array).

**Reward overlay in BattleScene:**
- After computing the reward, instead of immediately emitting `battle_won`, show a `PanelContainer` overlay with:
  - "Victory!" label
  - "You earned: [CardData.display_name]" label (use `CardRegistry.get_card(reward_card_id).display_name`)
  - "Collect" button
- On button press → emit `GameBus.battle_won.emit({ "card_reward": reward_card_id })`
- If `drop_pool` is empty, show "Victory!" with "Continue" and emit with empty reward.
- Size all UI elements relative to viewport height (CLAUDE.md requirement).

**Key files:**
- `scenes/battle/BattleScene.gd` — main changes here
- `autoloads/SceneManager.gd` — `_on_battle_won` to persist the reward
- `autoloads/GameBus.gd` — no change needed (result dict is already `Dictionary`)
- `autoloads/CardRegistry.gd` — `get_card(id)` for display name lookup
- `autoloads/EnemyRegistry.gd` — verify `get_enemy(type_id)` exists

## Plan

1. Preload `EnemyRegistry` in `BattleScene.gd`.
2. Replace the immediate `battle_won` emit in `_check_game_over()` with a call to `_show_victory_overlay(reward_card_id)`.
3. `_show_victory_overlay()` builds a full-screen overlay with a Victory label, earned-card label, and a Collect/Continue button. On press it emits `GameBus.battle_won` with `{ "card_reward": reward_card_id }`.
4. In `SceneManager._on_battle_won()`, read `result["card_reward"]` and call `save_manager.add_cards_to_deck([reward])` when non-empty.

## Changes Made

- `scenes/battle/BattleScene.gd`:
  - Added `const EnemyRegistry` preload.
  - `_check_game_over()`: computes `reward_card_id` from `EnemyRegistry.get_drop_pool(enemy_type)` and calls `_show_victory_overlay()` instead of emitting immediately.
  - New `_show_victory_overlay(reward_card_id)`: full-screen `PanelContainer` overlay with Victory label, card-name label (from `CardRegistry.get_template()`), and Collect/Continue button that emits `GameBus.battle_won`.
- `autoloads/SceneManager.gd`:
  - `_on_battle_won(result)`: reads `result.get("card_reward", "")` and calls `save_manager.add_cards_to_deck([reward])` if non-empty.

## Documentation Updates

Updated `docs/agent/inventory-and-deck.md` Battle Card Drops section.
Updated `docs/agent/battle-system.md` (see below).
