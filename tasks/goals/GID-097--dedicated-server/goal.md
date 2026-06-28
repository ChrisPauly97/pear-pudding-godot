# GID-097: Dedicated Server Option

## Objective

Add a **dedicated headless server** as an *additional* hosting option — a
non-player authority you run at home (or a VPS) that owns the session + world and
relays PvP — **without changing or replacing** the existing peer-to-peer
listen-server (host-is-a-player) path.

## Context

The user explicitly wants the dedicated server to be **just another option**, not a
replacement: the current "Host Game" (listen server, host is player 1) must keep
working exactly as-is. A dedicated server is attractive for an always-on home box
so players can come and go and the world/session persists independently of any one
player.

Because GID-095 (persistence) and GID-096 (world sync) were built around an
**authority abstraction** rather than "the host player," the dedicated server slots
in as a non-player authority behind the same interfaces. The main new work is the
headless launch path, running the world authoritatively with no local player /
camera / rendering, and adapting PvP (today "host = player idx 0") to a
server-as-referee model where neither connected peer is the simulator.

Internet reachability still relies on **port forwarding + the server's public IP**
(no relay/NAT-punch in this goal — that would be a future Steam transport).

**Out of scope:** matchmaking / global server browser, relay/NAT traversal,
containerized deployment tooling (document the manual run instead).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-352 | Dedicated headless server mode (`--server` launch, non-player authority) | agent | done | GID-095, GID-096 |
| TID-353 | PvP on dedicated server (server-authoritative duel, neither peer simulates) | agent | done | TID-352 |
| TID-354 | Tests + docs (dedicated server + PvP-on-server) | agent | done | TID-352, TID-353 |

## Acceptance Criteria

- [ ] A documented launch (e.g. `godot --headless -- --server [--port N]`) starts a
      server that hosts, loads the shared map, owns the session (GID-095) + world
      sync (GID-096), and runs with no local player, camera, or rendering.
- [ ] Up to 4 clients connect to the dedicated server; per-player characters and
      world progress persist in the session file and resume on reconnect.
- [ ] The existing **listen-server (host-is-player)** path is unchanged and still
      works — verified by its existing smoke tests still passing.
- [ ] PvP works on the dedicated server: two clients duel with the server as
      authority/referee (neither client simulates the canonical state).
- [ ] Server tolerates clients joining/leaving without crashing; logs connects,
      disconnects, and persistence to stdout.
- [ ] Tests + docs updated; manual run instructions (port forward, public IP) in
      the agent doc.
