# TID-775: Deck-rule rows: technique slot, hand size, draw speed

**Goal:** GID-185
**Type:** agent
**Status:** done
**Depends On:** TID-774

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

1. Three feature rows (`feat_tech_slot` 20, `feat_hand_size` 22, `feat_quick_draw` 25) with rule helpers in UnlockLadder.
2. `deck_violation(ids, max_total)`; per-player draw/hand fields on RealtimeCombat set by `BattleSetup.apply_deck_rules`.
3. Tests, bands, measurement.

## Changes Made

- `UnlockLadder.gd`: rows, `DECK_RULE_ROWS`, `QUICK_DRAW_MULT`, `technique_slots`, `hand_cap_bonus`, `draw_interval_mult`; cards for each row.
- `TechniqueDefs.deck_violation` takes `max_total`; callers in `InventoryScene`, `SaveManager` pass the learned slots.
- `RealtimeCombat`: `player_draw_mult`, `player_hand_bonus` in the draw tick. `BattleSetup.apply_deck_rules`, `level_deck` uses `technique_slots`; `BattleRealtime.maybe_start` applies them.
- `BalanceBands.all_learned` excludes deck-rule rows (bands otherwise saturate at 100 %).
- Tests: `test_deck_rule_unlocks_draw_sooner_and_hold_more`, `test_technique_slot_row_allows_a_fourth`.
- Validation: parse/unsafe/gdlint clean; runner 3465 / 0 / 0 SCRIPT ERROR; balance bands PASS (unchanged).
- Measurement in docs; BID-103 logged (fourth slot power step).

## Documentation Updates

- `docs/agent/starter-zone-and-training.md`: "Deck-rule rows".
