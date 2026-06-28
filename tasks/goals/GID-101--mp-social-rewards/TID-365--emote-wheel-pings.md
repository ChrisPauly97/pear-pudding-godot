# TID-365: Emote wheel & map pings

**Goal:** GID-101
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
