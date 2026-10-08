# BID-095: Chapter 1 enemy types spread widely one level up

**Category:** balance
**Discovered During:** GID-176 / TID-718

## Description

With the TID-718 global tuning, every Chapter 1 type is beaten ~100 % at the same level, but one level up the types disagree: `ghoul_pack` wins 23–40 % (its two 4/3 ghouls out-trade a level-3–5 hero), while `undead_basic` / `undead_horde` stay at 100 % (the horde is leaderless, so `gap_hp` never applies). Global knobs move every type together, so this needs per-type content tuning.

## Evidence

`bash tools/balance_matrix.sh` — table in `docs/agent/balance-sim.md` ("After TID-718").

## Suggested Resolution

Soften `ghoul_pack`'s pack (e.g. one ghoul + two zombies) and give leaderless packs a gap lever (scale pack unit health by `gap_hp`). Re-run the matrix; TID-717's CI bands should then cover every type.
