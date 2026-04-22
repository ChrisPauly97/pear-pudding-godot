# TID-078: Hit Flash on Minions and Heroes

**Goal:** GID-023
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

When a minion or hero takes damage there is no visual reaction — they simply update their health number. A brief color flash signals impact and makes combat feel responsive.

## Research Notes

- `scenes/battle/BattleScene.gd` — find the card/hero display nodes; they are likely Control nodes with a background ColorRect or TextureRect
- Flash approach: when damage is applied, tween the node's `modulate` color:
  1. Instantly set `modulate = Color(1, 0.3, 0.3, 1)` (red tint)
  2. Tween back to `Color(1, 1, 1, 1)` over 0.25s
- For healing: flash green `Color(0.3, 1, 0.5, 1)` then back to white
- Encapsulate in a helper method `_flash_node(node: Control, flash_color: Color)` in BattleScene to avoid repetition
- Minion cards: the card display container or its background panel
- Hero panel: the hero HP display container
- Godot Tween: `var tw := create_tween(); tw.tween_property(node, "modulate", flash_color, 0.0); tw.tween_property(node, "modulate", Color.WHITE, 0.25)`
- Strict mode: `create_tween()` returns a `Tween` — do not use `:=` unless the call site is typed

## Plan

Two complementary strategies:

**Direct attack sites** (`_on_enemy_card_input`, `_on_enemy_hero_input`): capture panel refs before damage via `_get_card_panel()`, then flash them immediately after `take_damage` but before `remove_card`. This ensures even dying minions flash briefly before their panel is freed.

**Snapshot-based sites** (spells, AI actions, status ticks): `_flash_from_snapshot()` mirrors the existing `_spawn_float_labels_from_snapshot()` pattern — diffs current HP against the snapshot and flashes all surviving cards/heroes that had HP changes. Dead cards are skipped (they disappear, which is itself a visual cue).

## Changes Made

- `scenes/battle/BattleScene.gd`:
  - Added `_get_card_panel(card, is_enemy) -> Control` — finds a CardInstance's panel in the zone view by index.
  - Added `_flash_node(node, flash_color)` — instantly tints to flash_color, tweens back to white over 0.25s.
  - Added `_flash_from_snapshot(snap)` — flashes surviving cards and heroes based on HP diff against a snapshot.
  - `_on_enemy_card_input`: get target/attacker panel refs before damage, flash both after damage.
  - `_on_enemy_hero_input`: get attacker panel ref, flash enemy hero view and attacker after damage.
  - `_finish_hand_drag`, `_on_target_chosen_card`, `_on_target_chosen_hero`: call `_flash_from_snapshot` after spell resolution.
  - `_execute_ai_actions`: call `_flash_from_snapshot` after each AI action.
  - `_on_turn_ended`: call `_flash_from_snapshot` after status ticks and after auto-spell resolution.

## Documentation Updates

- Updated `docs/agent/battle-system.md` to document the hit flash system.
