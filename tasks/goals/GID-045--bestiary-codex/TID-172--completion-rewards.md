# TID-172: Completion Rewards + Achievement Hookup

**Goal:** GID-045
**Type:** agent
**Status:** pending
**Depends On:** TID-171

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The reward layer. When the player defeats every bundled enemy type at least once, grant a one-time coin bonus + a rare card, emit an achievement, and show an achievement toast.

## Research Notes

- **Completion definition:** All enemy types in `EnemyRegistry.get_all_enemy_ids()` have `bestiary[type_id]["defeated"] >= 1`. Design: add a SaveManager method `is_bestiary_complete() -> bool` that iterates all enemy IDs and checks if each has been defeated at least once. Call this check after every `record_enemy_defeated()` call.
- **One-time guard:** SaveManager tracks `bestiary_complete_rewarded: bool` (default false). Add to instance vars after `bestiary` field. On migration (v14→v15), backfill as `false` for old saves. When bestiary completion is detected, check `if is_bestiary_complete() and not bestiary_complete_rewarded`, then grant rewards, set `bestiary_complete_rewarded = true`, and emit `GameBus.bestiary_complete` signal.
- **Coin reward:** Use `SaveManager.add_coins(amount)` — which method exists and is already used in `SceneManager._on_battle_won()` (line 292). Award **500 coins** (tunable via constant).
- **Rare-or-better card:** Check `game_logic/AchievementRegistry.gd` (line 1–23) — achievements have a `reward_card_id` field. For the bestiary achievement, pick a **rare or legendary** card. Options from `data/cards/`:
  - Check what card IDs exist by searching CardRegistry (search for `CardRegistry` or browse `data/cards/*.tres`).
  - Per `meta-progression.md`, legendary cards are: `ancient_guardian`, `soul_harvest`, `time_warp`, `phoenix_rise`, `void_wyrm`. Pick one (e.g., `soul_harvest` — thematic for collecting lore) or a non-legendary rare (e.g., `mend`, `wither`). Use `SaveManager.add_card_instance(card_id, "rare")` or higher rarity.
  - Method exists at line ~276 in SceneManager: `save_manager.add_card_instance(reward, rarity, ...)` but that's for battle drops. Check SaveManager for a simpler `add_card_instance(card_id, rarity)` signature (search SaveManager for `add_card_instance` definition).
- **Achievement definition:** Add to `AchievementRegistry.ACHIEVEMENTS` array:
  ```gdscript
  {
      "id": "monster_scholar",
      "name": "Monster Scholar",
      "description": "Defeat every enemy type at least once.",
      "condition_type": "specific_flag",
      "target_value": 1,
      "reward_card_id": "soul_harvest",
      "flag_key": "bestiary_complete",
  }
  ```
  Or create a new `condition_type` value `"bestiary_complete"` if preferred (but specific_flag works via a story flag trigger).
- **Achievement unlock flow:** When `record_enemy_defeated()` detects completion, call `SaveManager.set_story_flag("bestiary_complete", true)`. In SaveManager's `set_story_flag()`, if the flag is newly set, call `check_flag_achievement("bestiary_complete")`. Per `meta-progression.md` (line 32), this method compares `unlocked_achievements` against `AchievementRegistry` and emits `GameBus.achievement_unlocked` if the flag matches a `specific_flag` achievement.
- **GameBus signal:** Reuse `GameBus.achievement_unlocked(achievement_id: String)` (already exists, line 29). No new signal needed.
- **Achievement toast:** `AchievementToast.gd` (lines 1–106) already listens to `achievement_unlocked` signal (line 20) and queues toasts. No new code needed — the existing toast system will auto-display "Monster Scholar" when the achievement is unlocked.
- **Verification:** On unlock, verify:
  1. Coins are added to save.coins
  2. Card is added to owned_cards with correct rarity
  3. Achievement appears in unlocked_achievements
  4. Toast shows on screen (manual test; headless test can check GameBus signal emission)
- **Integration with TID-171:** The bestiary UI can display a visual indicator (e.g., "★ All enemies defeated!" banner) if `is_bestiary_complete()` returns true. Optional for this task but nice-to-have.
- **Tests:** Headless test `tests/test_bestiary_completion.gd` covering:
  1. Defeat 3 of 4 enemy types → `is_bestiary_complete()` returns false, no reward granted
  2. Defeat all 4 enemy types → `is_bestiary_complete()` returns true
  3. On completion, `bestiary_complete_rewarded` is set to true (guard works)
  4. Completing again (if somehow defeated counter increments further) does not grant reward twice
  5. Coin and card reward are present in SaveManager after reload
  6. Achievement is in `unlocked_achievements`
  7. `GameBus.achievement_unlocked` signal is emitted with `"monster_scholar"` ID

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
