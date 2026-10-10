# TID-774: Feature rows grant cards

**Goal:** GID-185
**Type:** agent
**Status:** done
**Depends On:** —

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

1. `UnlockLadder.FEATURE_CARDS` + `MAGIC_STARTER_CARDS`, `cards_for(id, magic_type)`.
2. `SaveManager._grant_ladder_cards()` + persisted `ladder_cards_granted`; hook learn, load, new game, magic type.
3. Trainer row "Grants:" chips opening card faces; learn tip names the cards.

## Changes Made

- `game_logic/progression/UnlockLadder.gd`: `FEATURE_CARDS`, `MAGIC_STARTER_CARDS`, `cards_for`.
- `autoloads/SaveManager.gd`: `ladder_cards_granted` field (+ PERSISTED_FIELDS), `_grant_ladder_cards`, hooks in `learn_ability`, `_restore_derived_fields`, `new_game`, `set_magic_type`.
- `scenes/world/modules/NpcInteractions.gd`: `_trainer_card_row`, `_card_names`, learn tip.
- Tests: 3 new in `test_unlock_ladder.gd`; `test_technique_learning` feature test now expects the cards.
- Validation: parse clean, unsafe-hits clean, gdlint clean, runner 3463 / 0 / 0 SCRIPT ERROR, world_scene_smoke exit 0 / 0 errors.

## Documentation Updates

- `docs/agent/starter-zone-and-training.md`: "Feature rows grant cards".
