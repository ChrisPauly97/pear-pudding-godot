# GID-094: Multiplayer Foundations — N-Player Capacity & Identity

## Objective

Raise co-op from a hard-coded 2-player slice to **up to 4 players**, generalize
avatar sync to N peers, and give every player a **display name + color** plus a
stable per-player **identity token** that later goals key persistence to.

## Context

The shipped co-op slice (GID-090/091) is deliberately capped at 2 players
(`NetworkManager.MAX_PEERS = 1`) and players are anonymous blue avatars. The user
wants a maturer multiplayer with **up to 4 players**, named/colored avatars, and
persistent session-scoped progress (GID-095) that follows a player across
reconnects. That persistence needs a stable identity key, so identity is
established here first.

This goal is **purely additive** and changes no single-player code. It is the
foundation for GID-095 (persistent sessions), GID-096 (world sync), and GID-097
(dedicated server) — all of which assume N peers and a player identity token.

The current 2-player assumptions to undo: `MAX_PEERS = 1`; the "+2 tiles over"
non-host spawn nudge (per `_spawn_remote_player`); and any place that assumes a
single remote peer. The remote-avatar registry (`_remote_player_nodes`) is already
a `peer_id → node` dict, so N-peer rendering is mostly a capacity + spawn-offset +
discovery-count change rather than a rewrite.

**Out of scope here:** persistence, reconnection, dedicated server, world-object
sync — those are GID-095/096/097.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-341 | Raise player cap to 4 + generalize avatar sync to N peers | agent | done | — |
| TID-342 | Player identity — display name + color + stable token | agent | done | TID-341 |
| TID-343 | Tests + docs for foundations | agent | pending | TID-341, TID-342 |
| TID-344 | Update spec multiplayer scope (human-owned spec); resolves BID-022 | human-action | pending | — |

## Acceptance Criteria

- [ ] Up to 4 players can be in one session (`MAX_PEERS = 3`); each renders the
      other three as distinct avatars that spawn on connect and free on disconnect.
- [ ] Remote avatars no longer collide at a single fixed +2 offset — spawn
      placement fans out deterministically so N avatars don't stack.
- [ ] Each player sets a **display name** and **color** in the lobby; both are
      transmitted on connect and shown as a label + tint above each remote avatar
      and in a lobby/session roster.
- [ ] Each player has a **stable identity token** (persisted locally, generated
      once) that is transmitted on connect — the key GID-095 uses to match a
      returning player to their saved character.
- [ ] Name/color default is remembered between launches.
- [ ] Unit tests cover identity payload encode/decode and N-peer spawn fan-out;
      headless import is clean; `tests/runner.gd` exits 0.
- [ ] `docs/agent/multiplayer-coop.md` updated; spec scope updated (TID-344).
