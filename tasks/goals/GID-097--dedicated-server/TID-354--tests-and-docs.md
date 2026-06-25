# TID-354: Tests + docs (dedicated server + PvP-on-server)

**Goal:** GID-097
**Type:** agent
**Status:** pending
**Depends On:** TID-352, TID-353

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Verify the dedicated server and server-refereed PvP, and document how to run it.

## Research Notes

_To be expanded as the goal lands._

- **Smoke (real sockets):**
  - `tests/net_dedicated_server_smoke.gd` — boot a server-mode authority (no
    player), connect 2 clients, confirm avatars + session persistence + world sync
    work and the server survives a client leaving.
  - `tests/net_pvp_dedicated_smoke.gd` — two clients duel through the server
    referee; intents from both apply; both receive the state mirror.
- **Regression:** the existing `net_coop_smoke`, `net_rehost_smoke`, `net_pvp_smoke`,
  `net_pvp_client_smoke` (listen-server paths) must still pass — proves the
  dedicated server is additive.
- **Unit:** any new pure helpers (e.g. cmdline arg parsing extracted to a static
  func) get a unit test.
- Validation gate: headless import clean, `tests/runner.gd` exits 0.
- **Docs:** update `docs/agent/multiplayer-coop.md` — dedicated-server section with
  the exact launch command, port-forward + public-IP instructions for internet
  play, the authority abstraction, and the server-refereed PvP model. Add test rows.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
