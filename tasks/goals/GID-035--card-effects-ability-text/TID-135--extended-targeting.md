# TID-135: Extended Targeting for Single-Target Spells

**Goal:** GID-035
**Type:** agent
**Status:** pending
**Depends On:** TID-134

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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
