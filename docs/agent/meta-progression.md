# Meta-Progression: Achievements, Legendary Cards & Run Summary

## Key Features

- **Achievement system**: 10 milestone achievements tracked in SaveManager, emitting `GameBus.achievement_unlocked` on completion
- **Toast notifications**: Slide-in panel (CanvasLayer layer 200) shows achievement name and description for 3 seconds
- **Achievement list screen**: Accessible from main menu; shows all achievements with progress bars and lock icons
- **Legendary cards**: 5 exclusive cards (ancient_guardian, soul_harvest, time_warp, phoenix_rise, void_wyrm) gated behind specific achievements; auto-granted to owned_cards on achievement unlock; never appear in shop until unlocked. The `duel_crown` legendary is awarded directly on first champion duel win (not via achievement card reward)
- **Run summary screen**: Shows session stats (battles, enemies, cards, coins, chests, time) when player returns to menu from the world

## How It Works

### Achievement Registry (`game_logic/AchievementRegistry.gd`)

Static registry defining all 10 achievements as plain Dictionaries with fields:
- `id`, `name`, `description`, `condition_type`, `target_value`, `reward_card_id`
- `flag_key` (only for `specific_flag` type achievements)

`condition_type` values: `battles_won`, `enemies_defeated`, `cards_earned`, `biomes_visited`, `chests_opened`, `specific_flag`, `dawn_battle_won`, `dusk_battle_won`

### SaveManager fields (v8 save format)

| Field | Type | Description |
|---|---|---|
| `achievement_progress` | Dictionary | achievement_id → int count |
| `unlocked_achievements` | Array[String] | IDs of completed achievements |
| `visited_biomes` | Array[int] | biome IDs seen (for biomes_visited achievement) |

### Key SaveManager methods

- `increment_progress(condition_type, amount)` — increments matching achievements, calls `_check_unlock`
- `check_flag_achievement(flag)` — called from `set_story_flag` when a story flag is set true
- `check_deck_achievements(deck)` — checks dawn_battle_won / dusk_battle_won on battle win
- `visit_biome(biome_id)` — tracks unique biomes visited
- `grant_achievement_card(card_id)` — adds legendary to owned_cards without triggering cards_earned counter

### Hook locations

| Event | Hook |
|---|---|
| Battle won | `SceneManager._on_battle_won` → increment battles_won, enemies_defeated; check_deck_achievements |
| Battle lost | `SceneManager._on_battle_lost` → session_stats only |
| Chest opened | `SaveManager.mark_chest_opened` → increment chests_opened |
| Cards earned | `SaveManager.add_cards_to_deck` → increment cards_earned |
| Story flag set | `SaveManager.set_story_flag` → check_flag_achievement |
| Biome entered | `WorldScene._process` biome change → visit_biome |

### Achievement Unlock Flow

1. Hook increments progress via `increment_progress`
2. `_check_unlock` compares progress to target; if met, appends to `unlocked_achievements` and emits `GameBus.achievement_unlocked`
3. `SceneManager._on_achievement_unlocked` calls `grant_achievement_card` if reward exists
4. `AchievementToast` (child of SceneManager) receives signal and queues slide-in notification

### Session Stats (ephemeral, SceneManager)

`SceneManager.session_stats` Dictionary resets on new game / continue. Fields: `battles_won`, `battles_lost`, `enemies_defeated`, `cards_earned`, `coins_earned`, `chests_opened`, `session_start_msec`. Not persisted to save file.

### Run Summary Flow

When `SceneManager.go_to_menu()` is called from world state, it routes to `RunSummaryScene` instead of `MenuScene` directly. `RunSummaryScene` reads `SceneManager.session_stats`, computes elapsed time, and its "Return to Menu" button calls `SceneManager.go_to_menu_direct()`.

## Integrations with Other Features

- **SaveManager**: achievement data added to save v8; migration backfills empty defaults for old saves
- **CardRegistry**: `is_unlocked(card_id, unlocked_achievements)` gates legendary cards in shop
- **ShopScene**: filters out locked legendaries before building the card list
- **MenuScene**: "Achievements" button routes to `AchievementsScene` overlay via `SceneManager.go_to_achievements()`
- **BattleScene**: deck-composition achievements checked via `check_deck_achievements` on win
- **WorldScene**: biome tracking and chest open tracking

## Asset Requirements

- 5 legendary card `.tres` files in `data/cards/` with `.uid` sidecars
- `scenes/ui/AchievementToast.gd` — code-only CanvasLayer, no .tscn needed
- `scenes/ui/AchievementsScene.tscn` — minimal wrapper referencing the .gd
- `scenes/ui/RunSummaryScene.tscn` — minimal wrapper referencing the .gd
