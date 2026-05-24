# TID-099: Rarity-Weighted Card Drops (Battles & Chests)

**Goal:** GID-028
**Type:** agent
**Status:** done
**Depends On:** TID-097

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

When a card drops (from a battle win or a chest), the system currently just picks a template ID at random from the enemy's `drop_pool` or the full card pool. This task adds a rarity roll to the drop pipeline: first pick a rarity tier based on the source's difficulty, then pick a template from the pool eligible for that rarity, then roll stats within that rarity's range and create a card instance.

## Research Notes

**Drop entry points** (both in `SceneManager.gd`):
- `_on_battle_won()` (line ~234): picks `result.get("card_reward", "")` — a template ID string chosen by `BattleScene`; then calls `save_manager.add_cards_to_deck([reward])`.
- Boss path (line ~252): picks all cards from `result.get("card_rewards", [])`.
- Chest drops originate in `WorldScene` (search for `add_cards_to_deck` in world-related files).

**New helper to create**: `CardDropUtil` (static functions in `game_logic/CardDropUtil.gd`):
- `roll_rarity(source_tier: int) -> String` — returns `"common"/"rare"/"epic"/"legendary"` based on weighted table per tier
- `roll_stats(template_id: String, rarity: String) -> Dictionary` — looks up CardData rarity ranges, returns `{attack, health, cost}` with random values in range; falls back to base stats if range is undefined
- `make_drop(template_id: String, source_tier: int) -> Dictionary` — combines roll_rarity + roll_stats + calls `SaveManager.add_card_instance(...)`; returns the created instance dict

**Rarity weight table by source tier** (suggested starting values — tune as desired):

| Tier | Source | Common% | Rare% | Epic% | Legendary% |
|------|--------|---------|-------|-------|------------|
| 1 | undead_basic / grassland chest | 80 | 18 | 2 | 0 |
| 2 | undead_horde / dungeon chest | 60 | 30 | 9 | 1 |
| 3 | ghoul_pack / dungeon treasure room | 40 | 40 | 17 | 3 |
| 4 | undead_elite / boss | 20 | 40 | 30 | 10 |

**Enemy difficulty tier**: `EnemyRegistry` has `type_for_chunk_dist()` and `type_for_biome()` returning type strings. The mapping to numeric tiers: undead_basic=1, undead_horde=2, ghoul_pack=3, undead_elite=4. Also any enemy with `is_boss=true` should use tier 4.

**`EnemyData`** (`data/EnemyData.gd`): add `@export var difficulty_tier: int = 1` so the tier can be overridden per-enemy without relying on the name mapping. Update existing `.tres` files.

**Template eligibility by rarity**: if a `drop_pool` template has no `legendary_stats` on its CardData, it cannot drop as legendary — the roll should re-draw or fall back to epic. Similarly, if a card has `is_unique = true`, it can only drop once (check SaveManager before awarding).

**BattleScene card_reward selection** (`scenes/battle/BattleScene.gd`): currently picks a random ID from `EnemyRegistry.get_drop_pool(type)`. After this task, BattleScene passes the template ID and the enemy's `difficulty_tier` to `CardDropUtil.make_drop()`. The return value replaces the string reward.

**Chest drops**: find where chests grant cards (search `add_cards_to_deck` or `GameBus.chest_opened` in WorldScene/ChunkRenderer). Chest tier can be read from the chest entity's `c_data` dict (add a `tier: int` field to chest data, defaulting to 1 for world chests, 2 for dungeon chests, 3 for dungeon treasure rooms).

**UID sidecar**: `game_logic/CardDropUtil.gd` is a plain `.gd` script — no `.uid` sidecar needed.

## Plan

1. Create `game_logic/CardDropUtil.gd` with `roll_rarity()`, `effective_rarity()`, and `roll_stats()` static helpers.
2. Add `difficulty_tier: int` to `data/EnemyData.gd` and set values on the four existing enemy `.tres` files.
3. Add `get_difficulty_tier()` to `EnemyRegistry.gd`.
4. Wire rarity rolls into `SceneManager._on_battle_won()` for both single and boss drops.
5. Wire rarity rolls into `WorldScene._spawn_card_items()` for chest drops, detecting tier from chest ID prefix.
6. Update `WorldItem.gd` to accept and store rarity + rolled stats, pass them to `add_card_instance()` on collect.

## Changes Made

- **`game_logic/CardDropUtil.gd`** (new): `TIER_WEIGHTS` table, `roll_rarity(tier)`, `effective_rarity(template_id, rolled)`, `roll_stats(template_id, rarity)` — global per-rarity multiplier/variance from `IsoConst.RARITY_CONFIG`, no per-card ranges.
- **`data/EnemyData.gd`**: added `@export var difficulty_tier: int = 1`.
- **`autoloads/EnemyRegistry.gd`**: added `get_difficulty_tier(type_id)` static method.
- **`data/enemies/undead_basic.tres`**: `difficulty_tier = 1`
- **`data/enemies/undead_horde.tres`**: `difficulty_tier = 2`
- **`data/enemies/ghoul_pack.tres`**: `difficulty_tier = 3`
- **`data/enemies/undead_elite.tres`**: `difficulty_tier = 4`
- **`autoloads/SceneManager.gd`**: `_on_battle_won()` now reads `enemy_type` / `is_boss`, computes `drop_tier`, rolls rarity via `CardDropUtil.roll_rarity(drop_tier)`, then calls `add_card_instance()` with rarity + rolled stats instead of `add_cards_to_deck()`.
- **`scenes/world/WorldScene.gd`**: `_spawn_card_items()` now detects chest tier from chest ID prefix (`dtr_`=3, `dc_`=2, else 1), rolls rarity, rolls stats, passes them to `WorldItem.setup()`.
- **`scenes/world/entities/WorldItem.gd`**: `setup()` now accepts `p_rarity`, `p_attack`, `p_health`, `p_cost`; stores them; `_collect()` passes them to `add_card_instance()`; `_get_glow_color()` updated with epic (purple) colour.

## Documentation Updates

No new agent docs required — behavior is an extension of the card-instances system documented in TID-098.
