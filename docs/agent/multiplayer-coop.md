# Co-op Multiplayer (Vertical Slice)

> Status: thin vertical slice (GID-090). Two players share one named map
> (**madrian**) and see each other's avatar move. Battles, enemies, chests,
> inventory, the infinite chunk world, and save sync are **out of scope** — see
> Limitations.

## Key Features

- Host/join co-op over Godot's high-level multiplayer (ENet), reached from a
  **"Co-op (Beta)"** button on the main menu.
- Transport is **abstracted behind one factory method** so GodotSteam's
  `SteamMultiplayerPeer` can be dropped in later with a one-line change.
- **LAN game discovery** — a "Find Games" scan lists nearby hosts to tap-join; no
  IP typing. Manual IP entry remains as a fallback.
- Remote players render as **display-only avatars** that interpolate smoothly;
  each client owns and drives only its own player + camera.
- Entirely **additive and guarded** — single-player is byte-for-byte unchanged
  when no session is active.

## How It Works

### Transport wrapper — `autoloads/NetworkManager.gd`

Autoload (registered last in `project.godot`). Owns the `MultiplayerAPI` peer
lifecycle and re-broadcasts the native multiplayer signals as its own so nothing
else in the game touches `multiplayer` directly.

Public API:

| Member | Purpose |
|---|---|
| `host(port = 24565) -> Error` | Create an ENet server + start the discovery listener; emits `server_started` |
| `join(ip, port = 24565) -> Error` | Connect to a host |
| `leave()` | Tear down peer + discovery; emits `session_ended` |
| `is_active()` / `is_host()` / `local_id()` | State queries (guard all co-op code with `is_active()`) |
| signals | `server_started`, `connection_succeeded`, `connection_failed`, `peer_connected(id)`, `peer_disconnected(id)`, `session_ended`, `hosts_discovered(hosts)` |

**Steam swap point:** `enum Transport { ENET, STEAM }` + `_create_peer(transport)`
are the *only* transport-specific code. To add Steam: return
`SteamMultiplayerPeer.new()` from the `STEAM` branch and select it in `host`/`join`.
The discovery channel (below) is ENet-only — Steam's matchmaking replaces it.

### Pure sync logic — `game_logic/net/AvatarSync.gd`

Static, scene-free, fully unit-tested:

```
AvatarSync.encode(x, z, flip_h, moving) -> Array       # payload [x, z, flip_h, moving]
AvatarSync.decode(payload) -> Dictionary               # {x, z, flip_h, moving}
AvatarSync.interp(current, target, delta, rate) -> Vector3   # clamped lerp, no overshoot
```

`y` is **never transmitted** — receivers recompute it locally from terrain height.

### Remote avatars — `scenes/world/entities/RemotePlayer.gd` (+ `.tscn`)

A `Node3D` (no physics, no input, no camera). `init_from_data({peer_id, x, z})`
seeds it; `set_net_state(x, z, flip_h, moving)` stores the latest packet;
`_process` interpolates XZ via `AvatarSync.interp` (rate 12), recomputes Y from
`world_scene.get_terrain_height`, and drives walk/idle + horizontal flip. A blue
modulate distinguishes it from the local player. The wizard walk sprite is built
by the shared helper `scenes/world/entities/AvatarSprite.gd` (`build()`), reused
to avoid duplicating Player's sprite setup.

### Position sync — `scenes/world/NetSync.gd` + WorldScene hooks

`NetSync` is a fixed-name `Node` child of WorldScene carrying one RPC:

```gdscript
@rpc("any_peer", "unreliable_ordered", "call_remote")
func recv_avatar(payload: Array) -> void
```

Because the WorldScene root node is named `WorldScene` (instantiated via
`change_scene_to_node`), the RPC node resolves to the **same path
`/root/WorldScene/NetSync` on both peers** — a hard requirement for Godot RPC
delivery. The node dies with the scene.

WorldScene co-op hooks (all guarded by `NetworkManager.is_active()` /
`_coop_active`):

- `_setup_coop()` (end of `_ready`): create `NetSync`, connect NetworkManager
  peer/session signals, and spawn `RemotePlayer`s for peers already connected
  (`multiplayer.get_peers()` — covers the client-joining-host ordering).
- `_remote_player_nodes: Dictionary` (peer_id → RemotePlayer) under the existing
  `Entities` node; spawned on `peer_connected`, freed on `peer_disconnected` /
  `session_ended`.
- `_broadcast_local_avatar(delta)` in `_process` at **15 Hz**: encodes the local
  `(x, z, flip_h, moving)` and `rpc("recv_avatar", payload)`.
- `_on_avatar_received(sender, payload)` decodes and feeds `set_net_state` (lazy-
  spawns if a packet arrives before the connect signal).
- The non-host avatar spawns +2 tiles over so the two don't overlap at the shared
  madrian spawn marker. Camera logic is untouched (only the local player drives it).

### Session entry — lobby + SceneManager

- `scenes/ui/MultiplayerLobbyScene.gd` (extends `BaseOverlay`, instantiated via
  `.new()` like SettingsScene): Host / Find Games (+ results list) / Join-by-IP /
  Close, viewport-relative, rebuilt on resize.
- Host → `NetworkManager.host()` then `SceneManager.enter_map_coop("madrian")`
  immediately. Client → on `connection_succeeded`, `enter_map_coop("madrian")`.
  Both end up in madrian before any avatar RPCs flow.
- `SceneManager.enter_map_coop(map_name)` clears any prior world/stack and reuses
  the normal `enter_map` path. `save()` is a no-op when no game is loaded, so this
  is safe launched cold from the menu.

### LAN discovery — UDP channel (ENet-only)

A separate UDP channel from the ENet game connection, on `DISCOVERY_PORT = 24566`:

- **Client broadcasts** a query (`255.255.255.255:24566`); **host replies unicast**
  with `{name, ip, game_port, map, players}` (the IP is taken from the socket, not
  trusted from the payload). Client collects replies for ~1.2 s, dedupes by IP, and
  emits `hosts_discovered`.
- Wire format lives in pure static helpers (`build_discovery_query`,
  `is_discovery_query`, `build_discovery_reply`, `parse_discovery_reply`) — unit-tested.

**Why client-broadcasts / host-replies-unicast:** only the side that *receives a
broadcast* needs Android's `WifiManager.MulticastLock`. With this model only the
**host** receives a broadcast, so the common mobile path **Android client →
desktop host** works with zero native code (the Android client receives a unicast
reply, which needs no lock).

## Integrations with Other Features

| System | Integration |
|---|---|
| SceneManager | `enter_map_coop()` reuses `enter_map`; co-op lives entirely in `State.WORLD` |
| WorldScene | Hosts `NetSync`, spawns/despawns RemotePlayers under `Entities`, broadcasts at 15 Hz; reuses `get_terrain_height` |
| Player | Local avatar's `_sprite.flip_h` / `_is_moving` are read (via `get()`) to build the broadcast payload |
| MenuScene | "Co-op (Beta)" button opens the lobby overlay (same pattern as Settings) |
| MapRegistry | madrian `.tres` is identical on both peers, so the shared map is deterministic |
| GameBus | Not used for net events by design — NetworkManager is itself the event hub |

## Asset Requirements

No new art. RemotePlayer reuses the existing wizard walk textures
(`assets/textures/pixel_art/wizard_walk_*_pixel.png`) via `AvatarSprite.build()`.
`RemotePlayer.tscn` and all new scripts have `.uid` sidecars.

## Tests

| File | Type | Covers |
|---|---|---|
| `tests/unit/test_coop_sync.gd` | unit (auto-run) | AvatarSync encode/decode round-trip + interpolation (13 cases) |
| `tests/unit/test_coop_discovery.gd` | unit (auto-run) | Discovery wire-format round-trip, IP-from-socket, invalid/wrong-tag rejection (7 cases) |
| `tests/net_coop_smoke.gd` | on-demand SceneTree | Real ENet loopback connect + NetSync RPC + AvatarSync decode end to end |
| `tests/net_discovery_smoke.gd` | on-demand SceneTree | Real loopback UDP discovery request/reply |

Run the smoke tests with `godot --headless --path . -s tests/<file>` (exit 0 =
pass). They are not in the auto-discovered unit suite because they need real
sockets + frame polling.

**Manual two-instance check (visual, recommended before release):** launch two
instances; A → Co-op → Host (lands in madrian); B → Co-op → Find Games or IP
`127.0.0.1` → Join. Move each player and confirm the other sees it walk smoothly;
close one and confirm its avatar is freed.

## Limitations / Out of Scope (this slice)

- **LAN / loopback only** — no NAT traversal; over-the-internet play needs a VPN
  overlay (e.g. Tailscale) or the future Steam transport.
- **Android host discovery** needs a `MulticastLock` (not yet implemented); an
  Android device can *join* and be *discovered as a client-of-desktop-host*, but
  hosting-and-being-found on Android requires a future plugin. AP-isolation and
  guest networks block UDP discovery entirely — manual IP entry is the fallback.
- **2 players max** (`MAX_PEERS = 1`); no reconnection.
- **Not synced:** battles, enemies/NPCs, chests, inventory, story flags, save data,
  day/night, weather. Co-op assumes both players just explore madrian together.
- **Infinite chunk world not supported** — co-op uses a finite named map to avoid
  chunk synchronisation.
- **Steam transport** is stubbed (`Transport.STEAM` returns null with a warning).
