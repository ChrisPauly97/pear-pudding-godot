# TID-321: NetworkManager autoload (abstracted ENet factory + signals)

**Goal:** GID-090
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The transport layer. This task creates a `NetworkManager` autoload that owns the
`MultiplayerAPI` peer lifecycle (host / join / disconnect) and re-broadcasts the
native multiplayer signals as its own, so no other system ever touches
`multiplayer` directly. It must be written so that swapping ENet for GodotSteam's
`SteamMultiplayerPeer` later is isolated to a single factory method — the whole
point of the user's "ENet now, Steam later" requirement.

## Research Notes

**Why the wrapper is thin:** Godot's high-level multiplayer already abstracts the
transport behind `MultiplayerPeer`/`MultiplayerAPI`. Both `ENetMultiplayerPeer`
and `SteamMultiplayerPeer` implement `MultiplayerPeer`, so the only
transport-specific code is peer construction. Keep all ENet specifics in one
`_create_peer()` / host / join factory and reserve `enum Transport { ENET, STEAM }`
to mark the seam.

**Autoload registration:** add to the `[autoload]` section of
`/home/user/pear-pudding-godot/project.godot`, registered **last** (after
SceneManager and the registries) so all dependencies exist. Pattern in the file:
`NetworkManager="*res://autoloads/NetworkManager.gd"`. Init order today:
IsoConst, GameBus, AppLog, SaveManager, SceneManager, AudioManager,
TransitionManager, … registries.

**ENet host/join skeleton (Godot 4.4):**
```gdscript
var peer := ENetMultiplayerPeer.new()
peer.create_server(port, max_clients)        # host
# or
peer.create_client(ip, port)                 # join
multiplayer.multiplayer_peer = peer
```
Use a fixed default port (e.g. `const DEFAULT_PORT := 24565`) and
`MAX_PEERS = 1` (2 players total) for the slice.

**Native signals to relay** (connect in a setup method, re-emit own signals):
- `multiplayer.peer_connected(id)` → `peer_connected(id)`
- `multiplayer.peer_disconnected(id)` → `peer_disconnected(id)`
- `multiplayer.connected_to_server` → `connection_succeeded`
- `multiplayer.connection_failed` → `connection_failed`
- `multiplayer.server_disconnected` → `session_ended`
- After `create_server` succeeds, emit `server_started`.

**Public API (for TID-323 / TID-324 to consume):**
```gdscript
signal server_started
signal connection_succeeded
signal connection_failed
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal session_ended

func host(port: int = DEFAULT_PORT) -> Error
func join(ip: String, port: int = DEFAULT_PORT) -> Error
func leave() -> void
func is_active() -> bool      # true when a peer is set and not in OFFLINE state
func is_host() -> bool        # multiplayer.is_server()
func local_id() -> int        # multiplayer.get_unique_id()
```

**Steam stub:** `_create_peer(transport: Transport)` switches on the enum; the
`STEAM` branch can `push_warning("Steam transport not yet implemented")` and
return `null` for now. Document the one-method swap in a comment.

**CLAUDE.md conventions:** explicit type annotations; `is_active()` will guard all
coop code in other files; no `.uid` needed (plain `.gd`). Do not route these
through GameBus — NetworkManager is itself the event hub for net events (design
decision).

## Plan

1. Create `autoloads/NetworkManager.gd` extending `Node` with:
   - `enum Transport { ENET, STEAM }` as the swap seam
   - Signals: `server_started`, `connection_succeeded`, `connection_failed`,
     `peer_connected(id)`, `peer_disconnected(id)`, `session_ended`
   - `_ready()` connects native `multiplayer.*` signals to relay handlers
   - `_create_peer(transport) -> MultiplayerPeer` factory — ENET branch returns
     `ENetMultiplayerPeer.new()`, STEAM branch push_warning + return null
   - `host(port)` / `join(ip, port)` call the factory, run `create_server` /
     `create_client`, assign `multiplayer.multiplayer_peer`
   - `leave()` clears the peer and emits `session_ended`
   - `is_active()` / `is_host()` / `local_id()` query multiplayer state
2. Register `NetworkManager` last in the `[autoload]` section of `project.godot`.
3. Run headless compile check to confirm clean.

## Changes Made

- Created `autoloads/NetworkManager.gd` (Node autoload):
  - `enum Transport { ENET, STEAM }` marks the swap seam
  - Signals: `server_started`, `connection_succeeded`, `connection_failed`,
    `peer_connected(id)`, `peer_disconnected(id)`, `session_ended`
  - `host(port)` / `join(ip, port)` route through `_create_peer(Transport.ENET)`,
    call `create_server` / `create_client`, assign `multiplayer.multiplayer_peer`
  - `leave()` clears the peer and emits `session_ended`
  - `is_active()` / `is_host()` / `local_id()` query multiplayer state
  - `_create_peer(transport)` factory: ENET returns `ENetMultiplayerPeer.new()`;
    STEAM branch push_warning + returns null (stub for GodotSteam)
  - `_ready()` connects native `multiplayer.*` signals; relay methods re-emit own signals
- Registered `NetworkManager="*res://autoloads/NetworkManager.gd"` last in
  `project.godot` [autoload] section (after CompanionRegistry)
- All 1530 tests pass; headless compile check clean.

## Documentation Updates

None required — `docs/agent/multiplayer-coop.md` is created by TID-326.
