# TID-308: Accrue corruption points from battle outcomes

**Goal:** GID-086
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`SaveManager.add_corruption_points()` has zero call sites. Per user decision (June 2026): corruption points should accrue from Dawn-branch card usage in battles.

Intended accrual logic:
- On battle victory, count how many Dawn-branch cards were played this battle
- Award `played_dawn_cards * CORRUPTION_PER_CARD` points (define constant, suggested 1 per card)
- Cleansing a BlightHeart also awards a fixed bonus (suggested 5 points)
- Call `SaveManager.add_corruption_points(amount)` and verify `GameBus.corruption_points_changed` fires

Dawn-branch card identification: check `CardData.magic_branch == "dawn"` or equivalent field.

## Plan

1. Add `dawn_cards_played: int = 0` to `PlayerState` (non-serialized counter). Increment in `play_card()` and `play_card_at_slot()` when `card.magic_branch == "dawn"`.
2. In `BattleScene._check_game_over()` when `w == 0`, read `_state.players[0].dawn_cards_played` and pass to `_result_ui.show_victory()`, `show_soulbind()`, and `show_victory_boss()` as a new param.
3. `BattleResultUI`: include `dawn_played` in the `battle_won.emit()` dict.
4. `SceneManager._on_battle_won()`: read `result.get("dawn_played", 0)`, call `save_manager.add_corruption_points(dawn * CORRUPTION_PER_CARD)` (constant 1).
5. BlightHeart cleansing: change existing `add_redemption_points(10)` → `add_corruption_points(5)` and update HUD message.

## Changes Made

- `game_logic/battle/PlayerState.gd`: added `dawn_cards_played: int = 0` and `dusk_cards_played: int = 0` non-serialized counters; incremented in `play_card()` and `play_card_at_slot()` based on `card.magic_branch`.
- `scenes/battle/BattleResultUI.gd`: updated `show_victory()`, `show_soulbind()`, and `show_victory_boss()` to accept `dawn_played: int = 0` and `dusk_played: int = 0` params; included both in the `GameBus.battle_won.emit()` dict.
- `scenes/battle/BattleScene.gd`: in `_check_game_over()` at `w == 0`, captured `dawn_win` and `dusk_win` from `_state.players[0]` and passed them to all three result UI calls.
- `autoloads/SceneManager.gd`: in `_on_battle_won()`, added `CORRUPTION_PER_CARD = 1` and `REDEMPTION_PER_CARD = 1` constants, reads `dawn_played`/`dusk_played` from result dict and calls `save_manager.add_corruption_points()` / `save_manager.add_redemption_points()` accordingly; changed BlightHeart cleansing from `add_redemption_points(10)` → `add_corruption_points(5)` and updated HUD message.

## Documentation Updates

No new doc files needed; changes are self-contained in existing battle pipeline.
