# TID-082: Achievement Data Model and SaveManager Integration

**Goal:** GID-024
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

No achievement system exists. This task defines the achievement list, the data model for tracking progress, and the SaveManager fields + GameBus signal that the rest of GID-024 builds on.

## Research Notes

- New file: `game_logic/AchievementRegistry.gd` — a static registry of all achievement definitions; add as autoload or load via preload
- Achievement definition fields: id (String), name (String), description (String), condition_type (String), target_value (int), reward_card_id (String, empty if no card reward)
- `condition_type` values: `"battles_won"`, `"enemies_defeated"`, `"cards_earned"`, `"biomes_visited"`, `"chests_opened"`, `"specific_flag"` (for story-gated achievements)
- `autoloads/SaveManager.gd` — add `achievement_progress: Dictionary` (key: achievement_id, value: current_count int) and `unlocked_achievements: Array[String]` (list of unlocked achievement IDs)
- `autoloads/GameBus.gd` — add signal `achievement_unlocked(achievement_id: String)` emitted when an achievement is first completed
- Helper function (in AchievementRegistry or SaveManager): `increment_progress(condition_type, amount)` — increments all relevant achievements and calls `_check_unlock()` for each; `_check_unlock()` emits GameBus.achievement_unlocked if newly completed
- Call `increment_progress("battles_won", 1)` from BattleScene on win; `increment_progress("enemies_defeated", 1)` from WorldScene on enemy defeat; etc.
- Strict mode: Dictionary values are Variant; use explicit `int` casts

**Suggested initial achievement list (10–12 milestones):**

| ID | Name | Condition | Target | Reward Card |
|---|---|---|---|---|
| first_blood | First Blood | battles_won | 1 | — |
| veteran | Battle Veteran | battles_won | 10 | (legendary card) |
| explorer | World Explorer | biomes_visited | 5 | — |
| treasure_hunter | Treasure Hunter | chests_opened | 10 | (legendary card) |
| card_collector | Card Collector | cards_earned | 20 | — |
| chapter1_done | The Warning Given | specific_flag: chapter1_complete | 1 | (legendary card) |
| undead_slayer | Undead Slayer | enemies_defeated | 25 | — |
| dawn_devotee | Dawn Devotee | (deck contains 5+ dawn cards and win) | 1 | (legendary card) |
| dusk_disciple | Dusk Disciple | (deck contains 5+ dusk cards and win) | 1 | (legendary card) |

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
