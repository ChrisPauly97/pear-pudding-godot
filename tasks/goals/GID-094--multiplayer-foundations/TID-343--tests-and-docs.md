# TID-343: Tests + docs for foundations

**Goal:** GID-094
**Type:** agent
**Status:** done
**Depends On:** TID-341, TID-342

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

> Completed in a single short session on `claude/work-task-multiplayer-h83xbq`;
> lock not held separately (low risk, no contention).

## Context

Lock in the N-peer + identity work with tests and update the agent docs, following
the testing pattern established by GID-090/091.

## Research Notes

**Unit suite (auto-run):** mirror `tests/unit/test_coop_sync.gd` /
`tests/unit/test_pvp_protocol.gd`. Add:
- `tests/unit/test_player_identity.gd` — `PlayerIdentity.encode/decode` round-trip,
  defaulting on garbage input, color round-trip.
- Spawn fan-out: a pure helper for the per-`peer_id` offset (TID-341) so it can be
  unit-tested without a scene — assert N distinct peer_ids map to N distinct
  offsets / non-overlapping tiles.
Register new tests where the runner auto-discovers them (see existing unit folder
registration).

**Smoke (on-demand, real sockets):** extend or add alongside
`tests/net_coop_smoke.gd` — connect 3+ loopback peers, confirm each sees the
others' avatars and identity packets. Run with
`godot --headless --path . -s tests/<file>` (exit 0 = pass). Not in the auto suite
(needs real sockets + frame polling).

**Validation gate (CLAUDE.md):** run the headless editor import and grep for
Parse/Compile/Failed-to-load errors before committing. Run `tests/runner.gd`
(exit 0). Install Godot per CLAUDE.md "Running Tests: Installing Godot" if absent.

**Docs:** update `docs/agent/multiplayer-coop.md` — bump the status line (no longer
"2 players max", "anonymous avatars"), document the identity handshake + token,
N-peer capacity, spawn fan-out, and add new test rows. Keep the CLAUDE.md doc-table
row accurate.

## Plan

The unit tests and most docs for this goal were already delivered with the work
they cover (TID-341 added `spawn_offset` + its 5 unit cases and a pure helper;
TID-342 added `tests/unit/test_player_identity.gd` (10 cases) and the identity/
roster docs). The outstanding gap is the **N-peer smoke test** the research note
calls for. So: add a 3+ peer loopback smoke test, finish the docs, validate, commit.

## Changes Made

**New smoke test — `tests/net_coop_npeer_smoke.gd`** (+ `.uid`, on-demand): spins up
a real 3-peer ENet loopback session (host + 2 clients, `max_clients = 3`) and asserts
(1) all three connect, (2) a host avatar broadcast reaches both clients, and (3) a
**client→client** identity packet is delivered. Point (3) is the important one — in
ENet client-server clients aren't directly connected, so client↔client visibility
relies on Godot's `SceneMultiplayer.server_relay` (host relays). This proves the
mechanism the up-to-4-player rendering depends on, and round-trips a `PlayerIdentity`
payload. **PASS** (exit 0).

Unit coverage required by this task was already in place from the earlier tasks:
`test_coop_sync.gd` (spawn fan-out, TID-341) and `test_player_identity.gd` (TID-342).
Confirmed: headless import clean, `tests/runner.gd` 1572 pass / 0 fail, `net_coop_smoke`
+ `net_coop_npeer_smoke` PASS.

## Documentation Updates

- `docs/agent/multiplayer-coop.md`: added the `net_coop_npeer_smoke.gd` test row and
  a **server-relay note** in the position-sync section explaining why a client's
  broadcast reaches other clients (the host relays) — the basis for N-peer visibility.
- `CLAUDE.md`: refreshed the multiplayer-coop doc-table row to mention up-to-4
  players, named/colored identity, spawn fan-out, and the session roster.
- (Identity/roster/N-peer narrative docs were written in TID-341/342.)
