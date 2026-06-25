# GID-095: Persistent Multiplayer Sessions & Per-Player Progress

## Objective

Give each multiplayer server a **persistent session**: shared world progress plus
a **per-player character** (inventory, deck, level, skills) that is *scoped to that
session* and resumes when the same player reconnects.

## Context

Today co-op persists nothing — it uses a transient in-memory deck
(`SaveManager.ensure_coop_deck`) and syncs no progress back to disk. The user
wants multiplayer progress to be **per-player but bound to the multiplayer
session**: your character on a given server (inventory, deck, level, skills) is its
own save, separate from single-player, and reconnecting to the same session
resumes the same character alongside the same world progress and the same players.

The persistence is owned by the **authority** — in the listen-server model that is
the host. This goal builds and ships on the existing host-is-authority P2P path;
GID-097 later reuses the same session/persistence interfaces for a non-player
dedicated server, so nothing here is server-specific. The per-player character is
keyed by the **identity token** from GID-094 (TID-342).

This is the backbone for "host a server at home and have people rejoin the same
world with their same characters."

**Out of scope here:** the dedicated-server process (GID-097) and the enemy/chest
*live* sync (GID-096) — though chest/loot *persistence* slots into the session file
this goal defines (TID-350 in GID-096 depends on it).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-345 | Session model + persistence file (`SessionState` pure logic + authority-side save/load) | agent | pending | GID-094 |
| TID-346 | Per-player character handshake & session-scoped progress (adopt + persist back) | agent | pending | TID-345 |
| TID-347 | Reconnection + recent-servers list + join-by-address + public-IP/port-forward guidance | agent | pending | TID-345 |
| TID-348 | Tests + docs (persistence, handshake, reconnect) | agent | pending | TID-345, TID-346, TID-347 |

## Acceptance Criteria

- [ ] The authority persists a **session file** containing shared world progress
      (map, defeated enemies, opened chests, day/night, seed) and a roster of
      **per-member character records** keyed by player token.
- [ ] On join, a player's token is matched to an existing member record (resume) or
      a new one is created (seeded starter character); the authority sends the
      character state and the client adopts deck/inventory/level/skills for the
      session.
- [ ] Per-player progress changes during the session are persisted back to the
      session file (dirty-flag batched, like `SaveManager`).
- [ ] Reconnecting with the same token resumes the same character + position and
      the same world progress — verified by a smoke test.
- [ ] A client keeps a **recent-servers** list and can rejoin a known server by
      address; join-by-address + public-IP/port-forward guidance is presented.
- [ ] Single-player `save.json` is never read or written by session persistence;
      the two are fully isolated.
- [ ] Tests + `docs/agent/multiplayer-coop.md` updated.
