# Co-op Multiplayer (Vertical Slice + PvP)

> Status: up to **4 players** (GID-094 / TID-341) share one named map
> (**madrian**) and see each other's avatar move (GID-090), and two players can
> challenge each other to a real TCG **card battle** (GID-091, host-authoritative).
> Each server now keeps a **persistent session** (GID-095): a shared world plus a
> **per-player character** (deck/inventory/coins/level/skills) keyed to the player's
> identity token and resumed on reconnect, all owned by the host authority and stored
> separately from single-player saves. **Shared world-object state** (GID-096) — enemy
> encounters and chest/loot opens — now syncs from the authority to all players and
> persists into the session file, resuming on reconnect. The infinite chunk world
> remains out of scope — see Limitations.

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
AvatarSync.encode(x, z, flip_h, moving, map := "") -> Array   # [x, z, flip_h, moving, map]
AvatarSync.decode(payload) -> Dictionary               # {x, z, flip_h, moving, map}
AvatarSync.interp(current, target, delta, rate) -> Vector3   # clamped lerp, no overshoot
AvatarSync.spawn_offset(peer_id, tile_size) -> Vector2 # deterministic N-peer ring fan-out
```

`map` is the sender's current map name (TID-352) so receivers can drop cross-map packets;
it is optional/defaulted, so a legacy 4-element payload still decodes (`map == ""`).

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

### Map-scoped avatar sync (TID-352)

Co-op is designed for a **single shared map** (madrian), but that contract was previously
enforced only at the lobby entry point — the avatar layer was map-blind, so a peer who walked
into another map (e.g. `main` via a door) still rendered as a **cross-map ghost** at
coordinates belonging to a different map. The fix makes the avatar layer honor the contract:

- The avatar payload carries the sender's `map_name` (the 5th `AvatarSync` element).
- `_on_avatar_received` records each peer's last-known map (`_remote_player_maps[peer_id]`)
  and **only shows + feeds `set_net_state`** to an avatar whose map equals the local
  `map_name`. A peer on a different map is **hidden** (its node persists, holding its last
  same-map position, so re-convergence resumes instantly) — not freed.
- Newly spawned `RemotePlayer`s start `visible = false` and are revealed by the first
  same-map packet (≤66 ms at 15 Hz, broadcast unconditionally), so there is no ghost flash
  on a fresh map load either.
- **Roster rule:** an off-map peer stays listed but greyed with an **"(elsewhere)"** suffix.
- An empty map field (legacy/garbage payload) is treated as same-map, so nothing regresses.

This is **not** multi-map co-op (syncing transitions / differing geometry is a larger,
out-of-scope feature) — it is correctness: you only see a partner who is actually with you.

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

### Rewards & end states

PvP duels support an **optional ante (wager)**: during the challenge handshake, either
peer can propose an ante via `NetSync.request_battle_wager(challenger_deck, ante_coins)` →
the opponent sees an Accept/Decline panel → on accept, both sides deduct `ante_coins`
(`SaveManager.add_coins(-ante)`) and call `SceneManager.enter_pvp_battle(local_idx,
opp_deck, ante_coins)`. On battle end the winner's `_on_pvp_battle_ended_coop(did_win)`
restores the pot (`add_coins(ante_coins * 2)`). For **unwagered** duels the flow is
unchanged: no coins awarded, same "no cards/XP" result.

`BattleResultUI.show_pvp_result(did_win, coins_delta)` shows `"+N coins (wagered)"` in gold
or `"-N coins (wagered)"` in red when `coins_delta != 0`. The Continue button emits
`GameBus.pvp_battle_ended(did_win)`, which SceneManager handles by restoring the shared
world. **Flee** (pause menu) becomes a surrender; an **opponent disconnect** mid-battle
starts a 45 s reconnect grace window (GID-102 / TID-372, below) before becoming a
forfeit win for the remaining player (if the whole session ended, the client routes
to the menu).

**Champion record (GID-101 / TID-368):** `SessionState` character records carry
`pvp_wins`, `pvp_losses`, `pvp_streak`, and `pvp_best_streak` (added in v3 migration).
`_on_pvp_battle_ended_coop` increments wins/streak or losses/resets streak and
writes the updated record back via `SessionStore.update_member` + `mark_dirty`.
A streak ≥ 3 earns the informal "Champion" status (visible in the session roster label).

**Ranked rating (GID-102 / TID-370):** character records also carry `pvp_rating`
(starts `1000`) and `pvp_games` (added in **v4** migration). The rating math lives in
the pure, unit-tested **`game_logic/net/RatingMath.gd`** (mirrors `BattleNetProtocol`):
standard ELO — `expected_score(a, b) = 1 / (1 + 10^((b-a)/400))`,
`updated(r, opp, score, games) = clamp(r + K·(score − expected))` — with a larger
placement K (`K_PLACEMENT = 64`) for the first `PLACEMENT_GAMES = 10` games settling to
`K_BASE = 32`, a `MIN_RATING = 100` floor, and `score` 1.0/0.0 (0.5 reserved for a draw).
Because the **authority owns both combatants' records**, `_on_pvp_battle_ended_coop`
calls `_update_pvp_ratings(state, host_token, host_won)`: it resolves the opponent token
from the duel peer (`_pvp_ante_peer1`, set in `_enter_pvp` / `_enter_pvp_wagered`; the
host-accepts-incoming path now sets `_challenge_target_peer = from_id` so it is recorded
there too) via `_session_token_by_peer`, computes both zero-sum-ish ELO deltas, bumps
`pvp_games`, and writes both records (`update_member` + `mark_dirty`). A client never
rates itself — only the host runs this. The **cross-session leaderboard** is *derived*
(no second source of truth): `SessionState.get_leaderboard(limit)` sorts `members` by
`pvp_rating` desc (ties → games, then token) returning `{token, name, rating, games,
wins, losses}` rows. The dedicated server (GID-097) is the canonical ladder host. This
is the data foundation TID-373 (ranked UI) builds on. Single-player hits none of it.
**Known gap:** opponent *champion* stats (wins/losses/streak) are still host-only
(TID-368 behaviour) — only the rating is updated for both sides here (see BID-025).

### Reconnecting into an in-progress duel (GID-102 / TID-372)

A **1v1 PvP duel** (listen-server or dedicated-server-refereed) survives a dropped
**client** combatant for a 45 s grace window, instead of an immediate forfeit. Team
duels (TID-371) and a dropped host/referee are out of scope for this slice — both still
end the battle immediately, as before.

**Why this can't be the WorldScene identity handshake (the originally-proposed
design):** `enter_pvp_battle`/`enter_pvp_referee` **detach WorldScene**
(`get_tree().root.remove_child`) on every peer mid-duel, including the dedicated
server's own WorldScene while refereeing. The identity broadcast/reply and the GID-095
character handshake all live on `WorldScene`/`NetSync`, so a peer reconnecting mid-duel
cannot complete a normal join — there's no live `/root/WorldScene/NetSync` to land on.
`BattleScene`/`BattleNetSync`, by contrast, stay alive at the fixed path
`/root/BattleScene/BattleNetSync` on every participant for the whole duel — the one
stable channel reconnect can actually use.

**Design — the reconnecting client decides locally, the host/referee just waits:**

- **Client-side resume memory — `NetworkManager.set_pvp_resume(local_idx, opponent_deck,
  ante_coins)` / `clear_pvp_resume()` / `has_pvp_resume()` / `get_pvp_resume()`.** A
  small in-memory (never persisted to disk) record set by `BattleScene._setup_pvp_battle`
  for the client side only (not the host/referee — only a disconnected client
  reconnects in this slice). Survives `_reset_session()` (called by `join()`/`host()` to
  tear down a stale peer before reconnecting) — **only an explicit `leave()` clears
  it**, so the record outlives the very disconnect it exists to recover from.
- **`MultiplayerLobbyScene._on_connection_succeeded`**: checks
  `NetworkManager.has_pvp_resume()` first; if set, calls
  `SceneManager.resume_pvp_battle(local_idx, opponent_deck, ante_coins)` instead of the
  normal `enter_map_coop` landing.
- **`SceneManager.resume_pvp_battle`**: the reconnecting client has no current
  WorldScene to give `enter_pvp_battle` a `_saved_world_scene` to detach/restore later,
  so it first lands in the shared map (`enter_map_coop("madrian")`), `await`s the state
  actually reaching `State.WORLD` (`TransitionManager.transition` is fire-and-forget
  async, so this can't be a synchronous follow-up call), then calls the normal
  `enter_pvp_battle`.
- **Host/referee grace window — `BattleScene._on_pvp_peer_disconnected`**: resolves the
  disconnecting peer's combatant index (listen-server: always 1, the sole client;
  referee: `_pvp_peer_to_idx.get(pid)`), records `_pvp_reconnect_idx`, and starts a
  45 s one-shot `Timer` instead of calling `_finish_pvp` immediately. On timeout
  (`_on_pvp_reconnect_grace_expired`), falls back to the original immediate-forfeit
  behavior.
- **Token verification — `BattleNetSync.announce_reconnect(token)`** (new RPC, client →
  host/referee, sent once at every duel setup — harmless no-op when no grace window is
  pending, i.e. a fresh non-reconnect start). `BattleScene._on_reconnect_announced`
  checks the announced token against the recorded opponent token for the
  mid-grace-window combatant (`pvp_opponent_token` for listen-server, set by
  `WorldScene._enter_pvp`/`_enter_pvp_wagered` from `_session_token_by_peer`;
  `_pvp_idx_to_token` for the referee, set by `enter_pvp_referee` from the same map on
  the dedicated server's `_on_relay_pvp_response`). A **missing recorded token doesn't
  block the resume** — refusing is worse than a same-LAN false accept (same trust model
  as the rest of LAN-only co-op). On match: cancels the timer, and for referee mode
  remaps `_pvp_peer_to_idx` to the new peer id (listen-server needs no peer-id
  bookkeeping at all — `_broadcast_state()` already reaches "all connected peers" and
  incoming-intent routing is hardcoded idx 1 regardless of peer id), then re-broadcasts
  the live state. The rejoined client's own `request_sync` retry loop
  (`_process`/`_pvp_sync_retry_accum`) also converges on it within ~0.4 s regardless.
- **Resume-record lifecycle**: `_finish_pvp` (the single function behind every genuine
  end-of-duel path — win/loss mirror, surrender, grace-timeout forfeit) calls
  `NetworkManager.clear_pvp_resume()`. The one path that must **not** clear it is the
  client's own `_on_pvp_session_ended` (its connection to the duel just dropped) — it
  returns early without declaring a false "win" when a resume record is pending, leaving
  the scene frozen-but-recoverable until the player navigates back to the lobby and
  reconnects (no auto-navigation on `session_ended`, consistent with the existing
  Rejoin-list precedent — `NetworkManager` conflates a host's own `leave()` with a
  client losing the host into the same signal).

**Out of scope (documented):** team duels, a dropped host/referee, and any UI affordance
beyond the existing pause menu / lobby Rejoin list (no "Reconnecting…" overlay).

### Ranked UI & Leaderboard (GID-102 / TID-373)

Surfaces the TID-370 rating data: a leaderboard panel, a rating badge in the session
roster, and a "Ranked" opt-in toggle on the challenge flow so a casual duel never moves
anyone's rating.

**Ranked vs casual flag — `GameState.ranked: bool`.** A *new* dedicated field, not a
reuse of `GameState.friendly_duel`. `friendly_duel` is the unrelated single-player
NPC wager-duel mode (set when `BattleScene.duel_wager > 0` on the non-PvP path; it
disables capture-tracking and companion bonuses) — co-op `_pvp` battles never touch
it. Reusing it would have conflated two different game modes, so `ranked` is its own
field, serialized in `to_dict`/`from_dict` like `coop_battle`, defaulting to `false`.

**Challenge handshake.** A "Ranked: OFF/ON" toggle button sits next to the existing
"Challenge to Battle" button (`WorldScene._ensure_challenge_button`), shown/hidden
together by proximity. `request_battle` / `respond_battle` gained a trailing
`ranked: bool = false` parameter so both peers agree on the flag before either calls
`SceneManager.enter_pvp_battle(local_idx, opponent_deck, ante_coins, ranked)` (which
now takes a 4th `ranked` parameter, threaded into `BattleScene.pvp_ranked` →
`GameState.ranked`, mirroring exactly how `ante_coins` already crosses the same
SceneManager → BattleScene boundary). `WorldScene._pvp_ranked` caches the agreed flag
for the active duel and gates the TID-370 `_update_pvp_ratings` call in
`_on_pvp_battle_ended_coop` — **casual duels never touch rating**. The wagered-duel
flow (`_enter_pvp_wagered`) does not currently expose a ranked option — composing
ranked + wagered is left for a follow-up (see BID-029, a related pre-existing gap:
there is no HUD entry point to *initiate* a custom-ante wager at all today).

**Leaderboard data flow.** A client never has direct `SessionStore` access, so the
authority pushes snapshots. `WorldScene._leaderboard_rows: Array` caches the last
`SessionState.get_leaderboard(20)` result (rows are already JSON-primitive —
`{token, name, rating, games, wins, losses}` — sent as-is over the wire, the same
"no dedicated wire-format helper needed" situation as `recv_party_bounties_snapshot`).
Broadcast points (host only, via `_broadcast_leaderboard(target_peer := 0)`):

- **Late join:** `_send_character_to_peer` unicasts the current leaderboard to a
  newly-identified peer right alongside the character + party-bounty snapshot sends.
- **After a ranked duel:** `_on_pvp_battle_ended_coop` calls `_broadcast_leaderboard()`
  to all peers once `_update_pvp_ratings` has written the new records.
- **On demand:** a client's `NetSync.submit_leaderboard_request()` (e.g. opening the
  panel) is answered by `_on_leaderboard_request_submitted` unicasting back.

**Roster rating badge.** The existing session roster (`_build_coop_roster` /
`_refresh_coop_roster`) appends a `[rating]` badge after each name — `[—]` until the
first snapshot arrives — via `_rating_badge_for_token(token)`, which looks the token
up in a `token -> row` map built on demand by `_leaderboard_lookup_by_token()`. The
local row uses `MpProfile.get_token()`; remote rows use `_remote_identities[pid]["token"]`.

**Leaderboard overlay — `scenes/ui/LeaderboardOverlay.gd`.** Extends
`res://scenes/ui/BaseOverlay.gd` by path string and is instantiated via `.new()` —
confirmed this is the actual convention `SettingsScene` and `MultiplayerLobbyScene`
both use before picking it. Viewport-relative throughout, rebuilt on
`NOTIFICATION_RESIZED`. Lists the cached rows: rank, name, rating, W/L; shows a
placeholder row when no ranked duels have been played yet. Opened via an
always-visible "Leaderboard" HUD button (top-left, alongside the other social/utility
buttons — a touch/click target, no separate keybind, consistent with how
Trade/Spectate/Emote are reached) that calls `_toggle_leaderboard_overlay()`, which
requests a fresh snapshot on open (host computes locally; client sends
`submit_leaderboard_request`).

**Rating-delta display — a sequencing constraint, not a corner cut.**
`BattleResultUI.show_pvp_result(did_win, coins_delta)` is shown by
`BattleScene._finish_pvp` **before** `GameBus.pvp_battle_ended` fires, but
`_update_pvp_ratings` (the only place that computes a delta) only runs **after** that
signal fires, inside `WorldScene._on_pvp_battle_ended_coop` — and only on the host.
Showing the delta on the same result screen would require either threading an
unverified number through the battle-end RPC (an integrity smell — a client would
have to trust a delta it can't re-derive) or restructuring the host-authoritative
battle-end ordering the rest of co-op relies on; both are out of scope here. Instead,
once `_update_pvp_ratings` computes both deltas, the host shows its own as a
`GameBus.hud_message_requested` toast ("+18 rating" / "-14 rating") and unicasts the
opponent's via the new `recv_rating_delta(delta: int)` RPC, which the opponent's
`_on_rating_delta_received` also surfaces as a toast — both appear once the player is
back in the world, after the result screen's Continue button, using the same
low-risk end-of-action toast pattern other features already rely on.

### Leaderboards (GID-102 / TID-379)

The **PvE counterpart** to the ranked rating board above: authority-persisted
best-score boards for the **Endless Spire** roguelike (GID-038) and **co-op joint
boss clears** (GID-099). Never touches `pvp_rating`/`pvp_games` — a completely
separate model, RPC pair, and cache, all carrying a `pve`/`_pve_` marker in their
names specifically to avoid colliding with the TID-373 symbols above
(`recv_leaderboard`, `submit_leaderboard_request`, `_leaderboard_rows`,
`_broadcast_leaderboard`, …).

**Storage — `SessionState.leaderboards: Dictionary`.** Shape `{spire: Array,
coop_clears: Array}`; each entry is `{token, name, value, day}`. Unlike the ranked
board (which is *derived* from `members` on every read), these are stored as their
own arrays — a player's best PvE result should survive independently of whatever
else is in their character record. `record_pve_score(board, token, name, value, day)`
is the single pure mutator: insert-or-update-if-better (a worse or equal `value`
for a token that already has an entry is a silent no-op — "only your own better
score overwrites"), then re-sort desc by `value` (ties broken by earliest `day`,
then token) and cap to `PVE_LEADERBOARD_CAP = 20`. `get_pve_leaderboard(board,
limit)` and `get_pve_leaderboards_snapshot()` (both boards together, for the wire)
are the read side. `CURRENT_SESSION_VERSION` bumped 5 → 6 (renumbered during
integration; TID-376's party stash claimed v5 first); the migration backfills
`leaderboards = {spire: [], coop_clears: []}` when absent, and a non-dict/garbage
`leaderboards` field on load falls back to the same empty shape rather than
crashing (mirrors every other tolerant-fallback field in this file).

**Submission hooks.** Both are connected **permanently** in `WorldScene._ready`
(same "WorldScene detaches during battle" reasoning as `pvp_battle_ended` above),
not inside `_setup_coop`:

- **Endless Spire** (`GameBus.spire_run_ended(stats)` → `_on_spire_run_ended_leaderboard`):
  submits `stats.floors_cleared` to the `"spire"` board — but **only when
  `NetworkManager.is_active()`**, per the task's explicit call-out that Spire is
  single-player and a co-op session may not even be running during a run. When no
  session is active, the result is purely local. **Decision: no device-local
  MpProfile best was added for the fully-offline case** — `SaveManager.spire_best_floor`
  already tracks the player's all-time-best floor and already drives the "New
  Record!" badge on `RunSummaryScene`, so a second offline-best store would just be
  a second source of truth for the same fact. The session-scoped board is the
  actual deliverable; the offline case was already solved before this task.
- **Co-op boss clears** (`GameBus.coop_pve_battle_ended(did_win)` →
  `_on_coop_pve_battle_ended_leaderboard`): submits on a party win, while
  `NetworkManager.is_active()`, to the `"coop_clears"` board. **Value = party size
  at battle end** (`multiplayer.get_peers().size() + 1`) — a v1 simplification.
  Neither the party-scaled boss tier (`CoopBattleScaling.scale_boss_tier`, computed
  inside `BattleScene._build_coop_pve_state`) nor a clear-duration timer are
  threaded back out to `GameBus.coop_pve_battle_ended` today, so party size is the
  only signal reliably available at the point WorldScene can submit a score without
  inventing new cross-battle plumbings. Logged as BID-031 for a future task to
  enrich the ranking signal (tier and/or clear time).

**Authority-records-then-broadcasts, same as party bounties.** `_submit_pve_score(board,
value)` is the single routing function: on the host it calls
`SessionState.record_pve_score` directly via `SessionStore.get_state()`, marks dirty,
and broadcasts; on a client it sends the new `NetSync.submit_pve_leaderboard_score(board,
value)` RPC, which the host's `_on_pve_leaderboard_score_submitted` resolves to a token
via the existing `_session_token_by_peer` map (the same lookup the ranked board and
champion-record paths use) before recording + broadcasting.

**Broadcast/snapshot — `NetSync.recv_pve_leaderboards(snapshot: Dictionary)`.**
Fired on late-join (`_send_character_to_peer` unicasts it right alongside the
existing character/party-bounty/ranked-leaderboard sends) and after every
`record_pve_score` write, via `WorldScene._broadcast_pve_leaderboards(target_peer :=
0)` — structurally identical to `_broadcast_leaderboard` but pushing the
`{spire, coop_clears}` snapshot instead of ranked rows. A client can also request a
fresh snapshot on demand via `NetSync.submit_pve_leaderboard_request()` (answered by
`_on_pve_leaderboard_request_submitted`), mirroring `submit_leaderboard_request`.

**UI — extended the existing overlay with tabs, not a second panel.** Per the task's
explicit guidance ("a unified 'Rankings' overlay beats two near-identical panels"),
`scenes/ui/LeaderboardOverlay.gd` gained a 3-button tab row (**Ranked** / **Spire** /
**Co-op Clears**) above the existing header. `_active_tab` picks which cached array
renders; `refresh_rows(rows)` (the pre-existing TID-373 method) still feeds the
Ranked tab unchanged, and a new `refresh_pve_rows(snapshot)` feeds the Spire/Co-op
tabs from the `{spire, coop_clears}` shape. Columns adapt per tab (Ranked: Rating/W-L;
Spire/Co-op: Value/Day) via `_build_header()`. `WorldScene._toggle_leaderboard_overlay()`
now requests **both** snapshots on open (ranked + PvE, each via its own
host-computes-locally-or-client-requests branch) so every tab is populated the
moment the panel opens, regardless of which tab happens to be active — switching
tabs is a pure local re-render of already-cached data, no new network round trip.

### Spectating a duel (GID-101 / TID-367)

Non-combatant party members can **watch** an in-progress PvP duel read-only.

- `NetSync.recv_pvp_active(in_battle, peer_a, peer_b)` (reliable, host→others) is
  broadcast when a duel starts or ends, tracking which two peers are fighting.
- A **"Spectate"** HUD button appears for non-combatants when `_pvp_active_peers` is
  non-empty. Pressing it sends `NetSync.request_spectate_pvp()` → host grants → authority
  calls `SceneManager.enter_pvp_spectator()` on the requesting peer.
- `enter_pvp_spectator()` launches BattleScene with `_pvp_spectating = true`,
  `_local_player_idx = 0` (host's perspective). All input is blocked (`_can_local_act()`
  returns false); `_broadcast_state()` fans mirrors to the `_spectators` list so the
  spectator sees live state.
- `BattleNetSync.request_spectate()` / `stop_spectate()` register/deregister spectators
  during the battle.
- **WorldScene detach/re-attach:** when a PvP battle starts, SceneManager removes
  WorldScene from the tree. The `pvp_battle_ended` signal fires while WorldScene is
  detached (`_net_sync` is nil), so the broadcast of `recv_pvp_active(false)` is
  deferred via `_pvp_ended_pending_broadcast = true` and fires on `_enter_tree()`.

### Social features (GID-101 / TID-365 & TID-366)

#### Emotes & map pings

- **`game_logic/net/SocialSync.gd`** — pure encode/decode for emote packets
  `[emote_id, map]` and ping packets `[x, z, kind, color_hex, map]`. Mirrors
  `AvatarSync`. Six presets: `greet`, `thanks`, `help`, `attack`, `retreat`, `laugh`.
- **Emote wheel**: a HUD button opens a 6-button `GridContainer` radial. Pressing a
  preset broadcasts `NetSync.recv_emote(payload)` (unreliable_ordered) and shows a
  transient `Label3D` bubble above the local avatar. Remote players receive it (same-map
  filter via `_remote_player_maps`) and show it via `RemotePlayer.show_emote(text)` —
  a `Label3D` above the name tag, auto-hidden after `EMOTE_DURATION = 3.0` seconds.
- **Ping mode**: toggled with a HUD button; in ping mode, a world tap fires
  `_handle_ping_tap` (ray-plane XZ intersection) → `NetSync.recv_ping(payload)`
  (unreliable_ordered). A torus mesh marker with emission material pulses at the
  pinged world position for `PING_DURATION = 5.0` seconds, then is freed. Kinds:
  `"place"` (map location) and `"enemy"` (enemy marker). Color matches the pinger's
  avatar color.

#### Card trading & gifting

- **`game_logic/net/TradeSync.gd`** — encode/offer/update helpers. `STATUS_PROPOSED`
  / `STATUS_COMPLETED` / `STATUS_CANCELLED`.
- Flow (proximity-gated, same as PvP challenge button): initiator clicks **"Trade"**
  → `submit_trade_offer(payload)` → host validates giver still owns the card in
  `SessionState`; if valid, sends `recv_trade_update(proposed)` to the target → target
  sees Accept/Decline panel → `submit_trade_confirm(trade_id, accepted)` → host executes
  `_transfer_card_in_session` (removes instance from giver's `owned_cards`/`player_deck`,
  re-keys UID into receiver's namespace, adds to receiver's `owned_cards`) → broadcasts
  `recv_trade_update(completed)` to both; on decline, `cancelled`.
- Unique cards (`is_unique = true`) are blocked from trading. All persistence goes
  through `SessionStore.mark_dirty()` — never `save_slot_*.json`.

#### Chat (GID-102 / TID-374)

- **`game_logic/net/ChatSync.gd`** — pure encode/decode for chat packets
  `[text, kind, map]`, scene-free and mirrors `SocialSync.gd` structurally. Two kinds:
  `KIND_QUICK = "quick"` and `KIND_TEXT = "text"`. Six fixed quick-chat presets
  (`QUICK_PRESETS`, order fixed for wire compatibility): "On my way", "Need help",
  "Nice!", "Wait", "Let's battle", "Trade?".
- **Sanitization happens in the pure helper**, not the UI, so the authority and every
  client compute the identical result: `_sanitize()` strips ASCII control characters
  (0x00–0x1F and 0x7F) and caps the result to `MAX_TEXT_LEN = 120` characters.
  `encode_text()` sanitizes the raw input; `decode()` *also* re-sanitizes the decoded
  text defensively, so a forged or corrupted payload can never smuggle control
  characters or exceed the cap on the receiving end either. `decode()` is fully
  defaulted and garbage-tolerant (never throws), exactly like `SocialSync.decode_*`.
- **RPC — `NetSync.recv_chat(payload: Array)`.** Unlike avatars/emotes/pings, this is
  **reliable** (not `unreliable_ordered`): the task explicitly calls out that chat
  messages must not be dropped, and chat is low-rate enough that reliable's extra
  overhead is irrelevant. Same `any_peer` / `call_remote` shape as `recv_emote`, so it
  benefits from the same automatic host server-relay (`SceneMultiplayer.server_relay`)
  that fans a client's broadcast out to every other client.
- **Same-map filtering matches the emote behaviour for consistency**: `_on_chat_received`
  decodes the payload and, if the sender's `map` is non-empty and differs from the
  local `map_name`, the message is **dropped** (not shown-but-tagged) — identical to
  `_on_emote_received`'s early-return. Sender display name + color are resolved from
  `_remote_identities[peer_id]` (the existing identity handshake), exactly like the
  emote bubble and roster.
- **HUD panel** (`WorldScene._ensure_chat_ui`): a viewport-relative `ScrollContainer` +
  `VBoxContainer` chat log (top-left, above the party bounty panel), retaining the last
  `ChatSync.LOG_MAX_LINES = 40` lines (oldest evicted first). Each line shows
  `[HH:MM] Name: text` colored by the sender's avatar color. The log stays **always
  visible** while in co-op (no auto-fade, no show/hide toggle) — the simplest option,
  matching the always-visible party bounty panel, and chat is low-frequency enough
  that it doesn't clutter the screen.
- **Quick-chat row**: reuses the emote-wheel's `GridContainer` radial-button pattern
  (`_show_chat_quick_panel`), built from `ChatSync.QUICK_PRESETS`, opened via a "Chat"
  HUD button (`_chat_toggle_btn`).
- **Free-text input**: a `LineEdit` (`_chat_input`) + "Send" button are always present
  in the HUD (desktop-first, but tappable on mobile too — satisfies the parity rule
  without hiding the control behind a second tap). The "Chat" HUD button additionally
  opens the quick-chat row and focuses the input, so a touch-only user can reach both
  quick presets and free text from one tap. Desktop also gets a keyboard shortcut:
  pressing Enter/Numpad-Enter while not already focused in the chat input focuses it
  (`_unhandled_input`, same raw-keycode pattern as the existing `KEY_G`/`KEY_D`
  shortcuts), mirroring the mobile "Chat" button per the CLAUDE.md parity rule.
- **Battle chat is out of scope for this slice.** The relay path during a PvP duel is
  `BattleNetSync`, not `NetSync` — bridging the two relay layers safely (e.g. so a
  chat line sent mid-duel doesn't leak to/from spectators incorrectly) was judged not
  "genuinely cheap" once the world-HUD version worked, so it was deliberately cut.
  Revisit if a future task wants in-duel chat; the same `ChatSync` pure helper can be
  reused, only the relay/RPC wiring would need to be duplicated onto `BattleNetSync`.

### Party stash (GID-102 / TID-376)

A **session-owned chest** any co-op member can deposit cards/coins into and withdraw
from — unlike trading, it needs no other player online and no proximity. It also lays
the transfer plumbing the auction house (TID-378) is expected to reuse.

- **Storage — `SessionState.stash: Dictionary`**, shape `{cards: Array, coins: int}`.
  `cards` holds full card instance dicts (same shape as a member's `owned_cards`, via
  `CardInstanceUtil`). Authority-owned, persisted via `SessionStore`, added in the **v5**
  migration (`CURRENT_SESSION_VERSION` bumped 4 → 5): a pre-v5 session file gets
  `stash = {cards: [], coins: 0}` backfilled on load.
- **Transfer plumbing — `game_logic/net/StashTransfer.gd`.** A new **pure, unit-tested**
  sibling to `CardInstanceUtil`/`RatingMath` (no scene deps) that generalizes the
  dupe-proof re-key mechanic `_transfer_card_in_session` (trading) already uses, to a
  **member ⇄ stash** move:
  - `deposit_card(stash, member_rec, card_uid)` — removes the instance from
    `member_rec.owned_cards`/`player_deck`, blocks it if the card's template has
    `is_unique = true` (checked via `CardRegistry.get_template(template_id)`, the
    correct way to read it since instance dicts never carry `is_unique` themselves —
    see BID-030), re-keys the uid to `"<uid>_stash_<n>"`, and appends it to
    `stash.cards`.
  - `withdraw_card(stash, member_rec, stash_uid, member_token)` — the inverse: removes
    the instance from `stash.cards`, re-keys the uid to `"<stash_uid>_w_<token_prefix>"`,
    appends to `member_rec.owned_cards`.
  - `deposit_coins(stash, member_rec, amount)` / `withdraw_coins(...)` — simple int
    moves with insufficient-funds / non-positive-amount guards.
  - All four return `{ok: bool, reason: String, stash: Dictionary, member: Dictionary}` —
    callers always get back safe, defensively-normalized copies to write back onto the
    live `SessionState`, even on failure.
- **RPCs — `NetSync.gd`** (reliable, `any_peer`/`call_remote`, mirrors the trade RPCs —
  proximity is **not** required since the stash is global to the session, unlike trade):
  - `submit_stash_deposit(payload)` / `submit_stash_withdraw(payload)` (client →
    authority). `payload = {kind: "card"|"coins", card_uid: String, amount: int}`.
  - `recv_stash_update(snapshot)` (authority → all/one) — the current `{cards, coins}`
    stash contents.
- **Authority flow — `WorldScene.gd`**: `_on_stash_deposit_submitted` /
  `_on_stash_withdraw_submitted` resolve the sender's token (via
  `_session_token_by_peer`, or the local `MpProfile` token when the host acts on its own
  behalf), call into `StashTransfer`, write the returned `stash`/`member` dicts back onto
  `SessionState` + `SessionStore.mark_dirty()`, then `_broadcast_stash_update()` to all
  peers. **Keeping the actor's in-memory character in sync**
  (`_apply_updated_member_to_actor`): because the periodic `_tick_session_persist` tick
  (every 5 s) would otherwise overwrite the just-mutated `SessionState` member record
  with the acting peer's now-stale in-memory `SaveManager` fields, the host re-adopts
  its own updated record directly (`adopt_session_character`) and a remote client actor
  is sent a fresh `recv_character(updated_member, resume=false)` mirror (no position
  restore — this isn't a reconnect, just a refresh).
- **Late-join**: `_send_character_to_peer` unicasts `recv_stash_update` with the current
  `SessionState.stash` alongside the character/party-bounty snapshot sends.
- **HUD — `scenes/ui/PartyStashOverlay.gd`** (new): extends `BaseOverlay` by path
  string, instantiated via `.new()` (matches `LeaderboardOverlay`/`SettingsScene`
  convention), viewport-relative, rebuilt on `NOTIFICATION_RESIZED`. Two scrollable
  columns — "My Collection" (deposit buttons; unique cards are filtered out of this
  list) and "Stash" (withdraw buttons) — plus a coins row with fixed-step
  deposit/withdraw buttons. Opened via an always-visible "Stash" HUD button (global to
  the session, not proximity-gated, same rationale as the leaderboard button) —
  touch/click target, mobile + desktop parity.
- **Authority-only writes**: clients never mutate `SessionState` directly; only the
  authority does, via `SessionStore` — same isolation invariant as trading/bounties.

### Shared party bounties (GID-101 / TID-369)

Party bounties are co-op goals the whole party works toward together.

- **Storage**: `SessionState.party_bounties: Array` — shared state owned by the host
  authority, persisted via `SessionStore`. Shape per bounty:
  `{id, type, target, count, progress, contributors: [tokens], completed}`.
- **Generation**: host calls `_setup_party_bounties()` in `_setup_coop()` if
  `party_bounties` is empty — generates 3 daily bounties via
  `BountyGen.generate_daily(WORLD_SEED, day_index)` so all peers compute the same list.
- **Progress flow** (authority-records-then-broadcasts): any subsystem calls
  `WorldScene.submit_party_bounty_progress(bounty_type, match_data)` — on the host this
  increments the matching bounty directly; on a client it sends
  `NetSync.submit_party_bounty_progress(type, data)` (reliable) to the host, which
  increments, persists, and fans `recv_party_bounty_update(payload)` to all peers.
- **Completion rewards**: when a bounty's `progress >= count`, the host iterates all
  session members and calls `SessionStore.ensure_member(token, name)` to distribute
  coins/cards; `completed` is set to `true`; a notification HUD message shows.
- **Late-join snapshot**: `_send_character_to_peer` sends `recv_party_bounties_snapshot`
  to the joining peer after the character record. Clients build their HUD panel from this.
- **HUD panel**: viewport-relative `VBoxContainer` panel in the world HUD, showing
  each bounty's `target` + `progress/count` + a check mark on completion. Refreshed
  on each `recv_party_bounty_update`.

### Team Duels (GID-102 / TID-371)

2v2 team PvP: two teams of two allies fight each other, reusing the same
host-authoritative state-mirroring model as 2-player PvP, generalized to 4 participants.
**No accept/decline and no wagers in v1** — the host assigns teams from the connected
4-peer session and starts the duel immediately for everyone (deliberately minimal
team-formation UI, per the task's scope).

**Model — `GameState.team_battle` / `player_teams`.** `setup_team_battle(team_a_setup,
team_b_setup)` builds exactly 4 `PlayerState`s, **interleaved**
`[teamA_0, teamB_0, teamA_1, teamB_1]` (`player_teams = [0,1,0,1]`) so the existing
`(idx+1) % size` turn rotation alternates teams every turn with zero rotation changes.
`is_game_over()`/`winner()` are team-aware: a team loses when **both** its members'
heroes are dead; `winner()` returns the surviving team id (0/1).

**Targeting — auto-pick + manual focus, not per-effect wiring.** Rather than threading
an explicit target through every spell-effect match arm, `GameState.opponent()` gained a
`team_battle` branch returning the alive enemy-team member with the **lowest hero HP**
(`_get_lowest_hp_enemy_team_member`, sibling to the co-op-PvE boss-targeting helper) —
this is the auto-target used by anything that doesn't have a manual choice (AOE/random/
hand-disruption spell effects, hero powers' `active_damage_all`, etc. — a documented v1
simplification: these always hit the single auto-picked enemy's board/hand, never both
enemies' combined). `BattleScene._opp_idx()` adds a **manual focus** override:
`_team_focus_target_pidx` (set by tapping an enemy panel in the new team status bar) is
used instead of the auto pick when it still names a living enemy-team member. Because
every existing render/target-building call site already routes through `_opp_idx()`
(`EnemyArea` board/hand/hero, `_pvp_target_dict_for_card`, `_attempt_attack`'s slot
lookup), focus propagates to spell minion/board targeting and attack-target-slot
resolution **for free** — no per-feature target-selection code was needed for those.
Two cases needed small, contained wiring since the slot index alone is ambiguous between
2 possible enemy boards:
- **Attacks**: `BattleNetProtocol.encode_attack`'s existing (previously-unused)
  `target_pidx` parameter now carries the attacker's `_opp_idx()`; the authority's
  `_apply_remote_intent` resolves `opp_idx` via `_resolve_intent_opp_idx` (validates the
  sent `target_pidx` names a living enemy-team member, else falls back to
  `_state.opponent_idx()`).
- **Hero-targeted spells** (only `deal_damage_single`'s hero branch reads
  `explicit_target.get("type") == "hero"`): the wire target dict carries
  `{"hero": true, "pidx": N}`; `SpellEffectResolver` uses `_state.players[pidx].hero`
  when present.
- **Single-minion-targeted spells** (`deal_damage_single`, `lifesteal_hit`,
  `curse_minion` — the only `ENEMY_TARGETED_EFFECTS` that remove a dead explicit target)
  need no wire change: the wire `{"side", "slot"}` dict already carries the real
  `CardInstance`, and a new `SpellEffectResolver._find_card_owner(card, fallback)`
  resolves the *actual* owner by board-membership scan instead of assuming `opponent`,
  so removal works correctly even when the manually-focused target differs from the
  GameState-level auto pick.

**Networking — own RPC set, mirrors co-op PvE.** `BattleNetSync` gains
`send_team_intent` / `sync_team_state` / `team_battle_ended` / `request_team_sync`
(reliable), kept distinct from the PvP and co-op-PvE RPCs. `BattleScene` gains a
`_team_pvp` section mirroring `_coop_pve` structurally: `_setup_team_battle`,
`_build_team_battle_state` (host-only, builds all 4 decks from `_team_decks`/
`_team_assignments`), `_on_team_state`/`_on_team_intent`/`_on_team_sync_request`/
`_broadcast_team_state`, `_team_check_game_over`, `_on_team_battle_ended`/
`_finish_team_battle` (minimal result: HUD message, 2 s pause, then
`GameBus.team_battle_ended.emit(did_win)` — no card/coin rewards, duel-style like
unwagered 2-player PvP), `_process_team_sync`.

**Team status bar.** A read-only `_build_team_arena_layout`/`_refresh_team_panels` pair
(new, parallel to the GID-100 ally bar, not a generalization of it) shows all 4
participants' HP/mana, grouped my-team-first then enemy-team. The two enemy panels are
tappable (`_team_focus_target_pidx`); the two ally panels are informational only (no
per-teammate spell targeting in v1).

**Team formation — `WorldScene`.** A host-only **"Team Duel (2v2)"** HUD button
(`_ensure_team_duel_button`/`_update_team_duel_button_visibility`) appears when exactly
3 clients are connected (4 total players). Pressing it (`_start_team_duel`): sorts the
connected peer ids for determinism, lays out the 4 absolute `GameState` indices as
`[host, clients[1], clients[0], clients[2]]` (so `player_teams = [0,1,0,1]` puts the
host's chosen partner, `clients[0]`, on the host's team), resolves each participant's
**real** deck via `_team_deck_for_peer` (reads the host-authoritative GID-095
`SessionState` member record directly — `owned_cards` + `player_deck` UIDs — so **no
extra deck-collection RPC round-trip is needed**, unlike the proximity-gated 1v1
challenge flow), and `rpc_id`s `NetSync.notify_team_duel_start(my_idx, team_assignments,
all_decks)` to each client before calling `SceneManager.enter_team_battle` itself.

**Rating — team-average expected score (GID-102 / TID-370 integration).** Host-only
`WorldScene._on_team_battle_ended_coop` (connected permanently to
`GameBus.team_battle_ended`, like `_on_pvp_battle_ended_coop`) uses the formation
`_start_team_duel` recorded (`_active_team_duel_peer_ids`/`_active_team_duel_teams`) to
resolve all 4 tokens, computes each team's **average rating**, then applies
`RatingMath.updated` per player against the *opposing team's average* (not pairwise per
opponent) scored 1.0/0.0 for their team's win/loss — the "team-average expected score"
approach. A no-op for every non-host peer and once the formation has been consumed.

**Bugs found and fixed while generalizing the opponent-index plumbing (BID-026):**
`BattleScene._execute_attack` (the host's own local attack resolution) hardcoded
`_state.players[1]`/`[0]` instead of `_opp_idx()`/`_my_idx()` — dormant for solo/2-player
PvP but a real bug in co-op PvE (the boss is never at index 1 for any valid battle; a
host's attack on the boss damaged the wrong ally). `_apply_remote_intent`'s `opp_idx`
had the same unconditional `1 - player_idx` problem for ally-client relayed attacks. Both
are fixed via the new `_resolve_intent_opp_idx` helper. See BID-026/027/028 for the
residual gaps (no co-op-PvE attack-resolution smoke test; the AI-turn boss path has the
same hardcoded-1 issue but is unreached by team PvP so was left for a follow-up).

**Out of scope for v1** (documented, not silent): individual team-invite accept/decline,
wagered team duels, a live 4-peer ENet loopback smoke test (covered instead by 17 pure
`GameState` unit tests — `test_team_battle_state.gd`), and 3v3/4v4 (`setup_team_battle`
is fixed at 2v2).

### Ghost duels (GID-102 / TID-377)

A **ghost duel** lets a player battle an **AI-piloted snapshot** of another (possibly
offline) session member's deck. This is the **only PvP-flavored mode in the game that
needs zero live connection** — no `NetSync`, no `BattleNetSync`, no reconnection
concern whatsoever, unlike every other duel/PvP mode documented above.

#### Not PvP host-mirroring — a plain solo battle

A ghost duel is the existing **single-player battle path**
(`_local_player_idx == 0`, no `_pvp`/`_coop_pve`/`_team_pvp` flags), with
`BasicAI` (`ai/BasicAI.gd`) piloting a deck built from the snapshot — exactly the
same mechanism an NPC tavern duel (GID-037, `SceneManager._on_duel_requested`) uses
for its enemy deck. `BattleScene` gains one small, inert-unless-set flag,
`_ghost_duel: bool` (+ `_ghost_duel_reward: int`), set by
`SceneManager.enter_ghost_duel` before `_ready`, mirroring how `_pvp`/`_coop_pve`
are set. It is deliberately **not** built on `duel_wager`/`GameState.friendly_duel`:
that path (`BattleResultUI.show_duel_loss`) deducts the wager amount as a real coin
stake on a loss, which is correct for a live NPC wager but wrong here — nothing was
ever staked against an offline AI opponent.

#### Snapshot extraction — `SessionState.get_ghost_snapshot(token) -> Dictionary`

Pure, derived on demand from `members[token]` — **no second source of truth**
(nothing is persisted separately for "ghost" purposes). Returns
`{token, name, deck: Array[String], rating}`. The member's `player_deck` is a list
of card-instance **UIDs** (per-instance rolled stats); each UID is resolved to its
`template_id` via the matching `owned_cards` entry, because the ghost only needs a
playable deck of template ids, not the opponent's specific rolled stats. A UID with
no matching `owned_cards` entry is silently skipped (the ghost fields a slightly
smaller deck) rather than crashing — a hand-edited or corrupt session file must
never break a duel. `rating` reads `pvp_rating` defaulting to `1000` (the same
default `SessionState.make_starter_character` seeds), so this reads correctly
whether or not the TID-370 rating model has landed. Returns `{}` for a blank token,
an unknown token, or a corrupt (non-Dictionary) member record — never throws.

#### Entry point — host-only "Ghost Duels" HUD button

`WorldScene._ensure_ghost_duel_button()` is gated on `SessionStore.is_open()`
(not `NetworkManager.is_active()`) — a **client never opens `SessionStore`
locally** (only the authority does, in `_setup_session`), so this is a
**host-only** feature in the current slice: a client has no local `SessionState`
to list opponents from. The button is always visible once available (not
proximity-gated like Trade/Spectate — this is async, not a live-nearby-player
interaction). Pressing it opens `scenes/ui/GhostDuelOverlay.gd` (`extends
BaseOverlay` by path string, `.new()`-instantiated, viewport-relative, mobile +
desktop parity — a simple list + button, matching the task's "keep this UI
genuinely simple" guidance), populated from `SessionStore.get_state().members`
(excluding the local host's own token — dueling your own live snapshot is a no-op
curiosity, not the intended use). Each row shows name + rating + a "Ghost Duel"
button that resolves the snapshot and calls `SceneManager.enter_ghost_duel`.

#### Entering the battle — `SceneManager.enter_ghost_duel(opponent_snapshot)`

Builds an `enemy_data` dict (`display_name: "<name> (Ghost)"`, `enemy_type: ""`,
`is_boss: false`, `drop_pool: []`, `coin_reward: 0`, `enemy_deck:
opponent_snapshot.deck`) and enters through the exact same
`_battle_scene_packed.instantiate()` + `TransitionManager.transition` path
`_on_duel_requested` uses, with the same `DECK_MIN` guard. Guards against an empty
snapshot deck up front so a bad caller can never launch a battle with nothing to
fight. `BattleScene`'s plain `else` setup branch builds `_state.players[1]` from
`enemy_data["enemy_deck"]` unchanged (`Array[String]` + `.assign()`, per CLAUDE.md's
variant-inference guidance) — no new deck-building path was added.

#### Rewards — coins only, win-only; explicitly NO rating change

**Decision (documented, not a silent default): a ghost duel never moves PvP
rating, win or lose.** The opponent is AI-piloted, not the real remote player — if
rating moved here, a player could farm free ELO by dueling their own cached
snapshot (or a stale/offline friend's) with zero real matched risk. Ghost duels
only ever grant a flat, modest coin reward (`SceneManager.GHOST_DUEL_COIN_REWARD =
25`, roughly half a basic-enemy's coin reward — clearly async, not a substitute
for a real battle or a real PvP duel) on a **win only**; a loss grants and deducts
nothing (there was never a stake). `BattleResultUi.show_ghost_duel_result(did_win,
coin_reward)` (new, mirrors the structure of `show_pvp_result`) shows the result
and a coin line only when `did_win and coin_reward > 0`, then emits
`GameBus.ghost_duel_ended(did_win)`. `SceneManager._on_ghost_duel_ended` applies
the reward **exactly once** (not on the button press, unlike the NPC wager-duel
path) and restores the world, mirroring `_on_duel_won`/`_on_duel_lost` — no card
drops, no enemy-defeat bookkeeping, no capture-tracker init (the capture-tracker
guard at battle setup now also excludes `_ghost_duel`, alongside `puzzle_mode`/
`friendly_duel`/`_pvp`).

#### Known gap

The ghost-duel entry point is host-only for now: a client would need its own way
to read the session roster (there is no wire message today that hands a client
the member list + ratings the way `recv_party_bounties_snapshot` does for
bounties). Extending this to clients is a natural follow-up but out of scope here
— see BID list for the corresponding backlog entry.

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

#### Friends list (GID-102 / TID-375)

Players who met in a co-op session previously had no way to remember each other. A
**device-local, token-keyed friends list** fixes this, mirroring the recent-servers
pattern above exactly.

- **Storage — `MpProfile`** (`friends` in `mp_profile.json`): an `Array` of
  `{token, name, color_hex, last_seen}` dicts, deduped by `token`, most-recent-
  touched-first, capped at **50** entries (same push-front + `resize` cap pattern as
  `_recent_servers`). API:
  - `add_friend(token, name, color_hex)` — idempotent upsert: re-adding an existing
    token refreshes name/color/last_seen and moves it to the front rather than
    duplicating it. Inputs are sanitized the same way `PlayerIdentity.decode`
    defaults a malformed identity payload (blank name → `DEFAULT_NAME`, invalid hex →
    `"ffffff"`), so a corrupted/garbage packet can never poison the friends list.
    No-ops on a blank token.
  - `remove_friend(token)` — drop by token; no-op if absent.
  - `get_friends() -> Array` — defensive copy, most-recent-touched-first.
  - `is_friend(token) -> bool` — membership check.
  - `touch_friend_last_seen(token)` — refreshes `last_seen` for an **existing**
    friend only (does not upsert a non-friend); called whenever a friend's token is
    observed among connected session peers.
  - The **token is never displayed** in any UI — friends are always rendered as a
    color swatch + sanitized display name, per the GID-094 opaque-token rule.
- **Add from roster — `WorldScene._add_roster_row`** gains an optional `token`
  parameter (empty for the local "(you)" row, which never gets the affordance). Each
  remote roster row shows a small "+ " button that calls
  `MpProfile.add_friend(token, name, color_hex)`; once `MpProfile.is_friend(token)` is
  true the button is replaced by a disabled "✓ Friend" indicator instead of allowing a
  redundant add. `_refresh_coop_roster` also calls `touch_friend_last_seen(token)` for
  every peer currently in `_remote_identities`, so a friend's `last_seen` advances
  automatically just by being in the same session — independent of whether they were
  added via the roster this session or a previous one.
- **Online status is in-session presence only** — there is no global
  matchmaking/presence backend (explicitly out of scope). "Online" means "this
  friend's token is currently among the connected peers' identities in the session
  I'm in right now"; otherwise the UI shows the stored `last_seen` timestamp honestly.
- **Lobby — `MultiplayerLobbyScene`**: a "Friends" section (viewport-relative,
  rebuilt on resize, same pattern as the Rejoin/Find-Games rows) lists
  `MpProfile.get_friends()` as swatch + name + status. `_online_friend_tokens()`
  checks `NetworkManager.is_active()` and, if so, reads `WorldScene._remote_identities`
  via `get_node_or_null` + `get()` (the lobby has no direct WorldScene reference) to
  see if any saved friend's token is currently connected; this is realistically rare
  while still *in* the lobby overlay (pre-connection) and more useful if the panel
  is later revisited mid-session. **No invite mechanism** is provided (no presence
  backend to deliver one) and **no join-shortcut** was added from a friend entry —
  a friend's server, if known, already one-tap-rejoins via the existing
  recent-servers list, so the coupling was kept deliberately light per the task scope.

## Shared World-Object Sync (GID-096)

Enemies and chests in a co-op session are **authority-owned shared state**. They are
spawned **deterministically** from the same map `.tres` on every peer (so positions are
identical by construction); only **discrete lifecycle changes** are synced live, and the
resolved state persists into the GID-095 session file so the world resumes on reconnect.

> Scope note: co-op currently lands on **madrian**, a town map with no enemies/chests, so
> there is nothing to sync there *in practice* — the system is map-agnostic and exercised by
> `tests/net_world_sync_smoke.gd` with synthetic ids. Named-map enemies are **static**
> (`EnemyNPC` is a proximity trigger, no wander AI; roaming-boss / nocturnal wanderers are
> infinite-world only and out of co-op scope), which is why deterministic spawn + discrete
> sync is sufficient.

### Encounter rule — engage-locks (first-engager-takes)

The first player to reach a shared enemy fights it **solo vs the AI** (this is the normal
single-player battle, *not* PvP). The instant they engage, the enemy is **removed for
everyone** (the authority fans out an `enemy_removed` event). Outcomes:

- **Win** → the defeat is recorded into the session file's `defeated_enemies`; the enemy
  stays gone after reconnect.
- **Loss / flee** → the enemy is gone for the live session but **returns on reconnect** (a
  loss is never persisted) — exactly the single-player semantic.

This avoids two players desyncing over one enemy without needing shared battle state for
PvE; PvE battles remain local to the engaging player.

### Loot rule — first-opener-takes (default), opt-in need/greed (GID-102 / TID-381)

The player who opens a chest gets the loot (cards/coins/equipment drop **locally for the
opener only**, into their per-player GID-095 character). Every other peer just sees the
chest **flip to opened** — no loot. The open is recorded into the session file's
`opened_chests`, so a chest can never be looted twice and reopens as opened on reconnect.
This remains the default and is **completely unchanged** unless a host opts into the
alternative below.

**Need/greed roll mode.** `SessionState.loot_mode` (`LOOT_MODE_FIRST_OPENER` default /
`LOOT_MODE_NEED_GREED`, added in **v4** with a migration that backfills the default for
existing session files) is a host-only setting toggled via an in-world HUD button
(`WorldScene._ensure_loot_mode_toggle_button`/`_on_loot_mode_toggle_pressed`, next to the
session roster — placed in-world rather than the pre-connection lobby because
`SessionStore` only opens once `_setup_session()` runs). `SessionStore.get_loot_mode()` /
`set_loot_mode()` are the convenience accessors.

When the mode is on, the chest branch of `_handle_interact` (immediately after the
existing `_on_chest_opened_coop(cid)` call, which still flips the chest for everyone and
persists the open exactly as before) **skips the opener's local grant** and calls
`WorldScene._start_loot_roll(cid, chest_tier)` instead of `_spawn_card_items` /
`_spawn_coin_piles` / `_maybe_drop_equipment_from_chest`. The chest's card ids / position
are **never sent over the wire for the roll** — the authority re-derives them from its own
`_active_chest_data[cid]`, which is deterministic and identical across peers (the same
GID-096 invariant that makes discrete-event-only sync sufficient). A client opener instead
sends a small `submit_loot_roll_request(cid, chest_tier)` intent so the authority knows to
start a roll for that chest.

The authority builds the participant list from every connected session member (host +
`_session_token_by_peer.values()` — "present" is simplified to "connected to the session",
not a same-map/proximity filter, a documented v1 scope cut), opens a roll session keyed by
a generated `roll_id`, and broadcasts `recv_loot_roll_start`. Each peer shows a transient
Need/Greed/Pass panel (`WorldScene._show_loot_roll_panel`, viewport-relative, three tappable
buttons — mobile/desktop parity with no keyboard-only path) and sends its choice back via
`submit_loot_roll_choice`. The authority resolves early once every expected participant has
responded, or after a `_LOOT_ROLL_TIMEOUT = 15.0`s timeout (`_tick_loot_rolls`, ticked from
`_process`) with any missing response **auto-passed**. **Equipment drops are out of scope for
a roll** — there is no session-scoped equipment inventory to grant to an arbitrary winner
(see BID-033), so only cards + a flat coin reward are roll-eligible; the map-fragment branch
is also unaffected (still resolved before the roll check, same as always).

**The authority is the only one that ever rolls the RNG** — clients only submit
`need`/`greed`/`pass`, never a numeric value, so the outcome is tamper-proof. Need beats
greed beats pass; ties within the same tier are broken by the highest rolled value
(1–100). The winner's cards/coins are granted **directly into their GID-095 session
character record** via `SessionStore` (`WorldScene._grant_chest_loot_to_token`) — the same
direct-write pattern `_transfer_card_in_session` (card trading) and the party-bounty reward
path already use for a member who may not be the local player, rather than the physical
`WorldItem` pickup path GID-096 uses (which only ever grants to the local opener). The roll
is removed from the in-flight map **before** any grant happens, so an item can never be
granted twice. `recv_loot_roll_result` announces the winner (or "everyone passed") to all
peers as a `GameBus.hud_message_requested` toast, consistent with other recent features.

### Pure helpers

| Helper | Purpose |
|---|---|
| `game_logic/net/EnemySync.gd` | Enemy **position** stream: `encode_state(id,x,z,alive)`/`decode_state`, `encode_batch`/`decode_batch`, `interp` (mirrors AvatarSync). Inert while enemies are static; provided for future moving enemies. |
| `game_logic/net/WorldObjectSync.gd` | **Discrete** events: `encode_event(kind,id)`/`decode_event` (kinds `enemy_engaged`/`enemy_removed`/`enemy_defeated`/`chest_opened`) and `encode_snapshot(removed_enemies, opened_objects)`/`decode_snapshot` for late-join reconciliation. |
| `game_logic/net/LootRoll.gd` (GID-102 / TID-381) | Need/greed roll: `encode_start`/`decode_start` (roll prompt: roll_id, item, participant tokens), `encode_choice`/`decode_choice` (client's need/greed/pass intent), `encode_result`/`decode_result` (winner + rolled values), and the core `static func resolve_winner(choices: Dictionary, rng: RandomNumberGenerator) -> Dictionary` — need beats greed beats pass, ties broken by highest rolled value, `winner_token == ""` when all pass. The RNG is always injected so the authority (and tests) can seed it. |

### RPCs — `NetSync` (added)

| RPC | Direction / reliability | Purpose |
|---|---|---|
| `recv_world_event(payload)` | authority → clients, reliable | apply a discrete event (`enemy_removed` → drop node; `chest_opened` → flip node) |
| `submit_world_event(payload)` | client → authority, reliable | intent: I engaged / defeated an enemy, or opened a chest |
| `recv_world_snapshot(payload)` | authority → joining client, reliable | reconcile freshly-spawned nodes to the live + persisted removed/opened sets |
| `recv_enemy_positions(payload)` | authority → clients, unreliable_ordered | low-Hz (5 Hz) moving-enemy position batch; clients `EnemySync.interp` toward it |
| `recv_loot_roll_start(payload)` (GID-102 / TID-381) | authority → all, reliable | show the Need/Greed/Pass prompt for a chest's resolved drop |
| `submit_loot_roll_request(cid, tier)` (GID-102 / TID-381) | client → authority, reliable | "I opened this chest and need/greed mode is on — start a roll" |
| `submit_loot_roll_choice(roll_id, choice)` (GID-102 / TID-381) | client → authority, reliable | my need/greed/pass choice for an active roll |
| `recv_loot_roll_result(payload)` (GID-102 / TID-381) | authority → all, reliable | announce the winner + rolled values; grant already happened authority-side before this broadcasts |

### Authority flow (WorldScene, all guarded by `_coop_active`)

- **Engage:** `_on_enemy_engaged_coop(edata)` (connected to `GameBus.enemy_engaged`) — the
  host broadcasts `enemy_removed`; a client `submit`s `enemy_engaged`, and the host then
  removes its own node and fans `enemy_removed` to every *other* peer. The engaging peer
  already freed its node in `EnemyNPC.engage()`.
- **Defeat:** `_on_battle_won` → `_coop_persist_enemy_defeat()` — the host records the
  defeat into the session state; a client `submit`s `enemy_defeated` for the host to record.
  The id is captured at engage time (`_coop_last_engaged_enemy_id`) because
  `SceneManager._on_battle_won` clears its own copy first.
- **Chest open:** the chest branch of `_handle_interact` calls `_on_chest_opened_coop(cid)`
  — host persists + broadcasts `chest_opened`; a client `submit`s it (host persists +
  re-broadcasts). Peers only `mark_opened()` the node (no loot).
- **Resume / late-join:** `_coop_apply_world_progress(defeated, opened)` removes already-
  resolved nodes. The host applies it from the session state in `_setup_session`; a joining
  client applies the `recv_world_snapshot` the host sends right after the identity handshake.
- **Position stream:** `_broadcast_enemy_positions` (host, 5 Hz) + `_interp_synced_enemies`
  (clients) — a genuine path, inert while all enemies are static (target == spawn position).
- **Persistence target:** the GID-095 `SessionState.defeated_enemies` / `opened_chests`
  via `SessionStore` — **never** `save.json`. Single-player (no session) hits none of this:
  `SaveManager.is_enemy_defeated` / `is_chest_opened` + local loot are entirely unchanged.

## Integrations with Other Features

| System | Integration |
|---|---|
| SceneManager | `enter_map_coop()` reuses `enter_map`; co-op lives entirely in `State.WORLD` |
| World objects | Enemy engage/defeat + chest open branch on `_coop_active` to sync + persist into the session file; single-player path unchanged (GID-096) |
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
| `tests/unit/test_coop_sync.gd` | unit (auto-run) | AvatarSync encode/decode round-trip (incl. the TID-352 `map` field + legacy 4-element tolerance) + interpolation + N-peer `spawn_offset` fan-out (21 cases) |
| `tests/unit/test_player_identity.gd` | unit (auto-run) | PlayerIdentity encode/decode round-trip, color hex, robust defaults for short/blank/invalid payloads (10 cases) |
| `tests/unit/test_coop_discovery.gd` | unit (auto-run) | Discovery wire-format round-trip, IP-from-socket, invalid/wrong-tag rejection (7 cases) |
| `tests/unit/test_pvp_protocol.gd` | unit (auto-run) | BattleNetProtocol intent + state-mirror encode/decode (17 cases) |
| `tests/unit/test_session_state.gd` | unit (auto-run) | SessionState round-trip, member lookup/create by token, resume-without-reset, starter seeding (token-salted UIDs), migration scaffold + garbage tolerance; pvp stats fields + round-trip + migration v3 backfill; pvp_rating/pvp_games fields + round-trip + v4 backfill + derived `get_leaderboard` ordering/limit/record; party_bounties default/round-trip/garbage tolerance; shared `stash` default/round-trip/garbage tolerance + migration v5 backfill; `leaderboards` {spire, coop_clears} default + `record_pve_score` insert/own-better-overwrites/worse-and-equal-are-no-ops/sort-desc/cap-at-20/unknown-board-and-blank-token no-ops, `get_pve_leaderboard` limit, round-trip + snapshot shape, migration v6 backfill + preserves-existing + garbage-field tolerance; ghost-duel snapshot shape + UID→template_id resolution + rating passthrough + blank/unknown-token/non-Dictionary-member/dangling-UID tolerance (60 cases) (GID-095 / GID-101 / GID-102) |
| `tests/unit/test_rating_math.gd` | unit (auto-run) | RatingMath ELO: expected-score symmetry/bounds/favouring, win-raises/loss-lowers, symmetric zero-sum deltas at equal rating, placement vs settled K, floor clamp, draw no-op (15 cases) (GID-102 / TID-370) |
| `tests/unit/test_social_sync.gd` | unit (auto-run) | SocialSync emote round-trip for all 6 preset ids, map field, garbage/empty array tolerance; ping round-trip preserving coords/kind/color/map, partial array defaults, negative coords, constants sanity (16 cases) (GID-101 / TID-365) |
| `tests/unit/test_chat_sync.gd` | unit (auto-run) | ChatSync quick-chat round-trip for all preset ids + unknown-preset fallback, free-text round-trip + 120-char length cap (under/at/over + forged-payload re-sanitization), control-character (incl. DEL) and newline/tab stripping, map field round-trip, garbage/null/empty/short-array/invalid-kind decode tolerance, constants sanity (26 cases) (GID-102 / TID-374) |
| `tests/unit/test_stash_transfer.gd` | unit (auto-run) | StashTransfer deposit/withdraw card round-trip + uid re-keying, unique-card block, missing-card/blank-uid no-ops, coin deposit/withdraw incl. insufficient-funds/non-positive-amount guards, deposit-then-withdraw and coin round-trips are neutral, garbage-stash-shape tolerance (16 cases) (GID-102 / TID-376) |
| `tests/unit/test_world_sync.gd` | unit (auto-run) | EnemySync state/batch round-trip + interp; WorldObjectSync event + snapshot encode/decode, distinct kinds, garbage tolerance, id-string coercion (18 cases) (GID-096) |
| `tests/unit/test_mp_profile_friends.gd` | unit (auto-run) | MpProfile friends list: add/dedupe-by-token/move-to-front, blank-token no-op, name/color sanitization, remove (existing + missing), `is_friend` true/false/blank, 50-entry cap eviction (keeps newest, drops oldest), `touch_friend_last_seen` (updates existing, no-op for non-friend), `get_friends` defensive copy, JSON persistence shape round-trip via a temp `user://` file (17 cases) (GID-102 / TID-375) |
| `tests/unit/test_loot_roll.gd` | unit (auto-run) | LootRoll need-beats-greed (multi-seed), tie-break by highest rolled value within a tier, deterministic-with-seeded-RNG repeatability, all-pass/empty-choices has no winner, unrecognized choice normalizes to pass, timeout-as-pass equivalence, encode/decode round-trip + garbage/null/non-container tolerance for start/choice/result (24 cases) (GID-102 / TID-381) |
| `tests/net_coop_smoke.gd` | on-demand SceneTree | Real ENet loopback connect + NetSync RPC + AvatarSync decode end to end |
| `tests/net_coop_npeer_smoke.gd` | on-demand SceneTree | 3-peer (host + 2 clients) loopback: host avatar reaches both clients, and a **client→client** identity packet is relayed by the host (proves the server-relay path N-peer rendering depends on) + PlayerIdentity decode (GID-094) |
| `tests/net_discovery_smoke.gd` | on-demand SceneTree | Real loopback UDP discovery request/reply |
| `tests/net_pvp_smoke.gd` | on-demand SceneTree | Real ENet loopback: client intent → host apply → state-mirror round-trip |
| `tests/net_pvp_client_smoke.gd` | on-demand SceneTree | Real ENet loopback with **two real `BattleScene` peers**: client (idx 1) launches + applies the host's first mirror without crashing (GID-092 / TID-336) |
| `tests/net_pvp_reconnect_smoke.gd` | on-demand SceneTree | Real ENet loopback: duel starts and syncs, client peer disconnects (host starts a grace window, does **not** forfeit), a new connection reconnects and announces via `announce_reconnect`, host resumes (grace cancelled, re-mirrors) and the reconnecting client syncs (GID-102 / TID-372) |
| `tests/net_rehost_smoke.gd` | on-demand SceneTree | host→leave→host repeated, and re-host without an explicit leave, all return OK (port freed) (GID-092 / TID-337) |
| `tests/net_session_smoke.gd` | on-demand SceneTree | Real ENet loopback + live `SessionStore`/`SaveManager` autoloads: client identifies (token A) → host sends a seeded 12-card starter via `recv_character`; after persisted progress + close, re-opening the session resumes the **same** character (coins) + world progress from disk; `save_slot_*.json` proven untouched (GID-095 / TID-348) |
| `tests/net_world_sync_smoke.gd` | on-demand SceneTree | Real ENet loopback + live `SessionStore`: authority `enemy_removed`/`chest_opened` events + a late-join snapshot + an enemy position batch all reach the client via real NetSync RPCs and decode; a defeated enemy + opened chest persist into the session file and resume on reopen; `save_slot_*.json` untouched (GID-096) |
| `tests/net_leaderboard_smoke.gd` | on-demand SceneTree | Real ENet loopback: authority `recv_leaderboard` broadcast reaches the client with the exact `SessionState.get_leaderboard()` row shape and rating-desc ordering; client `submit_leaderboard_request` reaches the authority (GID-102 / TID-373) |

Run the smoke tests with `godot --headless --path . -s tests/<file>` (exit 0 =
pass). They are not in the auto-discovered unit suite because they need real
sockets + frame polling.

**Manual two-instance check (visual, recommended before release):** launch two
instances; A → Co-op → Host (lands in madrian); B → Co-op → Find Games or IP
`127.0.0.1` → Join. Move each player and confirm the other sees it walk smoothly;
close one and confirm its avatar is freed.

## Dedicated Server (GID-097 / TID-352)

A **headless, non-player server** is an additional hosting option that owns the
session + world authority without rendering, a local player, a camera, or a HUD.

### Launch

```bash
# From the project root, or from a deployed export
godot --headless -- --server [--port N] [--map NAME]
```

`--port` defaults to `24565`. `--map` defaults to `"madrian"`.
Connect clients with the normal "Join by IP" path in the lobby.

### How it works

1. **`SceneManager._maybe_boot_dedicated_server()`** (called at the end of `_ready()`):
   parses `OS.get_cmdline_user_args()` for `--server`, `--port N`, `--map NAME`;
   sets `NetworkManager._server_mode = true`, calls `NetworkManager.host(port, 4)`
   (4 client slots — the server is not a player), then `enter_map_coop.call_deferred(map_name)`.
   If the port bind fails, logs the error and quits with exit code 1.

2. **`NetworkManager.is_dedicated_server()`** — returns `true` only when this
   process was launched with `--server`. All server-only branches in WorldScene and
   elsewhere are gated on this.

3. **`WorldScene._ready()`** skips `_spawn_player()`, virtual joystick, HUD labels,
   WorldHUD, Minimap, DungeonSessionUI, and pending-battle re-enter when
   `is_dedicated_server()` is true. A `_server_ref_pos` computed from the map's SPAWN
   marker (or `Vector3.ZERO`) is used in place of `_player.position` for the initial
   chunk streaming calls.

4. **`WorldScene._process()`** runs co-op ticks (`_coop_active`) and the DayNightCycle
   tick *before* the `if _player == null: return` guard, so time, persistence, and
   enemy streaming work even without a local player.

5. All `_world_hud` accesses in WorldScene are safe: the HUD is never created in server
   mode and the code paths that access it are all reachable only via the player-guard
   (player-triggered interactions, `_check_interactions()`, etc.).

### Lifecycle

- Connects and disconnects are logged: `[Server] Client connected:` / `[Server] Client disconnected:`.
- The server keeps running when the last client leaves (no auto-quit).
- Session state (`SessionStore`) flushes on a peer-disconnect and on the normal quit/SIGINT path.
- All GID-095 per-player persistence and GID-096 world-object sync work unchanged
  — both were built against the authority abstraction, not the listen-server path.

### Additive guarantee

Every server-mode branch is gated on `NetworkManager.is_dedicated_server()` or
`_player == null`. The listen-server path (`MenuScene → Host Game`) is untouched.

### PvP on a Dedicated Server (GID-097 / TID-353)

On a dedicated server **neither client is the host**, so the server acts as the
headless referee. Both clients send intents; the server owns `GameState` and
broadcasts mirrors to both.

**Challenge handshake (3 messages):**

1. **Challenger → server:** `NetSync.relay_pvp_request(target_peer_id, my_deck)`.
   Clients use this path when `_session_dedicated == true` (set by
   `set_session_flags` alongside the character record on connect).

2. **Target → server:** `NetSync.relay_pvp_response(challenger_id, accepted, my_deck)`.
   The server also forwards the challenge to the target via the existing
   `request_battle` RPC so the target's `_pending_challenge_from` / UI still works.

3. **Server → each client:** `NetSync.notify_pvp_start(my_player_idx, opponent_deck)`.
   Challenger gets `(0, target_deck)`; target gets `(1, challenger_deck)`.
   Each client calls `SceneManager.enter_pvp_battle(my_player_idx, opponent_deck)`.

**Server referee scene** (`SceneManager.enter_pvp_referee`)

- Instantiates `BattleScene` with `_local_player_idx = -1` and
  `_pvp_peer_to_idx = {peer_a_id: 0, peer_b_id: 1}`.
- `_is_pvp_host()` returns `true` (the server is the ENet host).
- All rendering paths guard on `_local_player_idx < 0` — no UI, no board view.
- Intent routing: `_on_pvp_intent(sender, payload)` looks up `sender` in
  `_pvp_peer_to_idx` to get `acting_idx` (0 or 1); `_apply_remote_intent(intent,
  acting_idx)` is fully generalised with `opp_idx = 1 - acting_idx`.
- On game-over: broadcasts `pvp_ended`, then `_finish_pvp` emits
  `GameBus.pvp_battle_ended` directly (no result UI), returning to the world.

**Listen-server path unchanged:** `_is_pvp_host()` still returns `true` for the
listen-server host (peer_id=1, local_idx=0); `_pvp_peer_to_idx` is empty so
`_on_pvp_intent` falls through to the hardcoded `acting_idx = 1` path.

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
  Rejoin list. **Reconnection into an in-progress 1v1 PvP duel** is now supported
  (GID-102 / TID-372 — see the PvP section below); a dropped **host or referee**, or a
  dropped **team duel** (TID-371) participant, still ends the battle immediately
  (out of scope for this slice).
- **PvP is LAN/loopback only**, 2 players for 1v1 duels (Spectating/TID-367 and wagered
  duels/TID-368 are supported there) or 4 for **2v2 team duels** (GID-102 / TID-371 —
  no wagers, no accept/decline, fixed 2v2). A **persistent ELO rating + a derived
  leaderboard** now exist (GID-102 / TID-370), extended to team duels via a
  team-average-expected-score update, with a **ranked toggle, leaderboard panel, and
  roster rating badges** surfacing them (GID-102 / TID-373); what is still missing is
  global *matchmaking* (no queue across the internet) and a true cross-session ladder
  (the leaderboard is per-session, scoped to one host's `SessionStore` file).
- **Live-synced (GID-096):** shared **enemies** (engage-locks; defeat persists) and
  **chests** (first-opener-takes; open persists) now sync from the authority and resume on
  reconnect. Still **not** synced: NPC dialogue/story, day/night, weather, and the
  per-player inventory (that is the GID-095 character, by design). The co-op landing map
  (madrian) still has no enemies/chests of its own (BID-024, not fully resolved), but
  **procedural dungeons are now reachable together** via the "Dungeon Crawl" host button
  (GID-102 / TID-380, see Co-op Story Mode below) — every dungeon has combat/chest rooms, so
  the sync is exercised for real content, not just `net_world_sync_smoke.gd`'s synthetic ids.
- **Infinite chunk world not supported** — co-op uses a finite named map (or a finite
  generated dungeon, GID-102 / TID-380) to avoid chunk synchronisation.

---

## Co-op Story Mode (GID-098)

Extends co-op so the party can travel through and experience the story together across all named maps and dungeons.

### Multi-map transitions (TID-355)

**Model: Followed transition.** When any co-op player interacts with a door, all peers follow to the same map.

**Flow:**
1. The initiating peer broadcasts `NetSync.recv_map_transition(target_map, door_id)` before calling the local SceneManager entry point.
2. Receivers fire `WorldScene._on_map_transition_received(target_map, door_id)`:
   - Empty `target_map` → `SceneManager.exit_map()`.
   - Non-empty → `SceneManager.enter_map(target_map, door_id)`.
3. `_coop_map_transitioning: bool` flag on each WorldScene instance guards against double-transitions on the same scene instance.
4. **Late-joiner redirect:** in `_on_identity_received`, after the host sends the character + world snapshot, it checks `SessionStore.current_map != map_name` and unicasts `recv_map_transition` to the joining peer so they land where the party already is.

**RPC:** `recv_map_transition(target_map: String, door_id: String)` — reliable, any_peer → call_remote.

### Shared dungeon crawl (GID-102 / TID-380)

Co-op previously had **no way to reach a procedural `DungeonGen` dungeon at all** — every
`"dungeon_<seed>"` map name in the game was constructed by `InfiniteWorldGen.gd` for ruin
doors in the infinite chunk world, which co-op explicitly does not support (see
Limitations), and zero dungeon doors are authored in any of the 6 named `.tres` maps. This
was an entry-point gap, not a sync gap: `WorldScene._ready()` already loads any map whose
name starts with `"dungeon_"` by parsing the seed out of the string
(`int(map_name.substr(8))`) and calling `DungeonGen.generate(map_name, dseed)` — it doesn't
care how the string was built — and `docs/agent/named-maps-and-dungeons.md` confirms
`DungeonGen.generate` is a pure function of `(name, seed)`.

**Trigger — host-only HUD button, not a new map door.** A "Dungeon Crawl" button
(`WorldScene._ensure_dungeon_button` / `_start_dungeon_crawl`) is created in `_setup_coop()`
alongside the existing challenge/social buttons, visible only when `NetworkManager.is_host()`
(the host is the authority that picks the shared seed, avoiding a race where two peers open
two different dungeons at once). A HUD button — rather than an authored door/portal entity in
`madrian.tres` — was chosen because it needs no map-authoring pass (tile placement, terrain
carving, a new `MapDoor` resource), generalizes to any future co-op-supported named map for
free (it's gated on `_coop_active`, not a specific map name), and satisfies mobile/desktop
parity trivially (a HUD button has no separate touch/keyboard path to duplicate).

**Seed derivation:** when a session is open, `hash(str(world_seed) + "_dungeon_" +
str(days_elapsed))` (from `SessionStore.get_state()`) — reopening the button on the same
in-game day reproduces the same dungeon; a new day yields a fresh one. Falls back to
`randi()` if `SessionStore` isn't open (defensive; doesn't happen while `_coop_active`).

**Broadcast — no new RPC.** `_start_dungeon_crawl()` builds `target_map = "dungeon_%d" %
seed` and reuses the **existing** TID-355 mechanism verbatim: `_net_sync.rpc("recv_map_transition",
target_map, "")` then the local `SceneManager.enter_map(target_map, "")`, exactly like the
door-triggered branch in `_handle_interact()`. Every peer's `_on_map_transition_received`
independently calls `DungeonGen.generate(target_map, seed)` (or reloads its own cached
`.tres` on a repeat visit), producing byte-identical tile grids and entity ids — confirmed by
`DungeonGen`'s ids being purely index-based counters (`"de_%d"`, `"dnpc_rest_%d"`, `"dtr_%d"`,
fixed `"dc_0"`/`"dsr_0"`/`"exit"`), never randomized or position-derived. This means GID-096's
engage-lock / first-opener-takes sync (which keys purely on those string ids via
`WorldObjectSync`) works in a dungeon exactly as it does on any named map — no map-name
special-casing exists anywhere in the sync path.

**Exit:** the dungeon's generated exit door has `target_map = ""`, so it already routes
through the same `_handle_interact()` branch that broadcasts `recv_map_transition("", "")` for
any empty-target door — no dungeon-specific exit handling was needed.

**Progress is transient by design** — no dungeon-clear state is written to `SessionState`;
the shared seed only needs to live for the duration of the crawl (matches single-player,
where dungeons are also not tracked as "cleared").

**Scope cut:** no new loopback smoke test was added for this transition specifically, since
`recv_map_transition` itself is untouched, already-exercised code, and the property that
actually needs proving — "two independent `DungeonGen.generate()` calls with the same seed
produce identical content" — is a pure-logic property with no networking dependency. It is
covered by a unit test (`tests/unit/test_dungeon_secrets.gd` →
`test_dungeon_determinism_full_grid_and_entity_ids`) that asserts full tile-grid equality plus
per-entity id/type/position equality across two independent generations, rather than the
prior test's single center-tile + chest-count sample.

**Still not multi-map co-op for the infinite world** — the trigger only ever produces a
`"dungeon_<seed>"` name, never touches chunk streaming.

### Shared story flags (TID-356)

Story flags are authority-owned and stored in `SessionState.story_flags`. Every peer's local `SaveManager.story_flags` is kept as a mirror. Changes flow through the authority to prevent races and duplicate story beats.

**Write path (any peer):**
- `GameBus.story_flag_set` fires when `SaveManager.set_story_flag()` is called.
- `WorldScene._on_local_story_flag_set(key)` intercepts it (guarded by `_coop_story_flag_syncing` to prevent loops).
  - **Host:** writes to `SessionState`, marks dirty, broadcasts `recv_story_flag` to all peers.
  - **Client:** submits `submit_story_flag(key, value)` to authority (peer_id=1).

**Authority arbitration (`_on_story_flag_submitted`):**
- Idempotency check: if `SessionState.story_flags[key]` already equals the submitted value, the broadcast is skipped.
- Otherwise: updates `SessionState`, marks dirty, broadcasts `recv_story_flag` to all (including the submitter).

**Receive path (`_on_story_flag_received`):**
- Sets `save_manager.story_flags[key] = value`.
- Emits `GameBus.story_flag_set` (guarded by `_coop_story_flag_syncing` so it doesn't re-enter).
- Updates `SessionState` if open.

**Late-joiner snapshot:**
- Host sends `recv_story_flags_snapshot(flags: Dictionary)` to the joining peer after character + world snapshot.
- Receiver applies all flags at once (guarded by `_coop_story_flag_syncing`).

**Host resume:**
- `_setup_session` now restores `SessionState.story_flags` into `save_manager.story_flags` so a host re-entering a saved session starts with the correct story state.

**RPCs (all reliable):**
- `recv_story_flag(key: String, value: bool)` — authority → all.
- `submit_story_flag(key: String, value: bool)` — client → authority.
- `recv_story_flags_snapshot(flags: Dictionary)` — authority → joining peer.

### Group-aware NPC dialogue (TID-357)

NPCs can show different text when addressed as a group.

**Field:** `MapNpc.dialogue_group: String` (optional `@export`). Leave blank to always use `dialogue`.

**Selection logic** (`TownspersonNPC.get_dialogue()`):
1. If `_flag_key` is set and the flag is raised → return `_after_dialogue` (story-flag gate, unchanged).
2. Else if `_dialogue_group != ""` and `NetworkManager.is_active()` and `multiplayer.get_peers().size() > 0` → return `_dialogue_group`.
3. Else → return `npc_data["dialogue"]` (solo/single-player).

**Data pipeline:**
- `WorldMap.load_from_resource()` reads `dialogue_group` from the MapNpc resource and includes it in the NPC dict.
- `WorldMap.to_map_data()` writes it back to MapNpc on save.
- Author group variants in the `.tres` NPC directives under `assets/maps/`.

**TID-358 (human-action):** The human-owned story bible (`docs/human/story.md`) is updated separately to pluralize authored lines where a group variant exists.
- **Steam transport** is stubbed (`Transport.STEAM` returns null with a warning).

---

## Co-op Joint Battle Engine (GID-099)

Extends the battle engine so a **party of N allies (2–4) fight one shared boss** together.
Each ally keeps their own board, hand, and mana; the boss scales its HP and deck tier by
party size; and the boss drops a **soulbound card to every ally** on a party win.

### Model — `game_logic/battle/GameState.gd`

`GameState` is extended with a `coop_battle: bool = false` flag. All co-op logic is gated
behind it — the 2-player PvP / NPC-duel / puzzle / Spire paths are entirely unchanged.

**State shape:** `players[0..N-2]` = allies; `players[N-1]` = boss. The boss is always
`is_ai = true`; allies are `is_ai = false`.

**Key new API:**

| Member | Purpose |
|---|---|
| `coop_battle: bool` | Enables the N-player co-op code paths in `opponent()`, `end_turn()`, `is_game_over()`, `winner()` |
| `setup_coop_battle(n_allies, ally_setup, boss_setup)` | Builds N ally PlayerStates + 1 boss PlayerState. Clamps allies to 2..4. `ally_setup(i, ally)` / `boss_setup(boss)` are callables that populate decks and opening hands |
| `allies() -> Array[PlayerState]` | `players[0..N-2]` when co-op; `[players[0]]` for legacy 2-player |
| `boss() -> PlayerState` | Always `players[players.size()-1]` |
| `is_ally(idx) -> bool` | `coop_battle and idx < players.size()-1` |

**Turn rotation:** `(current_player_idx + 1) % players.size()` — mathematically identical to
`1 - idx` for 2 players, naturally extends to N. The boss turn follows all allies; after the
boss, play wraps back to ally 0.

**`opponent()` targeting:**
- Ally turn → always returns the boss (`players[N-1]`).
- Boss turn → returns the **alive ally with the lowest hero HP** (`_get_lowest_hp_ally()`);
  BasicAI is reused unchanged because it calls `state.opponent()` to find its target.

**Win/loss conditions:**
- Boss dead → party wins; `winner()` returns `0` (ally side).
- All allies dead → boss wins; `winner()` returns `players.size()-1` (boss's `player_id`).

**`to_dict`/`from_dict`:** includes `coop_battle` flag and a dynamically-grown
`player_turn_numbers` array (size = `players.size()`). `from_dict` handles 3 cases: new
N-entry saves, legacy 2-entry saves, and missing-key fallback from `turn_number`.

### Scaling — `game_logic/battle/CoopBattleScaling.gd`

Pure static helper. No scene dependencies.

```gdscript
# Boss HP: base_hp × (0.6·n + 0.4)   (n clamped to MIN_PARTY=1, MAX_PARTY=4)
scale_boss_hp(base_hp: int, n: int) -> int

# Boss deck tier: bonus = (n-1)/2  (0 for n=1,2; 1 for n=3,4), capped at 4
scale_boss_tier(base_tier: int, n: int) -> int
```

Party-size effect on a 30-HP boss: n=1→30 HP, n=2→48 HP, n=3→66 HP, n=4→84 HP.

### Networking — `BattleNetProtocol` + `BattleNetSync`

**`BattleNetProtocol.gd`:** `encode_attack` gains an optional `target_pidx: int = -1`
parameter carried through the wire dict and decoded back. `target_pidx >= 0` selects a
specific ally's board/hero as the attack target in N-player co-op; `-1` = default opponent
(boss or only opponent).

**`BattleNetSync.gd`:** four new reliable RPCs for the co-op PvE path, kept separate from
the PvP RPCs to avoid cross-mode confusion:

| RPC | Direction | Purpose |
|---|---|---|
| `send_coop_intent(payload)` | ally client → host | one ally action |
| `sync_coop_state(payload)` | host → all ally clients | full GameState mirror |
| `coop_battle_ended(payload)` | host → all ally clients | end-of-battle with reward dict |
| `request_coop_sync()` | ally client → host | startup race: "send me the current state" |

**`_send_intent` routing:** `BattleScene._send_intent` now calls `send_coop_intent` when
`_coop_pve`, `send_intent` otherwise.

### BattleScene co-op PvE hooks

All co-op code is gated behind `_coop_pve: bool`. No existing code paths are changed.

| Member | Purpose |
|---|---|
| `_coop_pve: bool` | Mode flag, set by `SceneManager.enter_coop_pve_battle` |
| `_coop_ally_decks: Array` | Per-ally deck data passed from SceneManager |
| `_coop_peer_to_idx: Dictionary` | Maps peer_id → ally_idx (authority-side only) |
| `_coop_ended: bool` | Guard against double end-of-battle |

**Setup:** `_setup_coop_pve_battle()` → creates `BattleNetSync`, wires disconnect signals
(reusing PvP handlers). Authority also calls `_build_coop_pve_state()`, which invokes
`GameState.setup_coop_battle` with `CoopBattleScaling`-derived boss HP and tier.

**Intent flow (authority):** `_on_coop_intent(sender, payload)` maps the sender peer to
their `ally_idx` via `_coop_peer_to_idx`, validates it's that ally's turn, then delegates to
`_apply_remote_intent` (shared with PvP). Surrender zeroes that ally's HP.

**End of battle (authority):** `_coop_pve_check_game_over()` detects `is_game_over()`,
computes `_build_coop_reward_payload` once (card, rarity, stats, coins, xp from
`EnemyRegistry`), broadcasts via `coop_battle_ended` RPC, then calls `_finish_coop_pve`
locally.

**Rewards (each peer):** `_finish_coop_pve` calls `_apply_coop_pve_rewards` which adds
coins (`SaveManager.add_coins`), XP (`SaveManager.add_xp`), and the soulbound card
(`SaveManager.add_card_instance`). Each ally gets their own instance with their own UID.
Minimal result: a HUD message ("Party victorious!" / "The party was defeated."), 2 s pause,
then `GameBus.coop_pve_battle_ended.emit(did_win)`.

**Client sync startup:** `_process_coop_sync` retries `request_coop_sync` at 0.4 s
intervals until the first mirror arrives (same pattern as `_process` for PvP).

### SceneManager integration

- `enter_coop_pve_battle(local_ally_idx, all_ally_decks, enemy_data)`: sets `_coop_pve =
  true`, `_local_player_idx = local_ally_idx`, `_coop_ally_decks = all_ally_decks`, then
  transitions to BattleScene.
- `_on_coop_pve_battle_ended(_did_win)`: restores the shared co-op world (mirrors the
  `_on_pvp_battle_ended` handler).
- `GameBus.coop_pve_battle_ended(did_win: bool)` signal added alongside
  `pvp_battle_ended`.

### Tests

| File | Type | Covers |
|---|---|---|
| `tests/unit/test_coop_battle_state.gd` | unit (auto-run) | N-player setup (2–4 allies + boss), turn rotation including boss turn and wrap-around, opponent targeting, win/loss conditions, `to_dict`/`from_dict` round-trip for N participants, `CoopBattleScaling` HP/tier for n=1..4 (42 cases) |
| `tests/unit/test_team_battle_state.gd` | unit (auto-run) | 2v2 team battle: interleaved setup + team assignment, turn rotation alternates teams across all 4 slots and wraps, `opponent()` picks the lowest-HP alive enemy-team member (preferring alive over dead), team-aware `is_game_over()`/`winner()`, `to_dict`/`from_dict` round-trip incl. legacy-dict default tolerance (17 cases) (GID-102 / TID-371) |

## Co-op Battle Design (GID-100)

### Square battlefield ally bar

`BattleScene` adds a compact ally-status bar above the main battlefield when `_coop_pve`
is true. The bar is an `HBoxContainer` anchored to `PRESET_TOP_WIDE`, populated with one
`Button` per ally player (boss excluded). Each button shows `P{n}  HP:{h}/{max}  Mana:{m}`
and is refreshed on every `_refresh_all()` call via `_refresh_coop_ally_panels()`.

The bar is built lazily on the first `_refresh_all()` after `_state` is ready, using
`_coop_arena_built: bool` as the guard (no build before `_state` exists). The existing
`$EnemyArea/$PlayerArea` two-zone layout is untouched for solo/PvP/NPC battles.

### Cross-board card targeting

Five new effect names — `ally_heal_hero`, `ally_grant_ward_board`, `ally_buff_minion_all`,
`ally_grant_mana`, `ally_revive` — are listed in
`SpellEffectResolver.ALLY_TARGETED_EFFECTS`. When a card with one of these effects is
dragged to the board in co-op PvE mode, `BattleScene._board_drop()` calls
`_enter_ally_targeting_mode(card)` instead of the normal targeting path.

In ally-targeting mode the ally bar buttons become tappable targets: tapping `P{n}`
calls `_resolve_ally_spell(spell, pidx)`, which encodes `{"pidx": n}` into the wire
target dict via `BattleNetProtocol.encode_play_spell(hi, {"pidx": n})`. The host
decodes this through `_pvp_resolver_target()` (extended to handle the `"pidx"` key) and
passes `{"pidx": n}` as `explicit_target` to `_resolver.resolve_spell()`.

`SpellEffectResolver.resolve_spell()` match arms for the 5 new effects read
`explicit_target.get("pidx", caster_pid)` — falling back to self when the target is
absent (solo / 2-player context).

### Co-op support cards (5 new)

| ID | Name | Cost | Effect |
|---|---|---|---|
| `coop_aegis` | Aegis Pact | 2 | Grant Ward to all minions on an ally's board |
| `coop_mend` | Mending Light | 2 | Restore 5 HP to an ally's hero |
| `coop_rally` | Rally Cry | 3 | Give all minions on an ally's board +1 ATK and +1 HP |
| `coop_mana_tithe` | Mana Tithe | 1 | Give an ally +1 mana this turn |
| `coop_second_wind` | Second Wind | 3 | Revive the last minion that died on an ally's board |

All five are `magic_type = "light"` spells with `.tres` + `.uid` sidecars in `data/cards/`
and are registered in `CardRegistry` via `const _C_COOP_*` preloads. The card-count
assertion in `tests/unit/test_card_registry.gd` was updated from 100 → 105.
