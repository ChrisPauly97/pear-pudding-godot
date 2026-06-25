# GID-096: Co-op World State Sync

## Objective

Make the shared world actually shared: sync **enemies/encounters** and
**chests/loot/world-objects** from the authority to all players, and persist their
state into the session file so the world resumes on reconnect.

## Context

Co-op currently syncs only player avatars and PvP duels. Enemies, chests, dig
spots, and other world objects are single-player-only — invisible to partners and
not shared. The user wants combat encounters and lootable world state to be common
to everyone in the session.

The authority (host now; dedicated server in GID-097) owns the canonical world
state and broadcasts it; clients render it but don't simulate it — the same
host-authoritative model PvP already uses (GID-091). Object state that should
survive a reconnect (defeated enemies, opened chests) persists into the
**session file** defined in GID-095.

This goal is built on the listen-server authority and works unchanged when the
dedicated server becomes the authority in GID-097.

**Out of scope:** NPC dialogue/story sync, inventory sync (that's the per-player
character in GID-095), the infinite chunk world (co-op stays on finite named maps).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-349 | Authoritative enemy & encounter sync (spawns/positions/defeat) | agent | pending | GID-094 |
| TID-350 | Chest / loot / world-object state sync + persist into session file | agent | pending | GID-095, TID-349 |
| TID-351 | Tests + docs (world sync) | agent | pending | TID-349, TID-350 |

## Acceptance Criteria

- [ ] Enemies are spawned/owned by the authority and rendered by all clients;
      positions/AI state sync smoothly (interpolated like avatars); defeat is
      reflected for everyone.
- [ ] A battle one player triggers does not desync the others (define the rule:
      e.g. authority marks the enemy engaged; document the chosen behavior).
- [ ] Chest open state, dig spots, and other interactable world objects sync so
      opening one reflects for all players, and the state persists into the GID-095
      session file (resumes on reconnect).
- [ ] Single-player enemy/chest behavior is byte-for-byte unchanged when no session
      is active.
- [ ] Tests (unit for any pure sync helpers + a smoke test for enemy/chest sync)
      pass; headless import clean; docs updated.
