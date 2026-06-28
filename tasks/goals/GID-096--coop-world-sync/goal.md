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
| TID-349 | Authoritative enemy & encounter sync (spawns/positions/defeat) | agent | done | GID-094 |
| TID-350 | Chest / loot / world-object state sync + persist into session file | agent | done | GID-095, TID-349 |
| TID-351 | Tests + docs (world sync) | agent | done | TID-349, TID-350 |
| TID-352 | Make avatar sync map-aware (no cross-map ghosts) | agent | done | GID-094 |

## Acceptance Criteria

- [x] Enemies are spawned/owned by the authority and rendered by all clients;
      positions/AI state sync smoothly (interpolated like avatars); defeat is
      reflected for everyone. *(Enemies spawn deterministically from the shared map on
      every peer — positions identical by construction; an `EnemySync` interp stream
      handles future moving enemies. Defeat/engage reflected for all via the authority.)*
- [x] A battle one player triggers does not desync the others. **Rule: engage-locks /
      first-engager-takes** — the engager fights solo vs AI; the enemy is removed for all
      on engage; a win persists the defeat, a loss returns it on reconnect. Documented in
      `multiplayer-coop.md`.
- [x] Chest open state syncs so opening one reflects for all players, and persists into
      the GID-095 session file (resumes on reconnect). **Loot rule: first-opener-takes.**
      Dig spots are per-player (treasure-map state) and intentionally excluded.
- [x] Single-player enemy/chest behavior is unchanged when no session is active — every
      new path is guarded by `_coop_active`; full unit suite (1603) still passes.
- [x] Avatar sync is map-scoped: a remote avatar only renders for peers on the same
      map; peers on different maps don't show cross-map ghosts (the single-map
      contract is enforced in the sync layer, not just at entry). *(TID-352 — `map` in the
      AvatarSync payload + receive-side filter; off-map peers hidden + rostered "(elsewhere)".)*
- [x] Tests pass: `test_world_sync.gd` (18 unit cases) + `net_world_sync_smoke.gd`; headless
      import clean; docs updated.

> **Implementation note:** co-op currently lands only on **madrian**, a town map with no
> enemies/chests, so the sync is dormant *in practice* there — the system is map-agnostic
> and verified end-to-end with synthetic ids by `net_world_sync_smoke.gd`. Logged as
> BID-024 (consider a co-op-reachable map with enemies/chests, or a co-op-enabled dungeon).
