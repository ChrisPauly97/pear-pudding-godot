# TID-206: Potions in Battle

**Goal:** GID-056  
**Type:** agent  
**Status:** pending  
**Depends On:** TID-205

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

Potion consumable UI in the battle HUD, one-per-battle limit, three effects: heal, draw, mana boost. Integrates with BattleScene's existing turn flow and HeroState stat updates.

## Research Notes

- **BattleScene HUD structure** (**`scenes/battle/BattleScene.gd`**):
  - Main UI components: `$EnemyArea`, `$PlayerArea`, `$SidePanel` (cite lines **92–101**)
  - `$SidePanel` holds: `TurnLabel`, `ManaLabel`, `EndTurnButton`, `MenuButton` (line 100–101)
  - Add a **potion button** in the SidePanel next to the "End Turn" button
  - Button sizing: cite CLAUDE.md viewport-relative sizing rule — button: 5–6% vh height, e.g. `custom_minimum_size = Vector2(_vh * 0.06, _vh * 0.06)` for a square icon button
  - Font size: 2–2.5% vh = `int(_vh * 0.022)`
  - Label/icon: "P" (potion) or drink icon; no text if icon-only to fit HUD constraints

- **Potion button implementation** (**`scenes/battle/BattleScene.gd`** method `_add_potion_button()`):
  - Call this in `_ready()` after existing button setup (~line 154–157)
  - Create a Button node, add to SidePanel, connect to `_on_potion_button_pressed`
  - Store ref in `var _potion_btn: Button = null` (alongside `_hero_power_btn` at line 24)
  - Store state in `var _used_potion_this_battle: bool = false` (battle-local, NOT persisted; initialized to `false` at battle start)
  - Note: Do **NOT** add this flag to GID-034 mid-battle state persistence — potions are one-per-battle only within a continuous battle session, not across resume. If the player pauses and resumes the same battle, the flag persists in the local `_used_potion_this_battle` var (which is NOT in `GameState.to_dict()`), so resuming gives a fresh potion use.

- **Potion picker flow** — when potion button is pressed:
  1. Check if potions are owned: if `SaveManager.potions` is empty or all counts are 0, button is disabled (hidden)
  2. Check if already used: if `_used_potion_this_battle == true`, button is disabled
  3. On button press, show a picker popup:
     - Similar to seed picker from TID-204: VBoxContainer listing owned potions with counts
     - Player selects a potion → confirm
     - Call `_apply_potion_effect(potion_id)`
     - Set `_used_potion_this_battle = true`
     - Decrement `SaveManager.potions[potion_id]`
     - Refresh button state (disable it or hide it)
     - Emit `GameBus.potion_used(potion_id)` for toast/battle log (cite TID-026 battle log if it exists — check **`scenes/battle/BattleLog.gd`** or similar in scenes/battle/)

- **Potion effect implementation** — `_apply_potion_effect(potion_id: String)`:
  - **Healing Draught** (`"healing_draught"`): Restore 8 HP to hero, capped at max
    - Cite **`game_logic/battle/HeroState.gd`** line 5–6: hero.health and hero.max_health
    - Code: `_state.players[0].hero.health = mini(_state.players[0].hero.health + 8, _state.players[0].hero.max_health)`
    - Show "+8 HP" float label and flash green on player hero panel (cite TID-077 float labels and TID-078 hit flash from battle-system.md lines 151–152)
  - **Clarity Brew** (`"clarity_brew"`): Draw 2 cards
    - Cite **`game_logic/battle/PlayerState.gd`** line 44 `draw_card()` method
    - Code: for 2 iterations, call `_state.players[0].draw_card()` then `_refresh_all()` to redraw hand
  - **Ember Tonic** (`"ember_tonic"`): Grant +1 mana THIS TURN only
    - Cite **`game_logic/battle/HeroState.gd`** line 7 `mana` field
    - Code: `_state.players[0].hero.mana += 1` (do NOT modify max_mana — it resets next turn via `gain_mana_for_turn()`)
    - Show "+1 Mana" float label on mana display
  - All three: call `_refresh_all()` to redraw the board state, call `_snapshot_hp_positions()` and `_spawn_float_labels_from_snapshot()` for float label (cite lines 153 TID-077 for float snapshot/spawn)

- **Button state refresh** — update button disabled/visible state:
  - Call `_refresh_potion_button()` at:
    - End of `_ready()` (initial state)
    - After `_apply_potion_effect()` (disables if already used or potions empty)
    - After enemy turn ends (ensures button state is consistent)
  - Logic in `_refresh_potion_button()`:
    - `var has_potions: bool = false` — check if any potion count > 0 in SaveManager.potions dict
    - `_potion_btn.disabled = _used_potion_this_battle or not has_potions`
    - Optionally hide the button if disabled for cleaner HUD

- **AI never uses potions** — state this as a v1 constraint (no enemy potion logic needed)

- **Enemy turn guard** — potion button is disabled during enemy turn:
  - In `_on_turn_ended(turn_player_idx)` (cite line 158), after AI actions, set `_potion_btn.disabled = true`
  - In player turn start (cite how turn-start detection works — either after `_state.start_turn(1)` or on `GameBus.turn_ended` if it fires for player too), set `_potion_btn.disabled = false` (unless already used or empty)
  - Alternatively, check `_state.current_player_idx == 0` before enabling potion button

- **GameBus signal** (**`autoloads/GameBus.gd`**):
  - Add `signal potion_used(potion_id: String)` — fired when a potion effect is applied; used for toast and optional battle log (check if TID-026 battle log exists)

- **Headless tests** (**`tests/battle_potions_test.gd`**):
  - Test healing effect: call `_apply_potion_effect("healing_draught")` on a damaged hero, verify HP increases by 8 and caps at max_health
  - Test draw effect: mock PlayerState, call draw effect, verify 2 cards drawn
  - Test mana effect: call mana effect, verify hero.mana += 1 (not max_mana)
  - Test one-per-battle: set `_used_potion_this_battle = true`, verify button is disabled
  - Test decrement: call effect, verify SaveManager.potions[id] decremented
  - Test empty potions: clear all potion counts, verify button is disabled

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
