# TID-077: Floating Damage and Heal Numbers

**Goal:** GID-023
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Attacks and spells currently produce no visual number feedback. Floating numbers are a baseline expectation in TCG games — they confirm what happened and how much.

## Research Notes

- `scenes/battle/BattleScene.gd` — find where damage is applied to minions and heroes; this is where to spawn floating labels
- Implementation: create a `FloatingLabel` scene or inline function that:
  1. Instantiates a Label node as a child of a CanvasLayer over the battle scene
  2. Sets the text (e.g. "-4" for damage in red, "+3" for healing in green)
  3. Starts at the screen position of the affected card/hero
  4. Tweens: move upward by ~60px over 0.8s, fade alpha from 1 to 0 over 0.8s
  5. `queue_free()` on tween completion
- Use a CanvasLayer at the top of the battle scene tree so numbers render above all cards
- Get screen position of a Control node: `node.get_global_rect().get_center()`
- Colors: damage = red (#FF4444), healing = green (#44FF88), armor = blue (#44AAFF)
- Strict mode: do not use `:=` with Tween return values that are Variant

## Plan

Snapshot-then-diff pattern: before each damage/heal action, capture the HP of all cards and heroes (plus their screen positions). After the action, compare current HP to the snapshot and spawn floating labels for any change. A `CanvasLayer` at layer 128 holds the transient labels so they render above all battle UI.

Coverage points:
1. Player minion attacks enemy minion (`_on_enemy_card_input`)
2. Player minion attacks enemy hero (`_on_enemy_hero_input`)
3. Player plays a non-targeted spell (`_finish_hand_drag`)
4. Player plays a targeted spell at a minion (`_on_target_chosen_card`)
5. Player plays a targeted spell at hero (`_on_target_chosen_hero`)
6. AI turn actions (`_execute_ai_actions`)
7. Status tick damage at turn start (`_on_turn_ended`)
8. Auto-spell resolution at turn start (`_on_turn_ended`)

## Changes Made

- `scenes/battle/BattleScene.gd`:
  - Added `_float_layer: CanvasLayer` variable; created with `layer = 128` in `_ready()`.
  - Added `_pos_of_hero(is_enemy)`, `_snapshot_hp_positions()`, `_spawn_float_labels_from_snapshot()`, `_spawn_float_label()` methods.
  - Added snapshot/spawn-labels calls at all 8 damage coverage points listed above.
- `game_logic/battle/CardInstance.gd`:
  - Removed duplicate `take_damage` method (simple version at line 45 that predated the armor-aware version); the armor-aware version is the only one retained. This was a pre-existing parse error that blocked headless tests.

## Documentation Updates

- Updated `docs/agent/battle-system.md` to document the floating label system.
