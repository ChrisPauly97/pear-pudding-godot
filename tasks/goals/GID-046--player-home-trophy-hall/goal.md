# GID-046: Player Home & Trophy Hall

## Objective

A purchasable house in madrian — a big coin sink — whose interior displays auto-earned trophies for major feats and offers a bed that heals and sets the respawn point.

## Context

Coins accumulate with few large sinks. A house gives the economy a big-ticket goal, and trophies make the feats of GID-037 (champion), GID-038 (Spire) and boss kills physically visible. Intentionally small scope: one interior map, fixed trophy pedestals, no decoration placement.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-173 | House purchase flow + interior map + door gating | agent | done | — |
| TID-174 | Trophy framework: feats from save data rendered as pedestal entities | agent | done | TID-173 |
| TID-175 | Bed rest: heal + set respawn point used by game-over flow | agent | done | TID-173 |

## Acceptance Criteria

- [ ] A house door in madrian is locked with a "For Sale" prompt until purchased; buying (suggested 500 coins, tune against the GID-007/GID-028 economy) persists `home_owned` in SaveManager with migration
- [ ] The interior is a new bundled map `.tres` registered in MapRegistry (preload + _BUNDLED + .uid sidecar per CLAUDE.md), entered and exited via the existing door/map-stack flow
- [ ] Trophies are defined as data (id, display name, save-data predicate); on interior load, earned trophies appear on fixed pedestals, unearned pedestals sit empty; at least 3 trophies exist (regional champion, Spire floor 7+, first boss defeated — adjust to real save fields)
- [ ] Interacting with the bed heals the player and sets the respawn point; after a game over, the player respawns at home if owned and rested, instead of the default location
- [ ] Mobile parity: purchase, door, trophy inspect, and bed interactions all work via the existing touch interact flow
- [ ] All tests pass headless
