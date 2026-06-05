# TID-141: Extended Targeting for Single-Target Spells

**Goal:** GID-035
**Type:** agent
**Status:** done
**Depends On:** TID-140

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Currently only `deal_damage_single` has a targeting UI. Six other single-target spells auto-target slot 0 silently: `heal_single`, `shield_minion`, `buff_attack` (friendly targets) and `curse_minion`, `lifesteal_hit` (enemy targets). Players can't choose which minion to affect. This task adds targeting modes for all of them.

## Research Notes

**Existing targeting flow (`deal_damage_single`):**
1. Player drags spell card to board area — `_on_drop()` detects it's in `_TARGETED_EFFECTS`.
2. Targeting mode entered: `_targeting_active = true`, `_targeting_spell = card`, card returned to hand visually.
3. `_refresh_all()` draws enemy board with cyan border on valid targets (see `_apply_card_style` zone_id "enemy_board" branch).
4. `_on_enemy_card_input()` and `_on_enemy_hero_input()` detect targeting mode and resolve on click.
5. "Cancel Spell" button shown; clicking cancels targeting.

**Changes needed:**
- Add `_FRIENDLY_TARGETED_EFFECTS: Array[String] = ["heal_single", "shield_minion", "buff_attack"]` constant.
- Add `_ENEMY_TARGETED_EFFECTS: Array[String] = ["deal_damage_single", "curse_minion", "lifesteal_hit"]` (superset of current `_TARGETED_EFFECTS`).
- Add `_targeting_friendly: bool` flag to distinguish which board is highlighted.
- In `_on_drop()`: check both lists; set `_targeting_friendly` accordingly.
- In `_apply_card_style()`: when `_targeting_friendly` and zone_id == "board", add cyan border to friendly minions.
- In `_on_board_card_input()`: when `_targeting_friendly` is true and targeting_active, resolve the spell against the clicked friendly card.
- Update `_resolve_spell_effect()` for `heal_single`, `shield_minion`, `buff_attack` to honour `explicit_target` dict (currently ignored).
- Update `_resolve_spell_effect()` for `curse_minion`, `lifesteal_hit` to honour `explicit_target` dict (currently targets slot 0).
- AI (`BasicAI.gd`): AI already auto-targets (plays spells without targeting UI), so no AI change needed — the explicit_target dict is only used by player-initiated targeting.
- `lifesteal_hit` friendly target: after enemy is selected, resolve same as before but against chosen target instead of slot 0.

**Key files:**
- `scenes/battle/BattleScene.gd` — all targeting logic lives here.
- `game_logic/battle/BasicAI.gd` — no changes needed (AI uses auto-targeting path).

**Edge cases:**
- If no friendly minions exist when a friendly-targeted spell is dragged, auto-resolve immediately (same as current behaviour for heal_single when board is empty).
- If no enemy minions exist when an enemy-targeted spell is dragged, allow targeting the enemy hero (same as current deal_damage_single behaviour).

## Plan

1. Replace `_TARGETED_EFFECTS` with `_ENEMY_TARGETED_EFFECTS` and `_FRIENDLY_TARGETED_EFFECTS` constants.
2. Add `_targeting_friendly: bool = false` flag.
3. Update `_finish_hand_drag()` — check both lists; skip targeting mode if no valid targets exist (friendly board empty / enemy board empty for non-hero spells); pass `friendly` bool to `_enter_targeting_mode()`.
4. Update `_enter_targeting_mode()` to accept `friendly` parameter and set `_targeting_friendly`.
5. Reset `_targeting_friendly` in `_cancel_targeting()`, `_on_target_chosen_card()`, `_on_target_chosen_hero()`.
6. Update `_apply_card_style()`: cyan border on `enemy_board` only when `not _targeting_friendly`; cyan border on `board` when `_targeting_friendly`.
7. Update `_on_board_card_input()`: resolve spell when `_targeting_active and _targeting_friendly`.
8. Update `_on_enemy_card_input()` and `_on_enemy_hero_input()`: guard with `not _targeting_friendly`.
9. Update `_refresh_hero()`: `is_spell_targetable` only true when `not _targeting_friendly`.
10. Update `_resolve_spell_effect()`: `heal_single`, `shield_minion`, `buff_attack` use `explicit_target` card when provided; `curse_minion`, `lifesteal_hit` use `explicit_target` card when provided.

## Changes Made

- `scenes/battle/BattleScene.gd`:
  - Replaced `_TARGETED_EFFECTS` with `_ENEMY_TARGETED_EFFECTS` (`deal_damage_single`, `curse_minion`, `lifesteal_hit`) and `_FRIENDLY_TARGETED_EFFECTS` (`heal_single`, `shield_minion`, `buff_attack`).
  - Added `_targeting_friendly: bool` flag; set in `_enter_targeting_mode(friendly)`, cleared in cancel/resolve handlers.
  - `_finish_hand_drag()`: checks both lists; skips targeting mode if no valid targets exist (friendly board empty, or enemy board empty for non-hero spells), falling through to auto-resolve.
  - `_apply_card_style()`: cyan border on `enemy_board` only when `not _targeting_friendly`; cyan border on `board` when `_targeting_friendly`.
  - `_on_board_card_input()`: resolves friendly spell on click when `_targeting_active and _targeting_friendly`.
  - `_on_enemy_card_input()` and `_on_enemy_hero_input()`: guarded with `not _targeting_friendly`.
  - `_refresh_hero()`: `is_spell_targetable` only true when `not _targeting_friendly`.
  - `_resolve_spell_effect()`: `heal_single`, `shield_minion`, `buff_attack` now use `explicit_target.get("card")` with slot-0 fallback; `lifesteal_hit` and `curse_minion` same. Also fixed `shield_minion` to write armor via `apply_status()` instead of the stale `self.armor` field (original was broken — `take_damage()` reads from `status_effects["armor"]`, not `self.armor`).

## Documentation Updates

Updated `docs/agent/battle-system.md` — extended targeting section under BattleScene UI.
