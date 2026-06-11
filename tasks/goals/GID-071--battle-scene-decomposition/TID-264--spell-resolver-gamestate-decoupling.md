# TID-264: Extract spell resolver; decouple GameState; wire GameBus battle signals

**Goal:** GID-071
**Type:** agent
**Status:** pending
**Depends On:** TID-263

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

This task extracts the 121-line spell-effect match statement into a dedicated resolver module, eliminates duplicated attack resolution logic, fixes the critical GameState→SceneTree coupling (the logic half of backlog item BID-010), and wires the never-emitted GameBus signals (resolves BID-006). After this task, game_logic/battle will be completely rendering-free, and all inter-system communication flows through GameBus signals.

## Research Notes

**Spell effect resolver:** BattleScene.gd:1260–1380 (~121 lines):
- _resolve_spell_effect: Giant match statement handling all spell types (damage, heal, poison, armor, freeze, stun, status clears, draw, mana effects, etc.).
- _resolve_emergence (1233–1259): Special case for emergence (summon) spell resolution.
- _flush_auto_spells (1382–1388): Clears auto-trigger queue after each action.

Extract to game_logic/battle/SpellEffectResolver.gd if it can be made scene-free (injected damage callback + emitter Callable), otherwise scenes/battle/.

**Attack resolution duplication:** _on_enemy_card_input (1097–1131) and _on_enemy_hero_input (1133–1166) share approximately 35 lines:
- take_damage on both target branches.
- attack_count decrement.
- Flash/float/shake trigger.
- _refresh_all.
- _check_game_over.

Extract _execute_attack(attacker, target_card_or_null) helper to eliminate duplication.

**Targeting effect arrays:** _ENEMY_TARGETED_EFFECTS / _FRIENDLY_TARGETED_EFFECTS (lines 53–54):
- Used at 372–373, 1099–1100, 1134–1135.
- Must stay in sync with resolver's match arms.
- Co-locate with the resolver.

**GameState coupling (BID-010 logic half):** game_logic/battle/GameState.gd:33–41:
- end_turn() calls Engine.get_main_loop(), finds the GameBus node, and emit_signal("turn_ended").
- This violates the "game_logic/ is rendering-free" rule.

Solution: Replace with an injected emitter Callable (set at construction by BattleScene) or define a plain `signal turn_ended` on GameState that BattleScene relays to GameBus. game_logic/ must stay tree-agnostic.

**BID-006 (never-emitted battle signals):** autoloads/GameBus.gd declares:
- card_played (line 19)
- card_attacked (line 20)
- battle_ended (line 22)

These are never emitted anywhere. Emit them at real sites:
- card_played: When a card is actually played (BattleScene _finish_hand_drag / play paths, around line 639–644 and 647–650).
- card_attacked: When an attack resolves (the new _execute_attack helper, around line 1115 and 1155).
- battle_ended: When the battle concludes (_check_game_over, around line 1450–1488).

Update docs/agent/battle-system.md integrations table to document these signals' emission points. Mark BID-006 resolved when done (move tasks/backlog/BID-006 file to tasks/archive/backlog/ per workflow).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
