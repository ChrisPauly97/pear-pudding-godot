# BID-102: Pure mono-school decks still uneven

**Category:** balance
**Discovered During:** GID-184 / TID-773

## Description

After GID-184 the school-*matched* decks are all within band (a) in neutral matchups, but pure mono-school decks
(`--sweep school=`) still swing widely: light 36 % and verdant 36 % on the bog hag (neutral for light) while
physical wins 100 %; every deck loses the scorched revenant cell at level 6 +1.

## Evidence

`docs/agent/balance-sim.md` → Mono-school decks (GID-184 re-check): scout 100/93/64/100/100, bog hag 100/36/43/36/79,
revenant 14/0/0/36/14 (physical/light/dark/verdant/rift).

## Suggested Resolution

Measure mono decks at 60 fights per cell, then tune light/verdant Ally stats (cards first, enemy profiles last).
Add a report-only mono band once the spread is under ~30 pp.
