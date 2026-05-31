# TID-118: Wire First-Time Triggers

**Goal:** GID-031
**Type:** agent
**Status:** done
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

Emit `GameBus.tutorial_popup_requested` at five trigger points. SceneManager's handler (from TID-116) does all dedup/flag work, so trigger sites just emit.

1. `SceneManager._on_skill_tree_requested()` — emit `"skill_tree"` before opening overlay
2. `SceneManager._on_enemy_engaged()` — emit `"mana"` at battle start
3. `SaveManager.add_coins()` — emit `"coins"` when `coins == 0 and amount > 0`
4. `SaveManager.scrap_card_instance()` — emit `"essence"` when `essence == 0` before scrapping
5. `SaveManager.add_card_instance()` — emit `"card_rarity"` when rarity is not "common"

## Changes Made

- `autoloads/SceneManager.gd`: emit `"skill_tree"` in `_on_skill_tree_requested()`; emit `"mana"` in `_on_enemy_engaged()`
- `autoloads/SaveManager.gd`: emit `"coins"` in `add_coins()` when coins==0; emit `"essence"` in `scrap_card_instance()` when essence==0; emit `"card_rarity"` in `add_card_instance()` when rarity != "common"

## Documentation Updates

None — trigger pattern is self-evident from the registry and signal docs.
