# TID-343: Tests + docs for foundations

**Goal:** GID-094
**Type:** agent
**Status:** pending
**Depends On:** TID-341, TID-342

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
