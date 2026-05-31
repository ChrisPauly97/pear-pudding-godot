# TID-118: Wire First-Time Triggers

**Goal:** GID-031
**Type:** agent
**Status:** pending
**Depends On:** TID-117

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The popup system is only useful if it fires at the right moments. This task wires the actual trigger points in existing scenes/scripts to emit `GameBus.tutorial_popup_requested` with the right popup ID the first time the player encounters each system.

## Research Notes

**Trigger points to wire:**

| Trigger | popup_id | Where to add emit |
|---|---|---|
| Player opens Skill Tree for first time | `"skill_tree"` | `SceneManager.gd` — in `_on_skill_tree_requested()` or wherever `SkillTreeScene` is instantiated |
| First coin earned (coins > 0 for first time) | `"coins"` | `SaveManager.gd` — in `add_coins()` method, check `coins == 0` before adding |
| First essence gained | `"essence"` | `SaveManager.gd` — in `add_essence()` (or equivalent), check `essence == 0` before adding |
| First battle starts | `"mana"` | `SceneManager.gd` — in the `_on_enemy_engaged()` handler, first battle only (reuse existing `tutorial_battle_tip` flag pattern) |
| First rare+ card obtained | `"card_rarity"` | `SaveManager.gd` — in `add_card()` (or wherever cards are added to owned_cards), check if first non-Common card |

**Implementation pattern (identical for each):**
```gdscript
# Check flag — GameBus emit is enough; SceneManager suppresses if already seen
if not save_manager.has_story_flag("seen_tutorial_skill_tree"):
    GameBus.tutorial_popup_requested.emit("skill_tree")
```

SceneManager (from TID-116) already handles the flag-setting and deduplication, so trigger sites don't need to set flags themselves — just emit.

**Files to modify:**
- `autoloads/SceneManager.gd` — skill_tree and mana triggers
- `autoloads/SaveManager.gd` — coins, essence, card_rarity triggers (requires reading the file to find exact method names)

**Note on SaveManager:** Check exact method names before editing. The coins field is at line 11. Search for `add_coins`, `add_essence`, and card-adding methods in the file.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
