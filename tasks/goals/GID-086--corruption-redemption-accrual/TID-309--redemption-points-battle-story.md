# TID-309: Accrue redemption points from battle outcomes and story flags

**Goal:** GID-086
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`SaveManager.add_redemption_points()` has zero call sites. Per user decision (June 2026): redemption points should accrue from Dusk-branch card usage in battles and from story milestone flags.

Intended accrual logic:
- On battle victory, count how many Dusk-branch cards were played
- Award `played_dusk_cards * REDEMPTION_PER_CARD` points (suggested 1 per card)
- When a story chapter flag is set (e.g. `chapter1_complete`), award a fixed redemption bonus (suggested 10 points)
- Call `SaveManager.add_redemption_points(amount)` and verify `GameBus.redemption_points_changed` fires

Dusk-branch card identification: check `CardData.magic_branch == "dusk"` or equivalent field.

## Plan

1. Add `dusk_cards_played: int = 0` to `PlayerState`. Increment in `play_card()` and `play_card_at_slot()` when `card.magic_branch == "dusk"`.
2. Pass `dusk_played` through `BattleScene` → `BattleResultUI` → `battle_won` dict → `SceneManager._on_battle_won()`.
3. `SceneManager._on_battle_won()`: call `save_manager.add_redemption_points(dusk * REDEMPTION_PER_CARD)` (constant 1).
4. `SaveManager.set_story_flag()`: add a `REDEMPTION_FLAG_AWARDS` constant dict mapping chapter milestone flags to bonus amounts; on first-time flag set, call `add_redemption_points(bonus)`.

## Changes Made

- `game_logic/battle/PlayerState.gd`: `dusk_cards_played` counter added (shared with TID-308 changes).
- `scenes/battle/BattleResultUI.gd`: `dusk_played` param and dict entry added to all three result overlay functions (shared with TID-308).
- `scenes/battle/BattleScene.gd`: `dusk_win` captured and passed through (shared with TID-308).
- `autoloads/SceneManager.gd`: reads `dusk_played` and calls `save_manager.add_redemption_points()` (shared with TID-308).
- `autoloads/SaveManager.gd`: added `REDEMPTION_FLAG_AWARDS` const dict with 6 chapter milestone flags (5–15 points each); `set_story_flag()` awards redemption points on first-time set of any listed flag.

## Documentation Updates

No new doc files needed.
