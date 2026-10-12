# BID-108: Expected loadout fit and weapon speed

**Category:** balance
**Discovered During:** GID-187 / TID-787

## Description

- `GearDrops.expected_loadout(level, magic_type)` picks, per slot, the best-fitting item within 5 item levels of the
  best wearable one (`FIT_WEIGHTS`). At the top of the legendary band most slots only offer pieces with another
  school's Mastery (both legendary items per slot sit at item level 50 and 59), so a level-59 player wears off-school
  gear. The catalogue needs a Mastery piece per school near the top of each band from Superior up.
- Weapon swing speed moves fights: profiles change weapon type between bands (level 4: a 1.8 s dagger; level 14:
  a 2.6 s blade) and single cells move by ~20 pp (`profiles` duelist adept 14 +1: typical 56 % vs modest 81 %).
  Faster weapons get more per-hit procs (combo, mana siphon, free casts) at the same DPS.

## Suggested Resolution

Add school-matched items near each band's top; check whether per-hit effects should scale with swing time.
