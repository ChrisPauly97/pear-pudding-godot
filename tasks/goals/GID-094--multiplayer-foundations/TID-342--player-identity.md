# TID-342: Player identity — display name + color + stable token

**Goal:** GID-094
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
