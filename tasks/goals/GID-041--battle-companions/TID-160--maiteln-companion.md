# TID-160: Maiteln Companion Content, Story-Flag Gated

**Goal:** GID-041
**Type:** agent
**Status:** done
**Depends On:** TID-159

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Maiteln the wizard is the player's story mentor — making him the first companion turns Chapter 1 progress into a battle-loop reward. He grants "draw 1 extra card at the start of each turn", a wizard-flavoured passive that's strong but not warping.

## Research Notes

- **Story flag:** Find the exact flag set when Maiteln joins Saimtar — check `docs/human/story.md`, `docs/agent/story-implementation.md`, and SaveManager's flag fields (GID-001/GID-020). Use that existing flag in `unlock_story_flag`; do NOT invent a new flag if one exists. If the joining beat isn't implemented yet (GID-020 is partially pending), pick the earliest existing flag that proves Maiteln has been met and note the choice in Changes Made.
- **CompanionData file:** `data/companions/maiteln.tres` + `.uid` sidecar:
  - `companion_id = "maiteln"`, `display_name = "Maiteln"`
  - `description = "The old wizard shares his insight: draw an extra card at the start of each turn."`
  - `passive_type = "draw_card"`, `passive_value = 1`
- **Portrait:** No art asset exists. Generate a 64×64 placeholder via `game_logic/TextureGen.gd` (grey robe / white beard blocks in the existing pixel style — study how TextureGen builds the player/NPC sprites) or leave `portrait` unset and rely on the TID-159 fallback. Do not add binary assets.
- **Registry:** Add `const _C_MAITELN := preload("res://data/companions/maiteln.tres")` to `CompanionRegistry.gd` per the Android preload rule.
- **First-equip moment:** When Maiteln is equipped for the first time, show a one-line flavour popup ("Maiteln chuckles. 'Try to keep up, boy.'") — reuse whatever toast/dialogue popup TID-159's picker uses; track first-equip with a simple flag inside `SaveManager` only if a generic mechanism doesn't already exist (avoid one-off fields if a story-flag store can hold it).
- **Locked-state text:** In the picker: "Travel with Maiteln in the story to unlock."
- **Balance check:** +1 draw/turn with a 5-card minimum deck (GID-003) accelerates fatigue/empty-deck edge cases — check how the game handles drawing from an empty deck (GameState/PlayerState draw routine) and make sure the passive doesn't crash there; add a headless test for drawing with an empty deck + companion active.
- **Tests:** Headless: Maiteln locked without flag, unlocked with it; passive draws 2 total at turn start (1 base + 1 passive — verify base draw count first); empty-deck draw safety.
- `docs/agent/story-implementation.md` — document Maiteln's companion unlock as a story reward; `docs/agent/battle-system.md` — add him to the companion list.

## Plan

1. Create `data/companions/maiteln.tres` (+ .uid) with `unlock_story_flag = "story_intro_complete"`, `passive_type = "draw_card"`, `passive_value = 1`.
2. Add `const _C_MAITELN` preload to `CompanionRegistry.gd` and include it in `_ensure_loaded()`.
3. Update `CharacterScene._on_equip_companion` to show a first-equip toast via `SceneManager.show_toast`; track first equip via `SaveManager.set_story_flag("companion_maiteln_first_equip")`.
4. Update companion picker locked-state text to show `"Travel with Maiteln in the story to unlock."` for Maiteln specifically.
5. Verify empty-deck draw safety in PlayerState (no crash when draw_card called on empty deck).
6. Add headless tests: locked without flag / unlocked with flag (mocked via registry logic); empty-deck draw safety; 2-total-cards drawn at turn start.
7. Update docs.

## Changes Made

- **`data/companions/maiteln.tres`** (+ `.uid`): Created with `companion_id="maiteln"`, `display_name="Maiteln"`, `passive_type="draw_card"`, `passive_value=1`, `unlock_story_flag="story_intro_complete"`. Used `story_intro_complete` — the earliest existing flag set when Maiteln is first encountered — since GID-020's "Maiteln joins" beat is pending.
- **`autoloads/CompanionRegistry.gd`**: Added `const _C_MAITELN` preload and included it in `_ensure_loaded()` array (Android preload rule).
- **`scenes/ui/CharacterScene.gd`**: Added `_COMPANION_LOCKED_TEXT` dict with Maiteln's "Travel with Maiteln in the story to unlock." text; added `_COMPANION_FIRST_EQUIP_TOAST` dict with Maiteln's quip; `_on_equip_companion()` now calls `set_story_flag("companion_maiteln_first_equip")` and `_show_companion_toast()` on first equip.
- **`tests/unit/test_companion_framework.gd`**: Added 18 Maiteln-specific tests: registry lookup, passive_type/value/flag assertions, locked-without-SaveManager guard, draw-card turn-start combination, empty-deck draw safety. All 38 companion tests pass.

## Documentation Updates

- **`docs/agent/battle-system.md`**: Added Maiteln to the companion catalogue in the Companion System section; documented `story_intro_complete` as unlock flag and first-equip toast mechanism.
