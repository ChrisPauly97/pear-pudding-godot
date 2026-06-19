# GID-057: Dungeon Secrets & Mimics

## Objective

Seeded secret rooms behind cracked dungeon walls, plus mimic chests that ambush the player — making dungeons reward observation and adding a spike of danger to routine looting.

## Context

Dungeons are corridors with an exit — nothing rewards looking closely. Secret rooms give observant players bonus loot; mimics make chest-opening occasionally dangerous. Both are seeded from the dungeon seed, so each dungeon is deterministic per save.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-207 | DungeonGen secret rooms: seeded hidden room behind a cracked-wall tile (~30% of dungeons) | agent | done | — |
| TID-208 | Cracked-wall visual tell + break-open interaction + reveal | agent | done | TID-207 |
| TID-209 | Mimic chests: seeded chance a chest is a battle in disguise, boosted loot on victory | agent | done | — |

## Acceptance Criteria

- ~30% of generated dungeons (decided by the dungeon seed) contain a small secret room adjacent to a corridor, sealed by a cracked-wall tile, containing a bonus chest; generation is deterministic per seed and never breaks dungeon connectivity or the exit path
- The cracked wall renders subtly different from normal walls (visible but easy to miss); interacting with it breaks it open with a particle/sound effect and converts it to floor, permanently for that dungeon visit
- ~15% of dungeon chests (seeded) are mimics: opening one starts a battle against a mimic enemy instead of granting loot; winning grants the chest's loot at a boosted rarity tier plus bonus coins; the mimic battle uses the standard battle flow
- Mimic state and broken walls don't need cross-session persistence beyond what dungeons already have (check how dungeon state persists between entries and match it)
- Mobile parity: the cracked wall break uses the existing interact flow (tap prompt)
- All tests pass headless
