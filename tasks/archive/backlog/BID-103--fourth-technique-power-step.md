# BID-103: The fourth technique slot is a large power step

**Category:** balance
**Discovered During:** GID-185 / TID-775

## Description

`feat_tech_slot` (level 20) lets a deck hold four techniques. In the balance sim (player 7 vs enemy 9, 60 fights)
the default deck's fourth technique (Ember Lance) lifts the scout cell 70 → 97 % and the bog hag cell 22 → 92 %. The
spec favours horizontal progression over raw power, so a single unlock this strong may need tuning.

## Evidence

`docs/agent/starter-zone-and-training.md` → Deck-rule rows (measurements). Measured at level 7 for comparability;
at level 20+ the enemy zone levels differ.

## Suggested Resolution

Measure at levels 20–25 with a level-appropriate deck, then either raise the row's level, make the fourth slot
accept only 0-cost/utility techniques, or lengthen recycle times when four techniques are slotted.

## Resolution (GID-187 / TID-779)

Measured with the typical profile at levels 26, 36 and 40 (the `rewards` coverage section, `tech_slot` axis,
24 paired fights per cell against a harder enemy): with vs without the fourth slot 50 / 46, 42 / 54, 75 / 67 %,
mean +0 pp. At the levels where the row is learned, with gear and a skill build, the slot is no longer a large
step. The section caps it (no must-have) and exempts it from the "must help" minimum (it is a deck rule).
