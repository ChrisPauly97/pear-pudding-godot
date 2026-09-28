# GID-141: Starter Zone & Trainer-Taught Unlocks

## Objective

A new player learns the game one mechanic at a time: a fleshed-out starter zone with simple WoW-style quests, where each level makes one new ability *available* and the player must visit a trainer, read what it does and pay gold to learn it.

## Context

Raised by the user (2026-09-28) after the game-appeal review (`docs/agent/game-appeal.md` §6):

- **Weakness #1 — hooks invisible / too much too fast.** A new game opens with auto-attack, Strike, Mend, Kick, a hand of minion cards, spells, companions, Dig, Phase, Mount, the Skills tab, bounties, Spire and night hunts all available at once, with little explanation.
- **Weakness #4 — uneven visual finish** between older and newer systems, most visible in the first session.

User decisions:
- A core loop of simple quests (like WoW) in a fleshed-out starter zone around Madrian (the world origin, where new games spawn).
- Level-ups add one thing at a time. The player is **forced to go to a trainer** for each new ability, and it **costs gold**, so they read what they are buying.
- Dig and Phase come around level 10; Mount around level 40.
- The starter chain sits between story steps `speak_maiteln` and `leave_madrian` (default proposed; not objected to).

Builds on GID-136 (TID-537 trainer + `learned_abilities` already shipped; TID-533 quest data, TID-534 quest givers and TID-536 zone levels are pending there and are prerequisites here) and GID-140 (QuestLog, tracked quest, NPC "!"/"?" marks).

### Unlock ladder (initial; tuned in TID-587)

| Lvl | Unlock | Trainer |
|---|---|---|
| 1 | Auto-attack + Strike (known) | — |
| 2 | Mend (+ potions) | Combat trainer |
| 3 | Kick | Combat trainer |
| 4 | Minion cards (hand in battle) | Combat trainer |
| 5 | Spells | Combat trainer |
| 6 | Maiteln as companion | Maiteln |
| 7 | Skills tab + magic type | Maiteln |
| 8 | Bounty board | Bounty master |
| 9 | Night hunts | Bounty master |
| 10 | Skeleton Dig | Gravedigger |
| 12 | Ghost Phase | Gravedigger |
| 15 | Endless Spire + card packs | Combat trainer / merchant |
| 40 | Mount | Stablemaster |

Co-op/PvP stay reachable from the main menu. "Head Start (debug)" learns everything.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-533 | *(GID-136)* Quest Data & Registry | agent | pending | — |
| TID-534 | *(GID-136)* Quest-Giver NPCs (accept/turn-in flow) | agent | pending | TID-533 |
| TID-536 | *(GID-136)* Zone Level Ranges & Enemy Levels | agent | pending | — |
| TID-587 | Unlock Ladder Table & XP Curve | agent | pending | — |
| TID-588 | Combat Gates Follow the Ladder | agent | pending | TID-587 |
| TID-589 | World & Menu Gates Follow the Ladder | agent | pending | TID-587 |
| TID-590 | Trainer Flow — Themed Trainers, Level-Up Notice, Learn-for-Gold | agent | pending | TID-588, TID-589 |
| TID-591 | Starter Zone — Madrian Outskirts | agent | pending | TID-536 |
| TID-592 | Starter Quest Chain | agent | pending | TID-534, TID-590, TID-591 |
| TID-593 | First-30-Minutes Visual Finish Audit | agent | pending | TID-591 |
| TID-594 | Visual Finish Fixes | agent | pending | TID-593 |
| TID-595 | Docs | agent | pending | TID-592, TID-594 |
| TID-596 | Spec & Story Update — New-Player Flow | human-action | pending | TID-592 |

## Acceptance Criteria

- [ ] A fresh save starts with only auto-attack + Strike in battle and no Dig/Phase/Mount/Skills/bounty/Spire/pack/night-hunt entry points.
- [ ] Each level-up names the newly available training and which trainer teaches it; the trainer shows a "!" and the compass can point at them.
- [ ] Nothing on the ladder becomes usable until learned at its trainer for gold; the trainer panel shows the full how-to text.
- [ ] Starter-zone quest gold covers each training cost on the intended path without grinding.
- [ ] Starter chain (~10 quests) runs between `speak_maiteln` and `leave_madrian`, each quest exercising the most recent unlock.
- [ ] Existing saves keep everything they already had (no regression for players past the ladder).
- [ ] Worst visual-finish gaps on the first-30-minutes path are fixed; game-appeal §6 #1 and #4 updated.
- [ ] Tests, gdlint, unsafe-hits and scene smoke tests pass.
