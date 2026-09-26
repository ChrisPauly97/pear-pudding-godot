# GID-135: WoW-Fluid Card Combat

## Objective

Card battles flow like WoW combat: fights happen in the world, turns are snappy, rewards don't interrupt, and encounters match what you see.

## Context

Raised by the user (2026-09-26), inspired by WoW: "key thing will be making card battle feel as fluid as combat in wow does". Approved fight-in-place ("zooming on the world… like Pokémon but still in main world") and asked to reconsider the combat model (spells-first, companions, one enemy vs a summoned board).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-527 | Battle Pacing Audit & Timing Test | agent | pending | — |
| TID-540 | Combat Model Redesign — Hero Spells, Companion Minions, Enemy Packs | agent | pending | — |
| TID-528 | Fight In Place — Camera Zoom Into Battle | agent | pending | TID-527 |
| TID-529 | Snappy Enemy Turns | agent | pending | TID-527 |
| TID-530 | Input Flow — Queued Taps, One-Tap Attack, Auto End Turn | agent | pending | TID-527 |
| TID-531 | In-World Loot & XP Toasts | agent | pending | TID-528 |
| TID-532 | Chain Pulls — Keep Momentum Between Fights | agent | pending | TID-528, TID-531 |
| TID-541 | Enemy Encounters That Match the World | agent | pending | TID-540 |

## Acceptance Criteria

- [ ] Engage→first input and per-turn dead time within the budgets set in TID-527, guarded by a test
- [ ] Solo PvE battles happen over the live world with a camera zoom; PvP/co-op unaffected
- [ ] Routine wins return to play without a blocking result card
- [ ] Combat model doc approved by the user and implemented for enemy encounters
- [ ] Tests, gdlint, unsafe-hits, smoke tests clean
