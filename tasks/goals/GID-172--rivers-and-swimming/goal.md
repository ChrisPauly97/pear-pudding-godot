# GID-172: Rivers & Swimming

## Objective

Add real rivers that run from the mountains to the eastern sea, and let the hero swim deep river and sea water, with stamina that runs out far from shore.

## Context

User: "Lets add real rivers, perhaps with swimming animations? Same for ocean you can swim but if you go too far you will die from tiredness." Today inland water is only thin wadeable streams/ponds (`WaterMath`, GID-134) and deep sea simply blocks the hero (`Coastline`, GID-171). Decision (user): drowning = wash up on the nearest shore at 1 HP, no other penalty.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-694](TID-694--river-courses.md) | River courses (pure logic) | agent | done | — |
| [TID-695](TID-695--river-rendering-bridges.md) | River rendering, banks & bridges | agent | pending | TID-694 |
| [TID-696](TID-696--swimming.md) | Swimming state + swim animation | agent | pending | TID-694 |
| [TID-697](TID-697--swim-stamina-drowning.md) | Swim stamina, currents & drowning | agent | pending | TID-696 |
| [TID-698](TID-698--rivers-coop-tests-docs.md) | Co-op sync, tests & docs | agent | pending | TID-695, TID-697 |

## Acceptance Criteria

- [x] River courses (pure logic)
- [ ] River rendering, banks & bridges
- [ ] Swimming state + swim animation
- [ ] Swim stamina, currents & drowning
- [ ] Co-op sync, tests & docs
- [ ] Tests, gdlint and unsafe-hits clean; agent docs updated
