# GID-177: Progression Pacing

## Objective

Make levelling much slower and steadier: about 10 minutes for level 1, longer for each level after, and a few quests per level from level 3.

## Context

User (2026-10-08): "level up should be much slower, we're not in a rush to level 10"; "few quests per level from level 3+"; "10 mins for lvl 1, graduating up". Today level 10 needs 5000 XP and the starter chain gives about one quest per level, so players race through.

**Pacing targets (user, 2026-10-08):**
- Levelling is much slower; there's no rush to level 10.
- Level 1 takes about **10 minutes** of play, and each level after takes longer ("graduating up"). Working model: +5 min per level, so L1 10, L2 15, L3 20 … L9 50 min, about 4.5 h to level 10. Confirm the step when the first numbers are in.
- From level 3 on, a level takes **a few quests** (about 3–4) plus the kills along the way.

Unchanged unless the user says otherwise: the UnlockLadder (one system per level, 2–10; slower levels spread unlocks out in time); Chapter 1 = levels 1–10 over story-route zones (GID-176 / TID-719): Madrian outskirts 1–5, South road 4–7, Farsyth / Isfig 6–9, Blancogov approach 8–10.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-721](TID-721--xp-curve.md) | XP curve to the pacing targets + save migration | agent | done | — |
| [TID-722](TID-722--more-quests.md) | Camps and repeatable quests across Chapter 1's zones | agent | done | TID-721, GID-176/TID-719 |
| [TID-723](TID-723--pacing-retune.md) | Re-tune quest / kill XP and gold to the new curve; pacing test | agent | pending | TID-721, TID-722 |

## Acceptance Criteria

- [ ] Level 1 ≈ 10 min of play, each later level longer (time model test)
- [x] Enough quests available from level 3 (3–4 per level sizing: TID-723)
- [x] Existing saves keep their level
- [ ] Training stays affordable on time; tests, gdlint and unsafe-hits clean; docs updated
