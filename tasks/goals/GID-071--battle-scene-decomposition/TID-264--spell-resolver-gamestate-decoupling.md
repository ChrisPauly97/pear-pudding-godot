# TID-264: Extract spell resolver; decouple GameState; wire GameBus battle signals

**Goal:** GID-071
**Type:** agent
**Status:** done
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

1. Create `scenes/battle/SpellEffectResolver.gd` — holds targeting-effect constants, `extra_turn_granted` flag, `capture_tracker` property, and `setup/resolve_spell/resolve_emergence/flush_auto_spells` methods.
2. Fix `GameState.end_turn()` — add `signal turn_ended(player_id: int)` and replace Engine.get_main_loop() block with `turn_ended.emit(current_player_idx)`.
3. Update `BattleScene.gd`:
   - Preload and instantiate `SpellEffectResolver`, wire `_state.turn_ended` directly.
   - Replace targeting-array constants and all resolver method calls.
   - Remove extracted methods and `_extra_turn_granted` field.
   - Add `_execute_attack(attacker, target)` helper; refactor `_on_enemy_card_input`/`_on_enemy_hero_input`.
   - Emit `GameBus.card_played`, `GameBus.card_attacked`, `GameBus.battle_ended` at real action sites.
   - Relay `GameBus.turn_ended` from `_on_turn_ended` for any external subscribers.

## Changes Made

- **Created `scenes/battle/SpellEffectResolver.gd`** (+ `.uid` sidecar): extracted `_resolve_spell_effect`, `_resolve_emergence`, and `_flush_auto_spells` from BattleScene into a RefCounted class. Co-located targeting-effect constants (`ENEMY_TARGETED_EFFECTS`, `FRIENDLY_TARGETED_EFFECTS`, `SLOT_TARGETED_EFFECTS`). Holds `extra_turn_granted` flag and `capture_tracker` property.
- **Fixed `game_logic/battle/GameState.gd`**: added `signal turn_ended(player_id: int)`; replaced `end_turn()` block that called `Engine.get_main_loop()` / `root.get_node_or_null("GameBus")` with `turn_ended.emit(current_player_idx)`. Eliminates the last SceneTree access in `game_logic/`.
- **Updated `scenes/battle/BattleScene.gd`**:
  - Preloads and instantiates `SpellEffectResolver`; wires `_state.turn_ended` directly; relays to `GameBus.turn_ended` in `_on_turn_ended()` for external subscribers.
  - Removed `_extra_turn_granted` field and three extracted methods; replaced all call sites with resolver delegates.
  - Replaced targeting-array constants with `SpellEffectResolver.ENEMY_TARGETED_EFFECTS` etc.
  - Added `_execute_attack(attacker, target)` helper; refactored `_on_enemy_card_input` / `_on_enemy_hero_input` to use it (eliminates ~35 lines of duplication).
  - Emits `GameBus.card_played` on `_do_play_card` / `_do_play_card_at_slot` success (BID-006).
  - Emits `GameBus.card_attacked` inside `_execute_attack` (BID-006).
  - Emits `GameBus.battle_ended` inside `_check_game_over` (BID-006).
  - BattleScene reduced from 2,561 → 2,391 lines.
- **Resolved BID-006**: moved `tasks/backlog/BID-006--gamebus-battle-signals-never-emitted.md` to `tasks/archive/backlog/`.

## Documentation Updates

- Updated `docs/agent/battle-system.md`:
  - Added **SpellEffectResolver** subsection documenting API, constants, and properties.
  - Updated Card Data section: spell_effect/emergence_effect references point to SpellEffectResolver methods instead of BattleScene methods.
  - Updated Slot Enhancement section: `_SLOT_TARGETED_EFFECTS` → `SpellEffectResolver.SLOT_TARGETED_EFFECTS`; resolver reference corrected.
  - Updated BattleScene UI section: targeting constants and resolve calls reference SpellEffectResolver.
  - Updated Integrations table: GameBus signals row now documents emission sites for `card_played`, `card_attacked`, `battle_ended`, and the `GameState→GameBus` relay for `turn_ended`.
