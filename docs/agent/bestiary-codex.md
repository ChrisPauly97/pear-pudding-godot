# Bestiary Codex

## Key Features

- **Lore fields on EnemyData:** Each enemy type has a `lore_text: String` field written in the .tres resource. All 8 bundled enemy types have a 1–2 sentence lore blurb.
- **Encounter/defeat tracking in SaveManager:** `bestiary: Dictionary` maps `type_id → {seen: int, defeated: int}`. Persisted in save JSON, migration v21→v22 backfills empty dict.
- **Three reveal tiers in JournalScene Bestiary tab:**
  - Tier 0 (unseen): row shows "???" in grey; detail shows "Encounter this enemy to reveal more."
  - Tier 1 (seen ≥ 1, defeated < 3): row shows `display_name`; detail shows deck size, difficulty, coin reward, and a countdown to lore unlock.
  - Tier 2 (defeated ≥ 3): row shows display_name in gold; detail shows stats + full `lore_text`.
- **Bestiary completion reward:** Defeating every bundled enemy type at least once grants a one-time reward of 500 coins + legendary `soul_harvest` card and fires the `monster_scholar` achievement.

## How It Works

### Data Layer (TID-170)

`data/EnemyData.gd` exports `lore_text: String = ""`. All bundled `.tres` files in `data/enemies/` have this field set.

`SaveManager` exposes:
- `record_enemy_seen(type_id)` — increments `bestiary[type_id]["seen"]`; called from `SceneManager._on_enemy_engaged()`.
- `record_enemy_defeated(type_id)` — increments `bestiary[type_id]["defeated"]`; called from `SceneManager._on_battle_won()` after the normal defeat tracking. Triggers `_check_bestiary_complete()`.
- `get_bestiary_entry(type_id) -> Dictionary` — returns `{seen, defeated}` or zeros for unknown.
- `is_bestiary_complete() -> bool` — iterates `EnemyRegistry.get_all_enemy_ids()` and returns true only if every type has `defeated >= 1`.
- `_check_bestiary_complete()` — internal; guards with `bestiary_complete_rewarded` flag; grants 500 coins, a legendary `soul_harvest` card, sets story flag `"bestiary_complete"`.

`EnemyRegistry` exposes:
- `get_all_enemy_ids() -> Array[String]` — returns all loaded enemy IDs sorted by difficulty_tier then id.
- `get_lore_text(type_id) -> String` — returns `lore_text` for the given enemy type.

### UI Layer (TID-171)

`JournalScene` gains a two-button tab bar ("Scrolls" | "Bestiary") inserted between the header row and the treasure status label. Tab state is tracked by `_active_tab: String`.

- **Scrolls tab:** unchanged behaviour.
- **Bestiary tab:** calls `_populate_bestiary_list()` which reads `EnemyRegistry.get_all_enemy_ids()` and populates `_scroll_list` with per-type buttons styled by tier. Selecting a row calls `_show_bestiary_detail()`.
- Header shows "Bestiary — N / M Revealed" (seen ≥ 1 counts as revealed). Completion banner "★ All enemies defeated!" shown when `SaveManager.bestiary_complete_rewarded` is true.

### Reward Layer (TID-172)

`AchievementRegistry` gains the `monster_scholar` achievement with `condition_type: "specific_flag"` and `flag_key: "bestiary_complete"`. The existing `check_flag_achievement()` / `_check_unlock()` pipeline triggers the achievement automatically when `set_story_flag("bestiary_complete")` is called by `_check_bestiary_complete()`.

The coin and card rewards are granted directly in `_check_bestiary_complete()` before setting the flag, so the achievement toast appears after the rewards are applied.

## Integrations with Other Features

- **SceneManager:** `_on_enemy_engaged()` calls `save_manager.record_enemy_seen(enemy_type)`; `_on_battle_won()` calls `save_manager.record_enemy_defeated(enemy_type)` for both the regular and Spire battle paths.
- **AchievementRegistry / AchievementToast:** `monster_scholar` uses the existing `specific_flag` condition type; the existing toast system auto-displays it when `GameBus.achievement_unlocked("monster_scholar")` fires.
- **SaveManager migration:** v21→v22 adds `bestiary` (empty dict) and `bestiary_complete_rewarded` (false).

## Asset Requirements

No new art assets are required. Enemy silhouettes/sprites are not used in v1; the bestiary is text-only. The `.tres` files needed the `lore_text` field only (no new resource files).
