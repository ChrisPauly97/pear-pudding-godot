# GID-072: World Layer Decomposition

## Objective

Decompose the 1,678-line WorldScene.gd god file into focused components and unify the duplicated entity-spawning paths between named maps and infinite chunks.

## Context

WorldScene.gd (scenes/world/WorldScene.gd) carries 9 responsibility clusters per the June 2026 simplification audit: chunk streaming (~273 lines, 16%), dungeon session UI (~245 lines), HUD wiring (~200 lines), interaction handling (~215 lines), day/night (~100 lines), entity spawning, camera, and setup. NPC and scroll spawning are duplicated between WorldScene and ChunkRenderer (only enemies/chests/doors went through TerrainMath.spawn_entity). Six entity scripts under scenes/world/entities/ share ~40–50 lines of identical static-resource/mesh boilerplate each.

**IMPORTANT coordination note:** GID-064 tasks TID-230/TID-231 (chunk streaming correctness & performance) are pending and touch the same code — whichever goal runs second must re-verify line numbers and behavior.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-266 | Extract ChunkStreamingManager | agent | done | — |
| TID-267 | Extract DungeonSessionUI and WorldHUD | agent | done | TID-266 |
| TID-268 | Extract DayNightCycle and interaction handling | agent | done | TID-267 |
| TID-269 | Unify entity spawning and add WorldEntity base class | agent | done | TID-266 |

## Acceptance Criteria

- [ ] WorldScene.gd shrinks to roughly 600–800 lines of orchestration
- [ ] Named-map and infinite-chunk play are visually and behaviorally unchanged
- [ ] NPC and scroll spawning have a single implementation path
- [ ] Entity scripts share a base class and eliminate boilerplate duplication
- [ ] All tests pass headless (`godot --headless --path . -s tests/runner.gd`)
