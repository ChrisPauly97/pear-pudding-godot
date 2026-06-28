# TID-365: Emote wheel & map pings

**Goal:** GID-101
**Type:** agent
**Status:** done
**Depends On:** TID-355

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The cheapest, highest-fun social layer: quick emotes and tap-to-ping a location/enemy so
the party can coordinate without text chat. Built on the existing avatar-sync transport.

## Research Notes

- **Transport pattern:** mirror `AvatarSync` / the GID-096 discrete-event RPCs. Add a
  small reliable RPC on `NetSync` (`recv_emote(emote_id)` / `recv_ping(x, z, kind)`),
  fanned out by the authority (server-relay reaches all clients). Pure encode/decode
  helper in `game_logic/net/` (e.g. `SocialSync.gd`) — unit-tested like the others.
- **Map-scope:** only show emotes/pings to peers on the **same map** (reuse
  `_remote_player_maps` filter from TID-352).
- **Emote display:** a billboard `Label3D`/icon above the `RemotePlayer`
  (`scenes/world/entities/RemotePlayer.gd` already has a name-tag `Label3D` — add a
  transient emote bubble). Local player shows it on their own avatar too.
- **Ping display:** a world marker at the pinged tile (reuse the tap-to-move destination
  marker / compass waypoint visuals, GID-047/GID-049) with the pinger's color; auto-expire.
- **Input parity (CLAUDE.md "Mobile / Desktop Feature Parity"):** emote wheel = a HUD
  button opening a radial of presets (tap on mobile, key/click on desktop); ping = a
  dedicated "ping mode" toggle or long-press on the world / minimap, with a desktop
  key equivalent.
- **Content:** a small preset set (e.g. greet, thanks, help, attack-here, retreat,
  laugh) — no free text (avoids moderation + localization scope, cf. BID-015).
- **Tests:** `SocialSync` encode/decode round-trip + a loopback smoke if cheap.

## Plan

- `game_logic/net/SocialSync.gd` — pure encode/decode for emote + ping packets (like AvatarSync).
- `NetSync.gd` — two new RPCs: `recv_emote(payload)` and `recv_ping(payload)`.
- `RemotePlayer.gd` — transient `_emote_label: Label3D` above the name tag; auto-hides after 3 s.
- `WorldScene.gd` — emote wheel HUD button (opens a radial panel), ping mode toggle button,
  ping marker (Label3D at tapped tile, colored per pinger, auto-expires), same-map guard on
  receive (reuse `_remote_player_maps`). Local emote fires on own avatar too.
- `tests/unit/test_social_sync.gd` — encode/decode round-trip for emotes + pings.

## Changes Made

- **`game_logic/net/SocialSync.gd`** (new): pure encode/decode for emote and ping packets. `EMOTE_IDS` (6 presets), `EMOTE_LABELS`, `PING_PLACE`/`PING_ENEMY` kinds, `EMOTE_DURATION = 3.0`, `PING_DURATION = 5.0`. Wire arrays: `[emote_id, map]` and `[x, z, kind, color_hex, map]`. Fully defaulted on garbage input.
- **`game_logic/net/SocialSync.gd.uid`** (new): `uid://chxx8jxlmyeu`
- **`scenes/world/NetSync.gd`**: added `recv_emote(payload)` (unreliable_ordered) and `recv_ping(payload)` (unreliable_ordered) RPCs.
- **`scenes/world/entities/RemotePlayer.gd`**: added `_emote_label: Label3D` above name tag; `show_emote(text)` shows it for `EMOTE_DURATION` seconds; `_process` ticks the timer and hides it.
- **`scenes/world/WorldScene.gd`**: emote wheel HUD button (opens a 6-button GridContainer radial of presets); ping mode toggle; `_handle_ping_tap` (ray-plane intersection → `_send_ping`); `_spawn_ping_marker` (torus mesh with emission, pulse tween, auto-expires via `_tick_ping_markers`); local emote bubble on own avatar; same-map guard on receive (`_remote_player_maps`).
- **`tests/unit/test_social_sync.gd`** (new): 16 cases — emote round-trip for all 6 preset ids, map field, garbage/empty tolerance; ping round-trip preserving coords/kind/color/map, partial array defaults, negative coords, constants sanity.
- **`tests/unit/test_social_sync.gd.uid`** (new).

## Documentation Updates

Updated `docs/agent/multiplayer-coop.md`: added GID-101 Social & Rewards section covering emotes, pings, trading, spectating, wagered duels, champion record, and party bounties; updated Rewards section; updated Tests table.
