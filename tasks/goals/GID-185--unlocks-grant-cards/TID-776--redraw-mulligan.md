# TID-776: Redraw (mulligan) row

**Goal:** GID-185
**Type:** agent
**Status:** done
**Depends On:** TID-775

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

See goal.md.

## Research Notes

- `SaveManager.learn_ability(id, cost)` grants technique cards via `_own_technique`; normal cards go through
  `grant_card_reward(id, rarity)` (bag full → mailbox). New persisted fields: one `PERSISTED_FIELDS` entry + var.
- `UnlockLadder.all_ids()`, `is_learned`, `can_learn`; `BalanceBands.all_learned()` learns every row, so deck-rule rows
  move the balance cells (re-baseline if intended).
- Real-time hand cap / draw: `RealtimeCombat` line ~332 (`tune.get_f("draw_interval")`, `tune.get_i("hand_cap")`), same
  for both sides — needs per-side modifiers. Opening hand: `BattleSetup.configure_realtime` → `rt.trim_hand`.
- Trainer UI: `NpcInteractions._trainer_row`; card faces via `CardInspectOverlay.present(parent, CardInstance, on_close)`.

## Plan

1. `feat_redraw` row (level 13, combat, 110 gold, grants Arcane Seal), in `DECK_RULE_ROWS`.
2. Pure rules in `game_logic/battle/Redraw.gd` over `RealtimeCombat.redraw_ready` / `fight_time`; window knob `redraw_window` in CombatTuning.
3. `RedrawButton.gd` in the action strip + R key. Real time only.

## Changes Made

- `UnlockLadder.gd`: `FEAT_REDRAW` row + card. `CombatTuning`: `redraw_window` 6 s.
- `RealtimeCombat`: `redraw_ready`, `fight_time` (advanced in `advance`). New `game_logic/battle/Redraw.gd` (kept out of RealtimeCombat: gdlint max-public-methods).
- `BattleSetup.apply_deck_rules` sets `redraw_ready`. New `scenes/battle/modules/RedrawButton.gd`; `BattleRealtime` builds/updates it, R key.
- Tests: `test_redraw_mulligan_once_in_window`; guardrail allow-list entry for `_RedrawButton.new(_battle, self)`.
- Validation: parse/unsafe/gdlint clean; runner 3466 / 0 / 0 SCRIPT ERROR; realtime_battle_smoke, in_world_battle_smoke, battle_input_flow_smoke exit 0 with 0 SCRIPT ERROR.

## Documentation Updates

- `starter-zone-and-training.md` Deck-rule rows (Redraw row), `combat-model.md` "Deck-rule unlocks", CLAUDE.md BattleRealtime row.
