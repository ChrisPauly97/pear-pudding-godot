# TID-352: Dedicated headless server mode

**Goal:** GID-097
**Type:** agent
**Status:** done
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

### Files to change

1. **`autoloads/NetworkManager.gd`**
   - Add `var _server_mode: bool = false` instance field.
   - Add `func is_dedicated_server() -> bool: return _server_mode`.
   - In `_on_peer_connected` / `_on_peer_disconnected`: add `if _server_mode: print(...)` log lines.

2. **`autoloads/SceneManager.gd`**
   - At the end of `_ready()`, call `_maybe_boot_dedicated_server()`.
   - Add `_maybe_boot_dedicated_server()`: parses `OS.get_cmdline_user_args()` for `--server`,
     `--port N`, `--map NAME`; sets `NetworkManager._server_mode = true`, calls
     `NetworkManager.host(port, 4)` (4 clients — no host player slot used), then
     `enter_map_coop(map)`.

3. **`scenes/world/WorldScene.gd`**
   - In `_ready()`: skip `_spawn_player()`, joystick, `WorldHUD`, `DungeonSessionUI`, and
     `Minimap` when `NetworkManager.is_dedicated_server()`. Compute `_server_spawn_pos` for
     the `build_all_named_map` / `build_initial_infinite` calls instead.
   - Replace the two `_csm.build_*(... _player.position)` calls with a local
     `var _ref_pos := _player.position if _player != null else _server_spawn_pos`.
   - In `_process()`: move the `_coop_active` block and `_dnc.tick(delta)` **before** the
     `if _player == null: return` guard so those ticks run in server mode.
   - Guard `_update_nocturnal_spawns()` and `_find_nocturnal_spawn_pos()` with
     `if _player == null: return / return Vector3.ZERO` early returns.
   - Guard `_tick_roaming_boss()` distance check with `if _player == null: …`.

### Guarantee: additive only
All server-mode paths are gated on `NetworkManager.is_dedicated_server()` or `_player == null`.
The existing listen-server / single-player paths are unchanged.

## Changes Made

1. **`autoloads/NetworkManager.gd`**
   - Added `var _server_mode: bool = false` field.
   - Added `func is_dedicated_server() -> bool: return _server_mode`.
   - Added `if _server_mode: print(...)` log lines in `_on_peer_connected` and `_on_peer_disconnected`.

2. **`autoloads/SceneManager.gd`**
   - Added `_maybe_boot_dedicated_server()` call at the end of `_ready()` (after all GameBus connects).
   - Added `_maybe_boot_dedicated_server()`: parses `OS.get_cmdline_user_args()` for `--server`, `--port N`, `--map NAME`; sets `NetworkManager._server_mode = true`, calls `NetworkManager.host(port, 4)`, then `enter_map_coop.call_deferred(map_name)`.

3. **`scenes/world/WorldScene.gd`**
   - In `_ready()`: gated `_spawn_player()`, joystick, HUD labels, WorldHUD, Minimap, DungeonSessionUI, pending battle re-enter on `not NetworkManager.is_dedicated_server()`. Added `_server_ref_pos` computed from world map's SPAWN marker (or Vector3.ZERO) for chunk streaming.
   - Replaced `_player.position` in `build_initial_infinite` and `build_all_named_map` calls with `_player.position if _player != null else _server_ref_pos`.
   - In `_process()`: moved `_coop_active` ticks and `_dnc.tick()` BEFORE the `if _player == null: return` guard so they run in server mode.
   - `_update_nocturnal_spawns()`: already had `if not _is_infinite or _player == null: return`.
   - `_find_nocturnal_spawn_pos()`: added `if _player == null: return Vector3.ZERO`.
   - `_tick_roaming_boss()`: guarded `distance_to` call with `_player != null and`.

## Documentation Updates

- Updated `docs/agent/multiplayer-coop.md` to document dedicated server launch path, invocation syntax, and server-mode behaviour.
