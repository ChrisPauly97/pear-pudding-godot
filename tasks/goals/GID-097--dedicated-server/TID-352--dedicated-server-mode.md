# TID-352: Dedicated headless server mode

**Goal:** GID-097
**Type:** agent
**Status:** pending
**Depends On:** GID-095, GID-096

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Add a headless, non-player server launch path that hosts a session and owns the
world + persistence authority, without rendering, a local player, or a camera —
strictly additive to the existing listen-server path.

## Research Notes

_To be expanded when GID-095 + GID-096 land._

- **Launch detection:** parse `OS.get_cmdline_user_args()` / `OS.get_cmdline_args()`
  for `--server` (+ optional `--port`, `--map`, `--session-id`). A bootstrap
  autoload or the main scene checks this early and, if set, routes to a server boot
  path instead of MenuScene. Document the exact invocation
  (`godot --headless -- --server`).
- **Server boot:** `NetworkManager.host(client_count = 4)` (the param added in
  TID-341 so the server allows 4 clients vs the listen-server's 3), then load the
  shared map as authority. Reuse the GID-095 session-load + GID-096 world-sync
  authority code unchanged — that's the whole point of the authority abstraction.
- **No-player guard:** WorldScene must run as authority **without** spawning a local
  Player/camera/HUD when in server mode. Add a `headless/server` flag so
  `_spawn_player`, camera follow, input, and rendering-only systems are skipped. Be
  careful: lots of co-op code reads `_player` — server-mode broadcasts must not
  assume a local player exists (the GID-095/096 authority code should already be
  player-agnostic; audit).
- **Additive guarantee:** listen-server path (MenuScene → Host Game) must be
  untouched; gate every server-only branch on the launch flag. The existing
  `net_rehost_smoke` / `net_coop_smoke` must still pass.
- **Lifecycle:** log connects/disconnects/persistence to stdout; keep running when
  the last client leaves; flush session on SIGINT/quit.
- CLAUDE.md: explicit typing, `preload`, guard everything.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
