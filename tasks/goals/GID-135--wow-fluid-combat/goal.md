# GID-135: WoW-Fluid Card Combat

## Objective

Card battles flow like WoW combat: real-time parallel combat on per-combatant global cooldowns, fights happen in the world, rewards don't interrupt, and encounters match what you see.

## Context

Raised by the user (2026-09-26), inspired by WoW: "key thing will be making card battle feel as fluid as combat in wow does". Approved fight-in-place ("zooming on the world… like Pokémon but still in main world") and asked to reconsider the combat model (spells-first, companions, one enemy vs a summoned board).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-527 | Battle Pacing Audit & Timing Test | agent | done | — |
| TID-540 | Combat Model Redesign — Hero Spells, Companion Minions, Enemy Packs | agent | done | — |
| TID-544 | Terminology — Mentor, Ally, Minion | agent | pending | TID-540 |
| TID-545 | Hero Kit — Weapon Auto-Attack, Ally Cap, Faster Start | agent | pending | TID-540, TID-546 |
| TID-546 | Real-Time Combat Prototype | agent | review | TID-540 |
| TID-547 | Real-Time Combat — Full Mode | agent | pending | TID-546 |
| TID-548 | Remote Attack Replay in Multiplayer Battles | agent | done | — |
| TID-528 | Fight In Place — Camera Zoom Into Battle | agent | done | TID-527 |
| TID-529 | Snappy Enemy Turns | agent | superseded | TID-527 |
| TID-530 | Input Flow — Spell Queue & One-Tap Targeting | agent | pending | TID-546 |
| TID-531 | In-World Loot & XP Toasts | agent | pending | TID-528 |
| TID-532 | Chain Pulls — Keep Momentum Between Fights | agent | pending | TID-528, TID-531 |
| TID-541 | Enemy Encounters That Match the World | agent | pending | TID-540 |

## Acceptance Criteria

- [ ] Solo PvE battles run in real time (GCD per combatant, swing timers, enemy cast telegraphs), guarded by tests
- [ ] Engage→first input within the budget set in TID-527, guarded by a test
- [ ] Solo PvE battles happen over the live world with a camera zoom; PvP/co-op unaffected
- [ ] Routine wins return to play without a blocking result card
- [ ] Combat model doc approved by the user and implemented for enemy encounters
- [ ] Tests, gdlint, unsafe-hits, smoke tests clean
