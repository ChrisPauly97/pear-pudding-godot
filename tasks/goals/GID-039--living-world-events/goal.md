# GID-039: Living World Events

## Objective

A lightweight event scheduler that periodically fires three visible world events — a roaming boss, a traveling merchant, and a card shower — giving the infinite world a heartbeat.

## Context

The infinite world is scenery between battles; nothing happens without player action. Timed events give players reasons to re-explore loaded chunks and create "drop everything" moments. The framework is a single new autoload; each event reuses an existing entity (EnemyNPC, MerchantNPC, WorldItem).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-151 | WorldEventManager autoload + save fields + GameBus signals | agent | done | — |
| TID-152 | Roaming boss event + minimap marker | agent | done | TID-151 |
| TID-153 | Traveling merchant event with rotating rare stock | agent | done | TID-151 |
| TID-154 | Card shower event with particle burst | agent | done | TID-151 |

## Acceptance Criteria

- [ ] WorldEventManager fires registered events on randomized intervals, persisted in `SaveManager.world_events` so cooldowns survive restarts
- [ ] A boss-tier enemy spawns near the player on its interval, appears as a red dot on the minimap, and drops a rare card on defeat
- [ ] A traveling merchant spawns with 3 seeded rare/legendary cards for sale and despawns after a timeout
- [ ] A card shower scatters 5–10 collectible WorldItem pickups around the player with a particle burst; uncollected items despawn after 60s
- [ ] Events only fire in the infinite world (not named maps or dungeons)
- [ ] All tests pass headless
