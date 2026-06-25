# Co-op Multiplayer (Vertical Slice + PvP)

> Status: up to **4 players** (GID-094 / TID-341) share one named map
> (**madrian**) and see each other's avatar move (GID-090), and two players can
> challenge each other to a real TCG **card battle** (GID-091, host-authoritative).
> Each server now keeps a **persistent session** (GID-095): a shared world plus a
> **per-player character** (deck/inventory/coins/level/skills) keyed to the player's
> identity token and resumed on reconnect, all owned by the host authority and stored
> separately from single-player saves. Live enemy/chest sync and the infinite chunk
> world remain out of scope — see Limitations.

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
| `host(port = 24565, max_clients = DEFAULT_MAX_CLIENTS) -> Error` | Create an ENet server + start the discovery listener; emits `server_started`. `max_clients` is the ENet client capacity (host occupies no slot); default `3` ⇒ 4-player session. A dedicated server (GID-097, host not a player) passes `4` without re-editing the constant (GID-094 / TID-341) |
| `join(ip, port = 24565) -> Error` | Connect to a host |
| `leave()` | Tear down peer + discovery (via `_reset_session()`); emits `session_ended` |
| `is_active()` / `is_host()` / `local_id()` | State queries (guard all co-op code with `is_active()`) |

**Host/join reset contract (GID-092 / TID-337):** `host()` and `join()` both call the
private `_reset_session()` first, which stops the discovery sockets, **closes** the current
ENet peer (`peer.close()` — not just nulling it), then nulls it. Closing is mandatory:
dropping the reference alone leaves the server socket holding the OS port until GC, so a
second `host()` on the same port would fail with "address in use". This makes the **Host
Game** button work on repeat presses even when a prior session was left dangling (e.g. the
host returned to the menu by a path that never called `leave()`).
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
AvatarSync.spawn_offset(peer_id, tile_size) -> Vector2 # deterministic N-peer ring fan-out
```

`y` is **never transmitted** — receivers recompute it locally from terrain height.

### Player identity — name, color & stable token (GID-094 / TID-342)

Each player has a **display name**, an **avatar color**, and a **stable identity
token**. Three distinct concepts, deliberately separate:

- **Token** — an opaque 16-hex id generated once and stored locally; *never shown*.
  It is the key GID-095 will use to match a reconnecting player to their saved
  per-session character. Shape is fixed here even though persistence lands later.
- **Display name / color** — user-editable in the lobby, shown to others, remembered.

**Device profile — `autoloads/MpProfile.gd` (autoload).** Stores `{token, name,
color}` at `user://mp_profile.json`, deliberately **separate from the game save**
(`save_slot_*.json`) because co-op can launch cold from the menu without loading a
game (cf. `SaveManager.ensure_coop_deck`). The token is generated and a random
palette color is assigned on first run; both persist. API: `get_token()`,
`get_display_name()`/`set_display_name()`, `get_color()`/`set_color()`, `color_hex()`.

**Pure wire format — `game_logic/net/PlayerIdentity.gd`** (mirrors `AvatarSync`):
`encode(token, name, color) -> [token, name, color_hex]` and
`decode(payload) -> {token, name, color}` (fully defaulted, invalid-hex-safe).

**Handshake — `NetSync.recv_identity(payload, is_reply)` (reliable RPC).** Identity
is a one-shot, so delivery can't rely on the avatar stream's continuous rebroadcast.
Instead the **just-loaded** peer drives it: in `_setup_coop` it broadcasts its
identity to all (`is_reply = false`); every recipient (already in-world, so its
NetSync exists) stores it and **replies once** directly (`is_reply = true`),
terminating the exchange. WorldScene keeps `_remote_identities` (peer_id →
{token,name,color}); identities arriving before the avatar spawns are applied lazily
in `_spawn_remote_player`. Entries are erased on disconnect / cleared on session end.

**Session roster.** A compact HUD panel (`_build_coop_roster` / `_refresh_coop_roster`)
lists the local player (`"<name> (you)"`) and every connected remote as a colored
swatch + name, refreshed on identity/connect/disconnect.

**Lobby fields.** `MultiplayerLobbyScene` has a name `LineEdit` (max 16) and a row of
preset color swatches, seeded from `MpProfile` and saved back on edit / before
hosting/joining. The host also sets `NetworkManager.host_label = "<name>'s game"` so
the name shows in others' Find-Games list.

### Remote avatars — `scenes/world/entities/RemotePlayer.gd` (+ `.tscn`)

A `Node3D` (no physics, no input, no camera). `init_from_data({peer_id, x, z})`
seeds it; `set_net_state(x, z, flip_h, moving)` stores the latest packet;
`_process` interpolates XZ via `AvatarSync.interp` (rate 12), recomputes Y from
`world_scene.get_terrain_height`, and drives walk/idle + horizontal flip. The wizard
walk sprite is built by the shared helper `scenes/world/entities/AvatarSprite.gd`
(`build()`), reused to avoid duplicating Player's sprite setup. `set_player_identity(name, color)`
(named so to avoid the native `Node3D.set_identity`) drives the sprite **tint** and a
billboard `Label3D` name tag above the head; until identity arrives it defaults to the
old neutral blue.

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
  `(x, z, flip_h, moving)` and `rpc("recv_avatar", payload)`. **N-peer note:** in
  ENet client-server, clients aren't directly connected, so a client's broadcast
  reaches other clients only because Godot's `SceneMultiplayer.server_relay` (on by
  default) has the host relay it. This is what lets up to 4 players all see each
  other; it is exercised end-to-end by `tests/net_coop_npeer_smoke.gd`.
- `_on_avatar_received(sender, payload)` decodes and feeds `set_net_state` (lazy-
  spawns if a packet arrives before the connect signal).
- Remote avatars seed near the local player with a **deterministic per-peer ring
  offset** (`AvatarSync.spawn_offset(peer_id, tile_size)` — 12 slots at a 2-tile
  radius, slot = `peer_id mod 12`) so up to 4 avatars don't stack on the shared
  madrian SPAWN tile before the first packet arrives, regardless of join order
  (GID-094 / TID-341). The seed is cosmetic — once 15 Hz packets flow each avatar
  interpolates to its real position; Y is always terrain-recomputed by RemotePlayer.
  Camera logic is untouched (only the local player drives it).

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
- **Cold-session deck seeding (GID-092 / TID-335):** `enter_map_coop` calls
  `SaveManager.ensure_coop_deck()` before loading the map. A co-op session launched
  straight from the menu never ran `new_game()`/`load()`, so `player_deck` is empty and
  the PvP challenge flow's `DECK_MIN` gate (`WorldScene._request_challenge` /
  `_accept_challenge`) would block the battle from ever starting. `ensure_coop_deck()`
  seeds the same 12-card starter `new_game()` uses, **in-memory only**: it is a no-op when
  a real game is loaded (`_loaded`) or the deck already meets `DECK_MIN`, and because
  `_loaded` stays false for a cold session, `save()`/`_flush_if_dirty()` remain no-ops, so
  the on-disk save is never clobbered. Covers both host (`_on_host`) and client
  (`_on_connection_succeeded`) since both route through `enter_map_coop`.

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

## PvP Card Battles (GID-091)

Two co-op players can challenge each other to a TCG card battle reusing the
existing battle engine, under a **host-authoritative state-mirroring** model
(not lockstep — avoids needing deterministic shared RNG for shuffles/draws).

### Model

- The co-op **host** (`NetworkManager.is_host()`) owns the one canonical
  `GameState`: `players[0]` = host, `players[1]` = client. It applies both its own
  and the client's actions, then broadcasts `GameState.to_dict()`.
- The **client** never simulates. It sends *intents* over a reliable RPC, and
  renders the received mirror **from its own perspective** (`_local_player_idx == 1`:
  its side at the bottom, host's at the top). Input is gated to its own turn and
  blocked while a round-trip is pending (`_pvp_pending`).
- Everything is guarded by `_pvp`; single-player / NPC duel / puzzle / Spire
  battles hit zero new code paths (`_local_player_idx == 0` → the `_my_idx()`/
  `_opp_idx()` accessors are the identity, so rendering/input are unchanged).

### Wire format — `game_logic/net/BattleNetProtocol.gd`

Pure, scene-free, unit-tested (mirrors `AvatarSync.gd`). JSON-primitive dicts.

| Helper | Payload |
|---|---|
| `encode_play_card_at_slot(hand_index, slot_idx)` | minion from hand → board slot |
| `encode_play_spell(hand_index, target={})` | spell; `target` = `{}` / `{hero:true}` / `{side,slot}` / `{slot}` (slot spells) |
| `encode_attack(attacker_slot, target_slot)` | `target_slot == -1` (`TARGET_HERO`) = enemy hero |
| `encode_end_turn()` / `encode_surrender()` | — |
| `encode_hero_power(target, effect_type, effect_value)` | effect carried because the host doesn't know the client's skills |
| `encode_potion(potion_id)` | host applies the state effect (acting peer consumed its own inventory) |
| `encode_state(state_dict, seq)` / `decode_state` | full-state mirror with a monotonic `seq` (client drops stale) |

`decode_intent` always returns a fully-defaulted dict; garbage/unknown → `type == ""`.

**Client mirror application (`_on_pvp_state`):** the client never simulates — it rebuilds a
fresh `GameState` from each mirror via `from_dict`. Because that is a brand-new object, the
`turn_ended` signal is reconnected to `_on_turn_ended` on every apply (GID-092 / TID-336);
the original `_ready` connection was to the now-discarded placeholder state. The client
launches on the default `GameState.new()` placeholder (which already seeds two full
players), so rendering before the first mirror lands is always safe — verified end-to-end
by `tests/net_pvp_client_smoke.gd`.

### Relay — `scenes/battle/BattleNetSync.gd`

Fixed-name child of `BattleScene`, so the RPC path
`/root/BattleScene/BattleNetSync` matches on both peers (SceneManager sets the
BattleScene root name explicitly). **Reliable** RPCs (turn-based, must not drop):
`send_intent` (client→host), `sync_state` / `pvp_ended` (host→client), and
`request_sync` (client→host, retried until the first mirror lands — resolves the
race where the host broadcasts before the client's scene exists).

### Flow

1. Walk within ~3 tiles of the other player → a **"Challenge to Battle"** HUD
   button appears (mobile + desktop). Press it → `NetSync.request_battle(my_deck)`.
2. The other peer sees an Accept/Decline prompt. On Accept →
   `NetSync.respond_battle(true, my_deck)`; both peers then call
   `SceneManager.enter_pvp_battle(local_idx, opponent_deck)` (host = idx 0).
3. The host builds both decks (its own + the relayed client deck), draws opening
   hands, `start_turn(1)`, and broadcasts the initial state. The host plays first.
4. The WorldScene is detached but kept alive; the co-op session is **never** torn
   down (`_setup_coop`/`_teardown_coop` are idempotent and re-run from
   `_enter_tree` on world re-attach). Both peers return to the same madrian.

### Rewards & end states (duel-style)

PvP outcomes award **no cards, no coins, no XP** and don't mark enemies defeated
(`enemy_data` carries an empty drop pool / zero coin reward). A synced
victory/defeat overlay (`BattleResultUI.show_pvp_result`) shows on both peers;
its Continue button emits `GameBus.pvp_battle_ended(did_win)`, which SceneManager
handles by restoring the shared world. **Flee** (pause menu) becomes a surrender;
an **opponent disconnect** mid-battle is a forfeit win for the remaining player
(if the whole session ended, the client routes to the menu).

## Persistent Sessions & Per-Player Progress (GID-095)

Each server keeps a **persistent session**: shared world progress plus a roster of
**per-player character records** (deck, inventory, coins, level, skills, position),
each scoped to that session and resumed when the same player reconnects. The
**authority** (the host in the listen-server model; a dedicated server in GID-097)
owns the persistence — this goal ships on the host-is-authority P2P path, but nothing
is host-specific, so GID-097 reuses the same interfaces.

The per-player character is keyed by the **identity token** from GID-094
(`MpProfile.get_token()`). A session character is **its own save, fully separate from
single-player `save_slot_*.json`** — the two never read or write each other.

### Pure model — `game_logic/net/SessionState.gd`

`class_name SessionState`, scene-free, unit-tested (mirrors `GameState`). JSON-primitive
only. Holds:

- **Identity:** `session_id`, `display_name`.
- **Shared world progress:** `current_map`, `world_seed`, `time_of_day`, `days_elapsed`,
  `defeated_enemies`, `opened_chests`, `story_flags`.
- **Roster:** `members: { token -> character_record }`.

A **character record** is the per-player slice: `owned_cards` (instances),
`player_deck` (UIDs), `coins`, `essence`, `xp`, `level`, `skill_points`,
`unlocked_skills`, `magic_type`, `corruption_points`, `redemption_points`, and
`map`/`x`/`z`. `to_dict`/`from_dict` round-trip with `CURRENT_SESSION_VERSION = 1` +
an `_apply_migrations` scaffold (same shape as `SaveManager`). API:
`ensure_member(token, name)` (resume or seed starter), `get_member`, `has_member`,
`update_member`, and static `make_starter_character(token, name)` — the 12-card
starter deck (same templates as `new_game`) with **token-salted UIDs** so two members'
instances never collide in one file.

**Card-instance shape is shared** with single-player via
`game_logic/CardInstanceUtil.gd` (`make(uid, template_id, rarity, attack, health,
cost)`), which `SaveManager.add_card_instance` now also uses, so `save.json` and the
session files can never diverge.

### Authority store — `autoloads/SessionStore.gd` (autoload)

A `SaveManager`-style **dirty-flag batched writer** (2 s timer + close-notification
flush) to `user://sessions/<session_id>.json` — one file per session so a device can
host several worlds. It is a **completely separate code path** that NEVER touches
`save_slot_*.json` (the isolation invariant). API: `open(session_id, display_name)`
(load-or-create), `close(flush)`, `mark_dirty`, `flush_now`, plus `ensure_member` /
`update_member` convenience that delegate to the open `SessionState` and mark dirty.
Writes atomically via `.tmp` + rename. Clients never call `open`/`_write` — only the
authority persists (single source of truth).

The **session id is stable per host**: `MpProfile.get_host_session_id()` generates +
persists one opaque id in `mp_profile.json`, so re-hosting reuses the same file.

### Character handshake — `NetSync` + WorldScene (TID-346)

Two reliable RPCs on `NetSync`:

```gdscript
@rpc("any_peer", "reliable", "call_remote")
func recv_character(record: Dictionary, resume: bool) -> void   # host → client
@rpc("any_peer", "reliable", "call_remote")
func submit_character(record: Dictionary) -> void               # client → host intent
```

Flow (all guarded by `NetworkManager.is_active()` / `_session_adopted`):

1. **Host** `_setup_coop` → `_setup_session()`: opens `SessionStore` with
   `get_host_session_id()`, seeds the shared world fields, `ensure_member` for its own
   token, and **adopts** its own record (restoring position on resume).
2. A client's identity arrives (`_on_identity_received`); the host now knows the token,
   so `_send_character_to_peer` resolves the member (resume or fresh starter via
   `SessionStore.ensure_member`) and `rpc_id`s `recv_character` to that peer, recording
   `peer_id → token`.
3. The **client** `_on_character_received` calls
   `SaveManager.adopt_session_character(record)` and restores position when `resume`.

**Adoption — `SaveManager.adopt_session_character(record)`:** loads the record into the
*same in-memory fields* co-op/PvP already read (collection, deck, loadout, coins,
essence, xp, level, skills, magic, corruption/redemption), then **forces
`_loaded = false`**. Because `save()`/`_flush_if_dirty` are no-ops until `_loaded`, the
session character can **never** be written into `save_slot_*.json` — the same
no-op-when-cold contract as `ensure_coop_deck`, extended to a full character. The
matching `export_session_character()` snapshots that slice back to a record dict.

**Persist-back** (`_tick_session_persist`, every 5 s in `_process`): the host writes
its own member directly; clients `rpc_id(1, "submit_character", record)` with their
latest snapshot (collection/deck/coins/level/skills + current position), which the host
merges by the `peer_id → token` map and marks dirty. The host also flushes on a
peer-disconnect, and `flush_now()` + `close()` on session end. `_session_adopted`
survives a PvP battle re-attach (SessionStore stays open across battles).

### Reconnection & recent servers (TID-347)

- **Recent-servers store** in `MpProfile` (`recent_servers` in `mp_profile.json`):
  `{address, port, label, last_session_id, last_joined}`, deduped by `address:port`,
  most-recent-first, capped at 6. API: `add_recent_server(...)`, `get_recent_servers()`.
- **Lobby Rejoin list** above "Find Games": one tap per remembered server →
  `NetworkManager.join(address, port)`. Because the host's session id is stable, this
  resumes the **same world + character**. Recorded on every successful connect; all
  three join paths (IP / discovered / rejoin) funnel through one `_start_join`.
- **Retry** button (hidden until a 12 s-watchdog timeout or hard failure) re-runs the
  same attempt. **WAN guidance** is a collapsible block: forward UDP 24565 + share the
  **public** IP (not the LAN IP `get_lan_ip` returns); Find Games is LAN-only.
- Reconnect UX is delivered via the one-tap Rejoin list, *not* by auto-navigating on
  `session_ended` — `NetworkManager` conflates the host's own `leave()` with a client
  losing the host into the same signal, so force-routing there would regress host-exit.

## Integrations with Other Features

| System | Integration |
|---|---|
| SceneManager | `enter_map_coop()` reuses `enter_map`; co-op lives entirely in `State.WORLD` |
| SessionStore | Authority-owned session persistence (`user://sessions/<id>.json`), isolated from `save.json`; opened/closed by WorldScene co-op hooks |
| SaveManager | `adopt_session_character` / `export_session_character` bridge a session record to the in-memory character co-op/PvP read, forcing `_loaded = false` for isolation; shares `CardInstanceUtil` for the instance shape |
| MpProfile | `get_host_session_id` (stable session file) + recent-servers list for one-tap Rejoin, alongside the GID-094 token/name/color |
| WorldScene | Hosts `NetSync`, spawns/despawns RemotePlayers under `Entities`, broadcasts at 15 Hz; reuses `get_terrain_height` |
| Player | Local avatar's `_sprite.flip_h` / `_is_moving` are read (via `get()`) to build the broadcast payload |
| MenuScene | "Co-op (Beta)" button opens the lobby overlay (same pattern as Settings) |
| MpProfile | Device-local identity store (token/name/color) read by the lobby + WorldScene handshake; independent of `save.json` so it works for cold co-op |
| MapRegistry | madrian `.tres` is identical on both peers, so the shared map is deterministic |
| GameBus | Not used for net events by design — NetworkManager is itself the event hub |

## Asset Requirements

No new art. RemotePlayer reuses the existing wizard walk textures
(`assets/textures/pixel_art/wizard_walk_*_pixel.png`) via `AvatarSprite.build()`.
The name tag is a procedural `Label3D` and the roster/lobby swatches are procedural
`ColorRect`/`StyleBoxFlat` — no textures. `RemotePlayer.tscn` and all new scripts
(`MpProfile.gd`, `PlayerIdentity.gd`) have `.uid` sidecars.

## Tests

| File | Type | Covers |
|---|---|---|
| `tests/unit/test_coop_sync.gd` | unit (auto-run) | AvatarSync encode/decode round-trip + interpolation + N-peer `spawn_offset` fan-out (18 cases) |
| `tests/unit/test_player_identity.gd` | unit (auto-run) | PlayerIdentity encode/decode round-trip, color hex, robust defaults for short/blank/invalid payloads (10 cases) |
| `tests/unit/test_coop_discovery.gd` | unit (auto-run) | Discovery wire-format round-trip, IP-from-socket, invalid/wrong-tag rejection (7 cases) |
| `tests/unit/test_pvp_protocol.gd` | unit (auto-run) | BattleNetProtocol intent + state-mirror encode/decode (17 cases) |
| `tests/unit/test_session_state.gd` | unit (auto-run) | SessionState round-trip, member lookup/create by token, resume-without-reset, starter seeding (token-salted UIDs), migration scaffold + garbage tolerance (16 cases) (GID-095) |
| `tests/net_coop_smoke.gd` | on-demand SceneTree | Real ENet loopback connect + NetSync RPC + AvatarSync decode end to end |
| `tests/net_coop_npeer_smoke.gd` | on-demand SceneTree | 3-peer (host + 2 clients) loopback: host avatar reaches both clients, and a **client→client** identity packet is relayed by the host (proves the server-relay path N-peer rendering depends on) + PlayerIdentity decode (GID-094) |
| `tests/net_discovery_smoke.gd` | on-demand SceneTree | Real loopback UDP discovery request/reply |
| `tests/net_pvp_smoke.gd` | on-demand SceneTree | Real ENet loopback: client intent → host apply → state-mirror round-trip |
| `tests/net_pvp_client_smoke.gd` | on-demand SceneTree | Real ENet loopback with **two real `BattleScene` peers**: client (idx 1) launches + applies the host's first mirror without crashing (GID-092 / TID-336) |
| `tests/net_rehost_smoke.gd` | on-demand SceneTree | host→leave→host repeated, and re-host without an explicit leave, all return OK (port freed) (GID-092 / TID-337) |
| `tests/net_session_smoke.gd` | on-demand SceneTree | Real ENet loopback + live `SessionStore`/`SaveManager` autoloads: client identifies (token A) → host sends a seeded 12-card starter via `recv_character`; after persisted progress + close, re-opening the session resumes the **same** character (coins) + world progress from disk; `save_slot_*.json` proven untouched (GID-095 / TID-348) |

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
- **Up to 4 players** (`host()` default `max_clients = DEFAULT_MAX_CLIENTS = 3`,
  i.e. 3 clients + host; GID-094 / TID-341). **Reconnection** resumes a player's
  session character + position and the shared world (GID-095), via the lobby's one-tap
  Rejoin list; there is still no reconnection *into an in-progress PvP battle*.
- **PvP is LAN/loopback only, 2 players**, no spectating, no wagers/ranked ladder.
- **Not *live*-synced:** enemies/NPCs, chests, day/night, weather (live world-object
  sync is GID-096). Per-player character progress (deck/coins/level/skills/position) IS
  persisted per session (GID-095); shared world progress fields exist in the session
  file but are only minimally populated until GID-096 writes them live. PvP battles are
  duel-style (no rewards).
- **Infinite chunk world not supported** — co-op uses a finite named map to avoid
  chunk synchronisation.
- **Steam transport** is stubbed (`Transport.STEAM` returns null with a warning).
