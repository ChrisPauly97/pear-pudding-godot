# GID-185: Unlocks Grant Cards & Expand the Deck

## Objective

Bring `UnlockLadder` in line with the spec's Identity rule ("Progression grants cards; unlocks expand what a deck
can do — size, draw, mulligan — never bypass it"). Every feature row grants cards, and new ladder rows grow the
deck's rules instead of adding non-card systems.

## Context

- User decision (2026-10-10): "Cards + deck-expansion unlocks" — feature rows grant themed cards; new rows for hand
  size, draw speed, mulligan and technique slots (3 → 4).
- Ladder: `game_logic/progression/UnlockLadder.gd`; learning: `SaveManager.learn_ability`; trainer panel:
  `scenes/world/modules/NpcInteractions.gd` (`_trainer_row`). Real-time rules: `RealtimeCombat`, `BattleSetup.configure_realtime`,
  `CombatTuning` (`hand_cap` 5, `draw_interval` 9 s). Technique cap: `TechniqueDefs.DECK_MAX` / `deck_violation`.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-774 | Feature rows grant cards | agent | done | — |
| TID-775 | Deck-rule rows: technique slot, hand size, draw speed | agent | done | TID-774 |
| TID-776 | Redraw (mulligan) row | agent | done | TID-775 |

## Acceptance Criteria

- [x] Learning any feature row grants its cards once (old saves get them once on load); the trainer row names them and opens their faces
- [x] Technique slot, hand size and draw speed rows change the deck's rules in real-time fights and the balance sim
- [x] Redraw: once per fight at the start, swap the opening hand (touch + keyboard)
- [x] Docs (`starter-zone-and-training.md`, `combat-model.md`) and the spec-facing rule hold; tests and balance bands pass
