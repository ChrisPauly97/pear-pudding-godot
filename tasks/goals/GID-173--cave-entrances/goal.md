# GID-173: Cave Entrances

## Objective

Replace ruin dungeon doors with cave entrances cut into rocky hills, leading to cave-themed interiors.

## Context

User wants cave entrances "as opposed to dungeon ruins". Today ~33% of chunks get a ruin whose wall openings are DOOR entities to `dungeon_<seed>` (`InfiniteWorldGen._gen_ruins`, ~line 279). Default chosen (user did not object): ruins stay as scenery without doors; caves become the way underground.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-699](TID-699--cave-sites.md) | Cave site placement (pure logic) | agent | done | — |
| [TID-700](TID-700--cave-mouth.md) | Cave mouth visuals + door | agent | done | TID-699 |
| [TID-701](TID-701--cave-interiors.md) | Cave interior theme for DungeonGen | agent | pending | — |
| [TID-702](TID-702--retire-ruin-doors.md) | Retire ruin dungeon doors, tests & docs | agent | pending | TID-700, TID-701 |

## Acceptance Criteria

- [x] Cave site placement (pure logic)
- [x] Cave mouth visuals + door
- [ ] Cave interior theme for DungeonGen
- [ ] Retire ruin dungeon doors, tests & docs
- [ ] Tests, gdlint and unsafe-hits clean; agent docs updated
