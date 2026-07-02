# GID-105: Party Convenience & Stakes — Rally Travel and Dungeon Rescue

## Objective

Remove the friction of regrouping with your party and add real shared stakes to co-op dungeon runs.

## Context

In co-op multiplayer sessions, players frequently split across maps (exploring different waystones, exiting dungeons early, hitting different doors). Today there is no way to converge on a friend — co-op becomes frustrating as players manually navigate back to each other or abandon the session. Additionally, shared dungeon crawls (TID-380) have no penalty structure: a player who loses a PvE battle inside the dungeon is ejected to the single-player defeat screen, breaking the party's run and removing any shared stakes. Rally travel (teleporting to a connected party member) and downed/rescue mechanics (falling in a dungeon invites teammates to revive you) make co-op feel cohesive and tactically rewarding.

Related design patterns: fast-travel UI (GID-044, docs/agent/waystone-fast-travel.md), shared dungeon generation (TID-380, docs/agent/multiplayer-coop.md), multi-map transitions (TID-355), battle loss routing (docs/agent/player-home.md).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-388 | Rally waystones (teleport to party) | agent | pending | — |
| TID-389 | Downed & rescue in shared dungeons | agent | pending | — |

## Acceptance Criteria

- [ ] A player can teleport to any connected party member from the fast-travel UI, same-map and cross-map
- [ ] A PvE loss inside a shared dungeon leaves the player downed and revivable by a teammate instead of ending their run
- [ ] Solo fallback: after timeout or all-downed, player respawns at the dungeon entrance
- [ ] Single-player battle flow unchanged
- [ ] Unit test suite passes
- [ ] Headless import clean (no parse errors)
