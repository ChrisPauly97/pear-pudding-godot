# TID-342: Player identity — display name + color + stable token

**Goal:** GID-094
**Type:** agent
**Status:** done
**Depends On:** TID-341

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Remote players are anonymous blue avatars today. This task gives each player a
**display name** and **color** (set in the lobby, shown above avatars and in a
session roster) and a **stable identity token** generated once and persisted
locally. The token is the key GID-095 uses to match a reconnecting player to their
saved per-session character (deck/inventory/level/skills), so its shape is decided
here even though persistence lands later.

## Research Notes

**Three distinct concepts — keep them separate:**
- **Identity token** — a stable opaque id (e.g. a UUID string) generated once per
  device/profile and stored locally; *never* shown; used purely as a persistence
  key. Generate with something stable (e.g. random 16-hex on first run, saved to
  `user://`).
- **Display name** — editable, shown to others. Default to something friendly;
  remember last choice.
- **Color** — editable avatar tint; default per-player or random; remember it.

**Where to store the local default:** name/color/token are *device* preferences,
not part of the single-player `save.json` character. Either a tiny separate file
(`user://mp_profile.json`) or `SaveManager`-managed config. Prefer a small
dedicated store so it is independent of game-save load state (co-op can launch
cold — see `ensure_coop_deck`). Do **not** fold the token into `save.json`.

**Transmission:** identity must reach peers on connect, before/with the first
avatar packet. Add an identity handshake to `NetSync` (scenes/world/NetSync.gd) or
NetworkManager: when a peer connects, each side `rpc`s its
`{token, name, color}` to the others (reliable RPC — must not drop). Store a
`peer_id → {token,name,color}` map on the receiving side. Lazy-handle ordering the
same way avatars do (a packet may arrive before the connect signal).

**Pure encode/decode helper:** follow the `AvatarSync.gd` /
`BattleNetProtocol.gd` pattern — add a pure `game_logic/net/PlayerIdentity.gd`
(static `encode(token,name,color)->Array/Dict`, `decode(payload)->Dictionary`,
fully-defaulted, unit-testable). Color packs as a hex string or 3 floats.

**Rendering:** `scenes/world/entities/RemotePlayer.gd` currently hard-tints blue
(`_sprite.modulate = Color(0.7,0.85,1.0,1.0)` at line 38). Drive the tint from the
received color, and add a billboard name `Label3D` above the sprite (respect the
Sprite3D depth/clipping note in CLAUDE.md for Y offset). `RemotePlayer.init_from_data`
already takes a dict — extend it with `name`/`color`, or add a `set_identity()`.

**Lobby roster:** `scenes/ui/MultiplayerLobbyScene.gd` already lists discovered
hosts; add a name/color entry field (LineEdit + color swatch) and, once in a
session, a roster of connected players (name + color). Viewport-relative sizing per
CLAUDE.md.

**CLAUDE.md conventions:** `Label3D`/any new `.tres`/scene resources need `.uid`
sidecars; guard by `NetworkManager.is_active()`; explicit typing; `preload`.

## Plan

Complexity is moderate but the research notes are sufficient — proceeding to Build.

1. **`autoloads/MpProfile.gd`** (new autoload, registered in `project.godot`):
   device-local profile at `user://mp_profile.json`, independent of `save.json`.
   Holds `token` (opaque 16-hex, generated once, never shown), `display_name`
   (default "Player"), `color` (random palette pick on first run). Lazy-load +
   persist-on-set. API: `get_token`, `get_display_name`/`set_display_name`,
   `get_color`/`set_color`, `color_hex`.

2. **`game_logic/net/PlayerIdentity.gd`** (pure, unit-testable, mirrors
   AvatarSync): `encode(token, name, color) -> Array` (`[token, name, color_hex]`),
   `decode(payload) -> Dictionary` fully-defaulted + invalid-hex-safe.

3. **`scenes/world/NetSync.gd`**: add a reliable `recv_identity(payload, is_reply)`
   RPC routed to `WorldScene._on_identity_received`.

4. **`scenes/world/WorldScene.gd`**: `_remote_identities` map (peer_id→{token,name,
   color}). On `_setup_coop` broadcast local identity to all (reply=false); on
   receiving a non-reply, store + reply once directly to sender (reply=true) — this
   handshake is initiated by the just-loaded peer so the other side's NetSync
   always exists (no lost one-shot). Apply identity to the matching RemotePlayer
   (lazy: stored if avatar not spawned yet, applied in `_spawn_remote_player`).
   Erase on disconnect / clear on session end. Add a compact HUD **session roster**
   (colored bullet + name per connected player, incl. self), refreshed on
   identity/connect/disconnect.

5. **`scenes/world/entities/RemotePlayer.gd`**: `set_identity(name, color)` drives
   the sprite tint (replacing the hard-coded blue) and a billboard `Label3D` above
   the sprite (Y above sprite top, `no_depth_test`, outline).

6. **`scenes/ui/MultiplayerLobbyScene.gd`**: name `LineEdit` + color swatch row at
   the top, seeded from MpProfile, saved back on edit.

7. **Tests** (`tests/unit/test_player_identity.gd`): encode/decode round-trip,
   color hex preservation, invalid/short-payload defaults.

8. **Validate** headless import clean + `tests/runner.gd` exit 0; update docs.

## Changes Made

**New device profile autoload — `autoloads/MpProfile.gd`** (+ `.uid`, registered in
`project.godot`): stores `{token, name, color}` at `user://mp_profile.json`,
separate from the game save so it works for cold co-op. Generates a stable opaque
16-hex token + random palette color on first run; lazy-load + persist-on-set.

**New pure wire helper — `game_logic/net/PlayerIdentity.gd`** (+ `.uid`):
`encode(token,name,color)->[token,name,color_hex]` / `decode(payload)->{token,name,
color}`, fully defaulted and invalid-hex-safe (mirrors `AvatarSync`).

**Identity handshake — `scenes/world/NetSync.gd`:** added reliable
`recv_identity(payload, is_reply)` RPC routed to `WorldScene._on_identity_received`.

**`scenes/world/WorldScene.gd`:**
- `_remote_identities` map; `_send_local_identity(is_reply, target_peer)` (broadcast
  or unicast); `_on_identity_received` stores + applies + replies once to a
  non-reply broadcast (terminating handshake, initiated by the just-loaded peer so
  the other side's NetSync always exists).
- `_setup_coop` broadcasts local identity after spawning existing peers; identities
  arriving before an avatar spawns are applied lazily in `_spawn_remote_player`.
- Erase identity on peer disconnect / clear on session end.
- In-world **session roster** HUD panel (`_build_coop_roster` / `_refresh_coop_roster`
  / `_add_roster_row`): local player + each remote as colored swatch + name.

**`scenes/world/entities/RemotePlayer.gd`:** `set_player_identity(name, color)`
(renamed from `set_identity` — collides with native `Node3D.set_identity`) drives the
sprite tint (replacing the hard-coded blue) and a billboard `Label3D` name tag above
the head; neutral-blue default until identity arrives.

**`scenes/ui/MultiplayerLobbyScene.gd`:** name `LineEdit` (max 16) + preset color
swatch row, seeded from `MpProfile` and saved on edit / before host/join; resize
preserves the unsaved name; host advertises `"<name>'s game"` in LAN discovery.

**Tests — `tests/unit/test_player_identity.gd`** (+ `.uid`, 10 cases): encode/decode
round-trip, color-hex preservation, robust defaults (empty/short/blank/invalid).
Full suite 1572 pass / 0 fail, exit 0; headless import clean; `net_coop_smoke` PASS.

## Documentation Updates

`docs/agent/multiplayer-coop.md`: new "Player identity" section (MpProfile token/
name/color store, PlayerIdentity wire format, the reply-flagged handshake, session
roster, lobby fields); RemotePlayer description updated (identity-driven tint +
`Label3D`, `set_player_identity` naming); MpProfile added to the Integrations table;
tests table + Asset Requirements updated for the new files.
