# TID-775: Deck-rule rows: technique slot, hand size, draw speed

**Goal:** GID-185
**Type:** agent
**Status:** pending
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

## Changes Made

## Documentation Updates
