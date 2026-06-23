# TID-324: MultiplayerLobbyScene UI + MenuScene entry + SceneManager coop hook

**Goal:** GID-090
**Type:** agent
**Status:** pending
**Depends On:** TID-321, TID-323

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players need a way to start or join a session. This task adds a minimal lobby
screen reached from a "Co-op (Beta)" button on the main menu, wires its Host/Join
buttons to `NetworkManager`, and adds a thin `SceneManager.enter_map_coop()` hook
so that both peers reliably end up in **madrian** before any avatar RPCs flow.

## Research Notes

**MenuScene:** `scenes/ui/MenuScene.gd` / `.tscn` is the main scene (per
`project.godot`). It shows New Game / Continue / Settings buttons; Settings opens
as an overlay. Add a "Co-op (Beta)" button following the same construction +
overlay pattern the existing buttons use. Keep button sizing viewport-relative
(see CLAUDE.md "UI Sizing: Relative to Viewport").

**Lobby scene:** create `scenes/ui/MultiplayerLobbyScene.gd` + `.tscn` (+ `.uid`).
Consider extending the shared overlay base if appropriate (`scenes/ui/BaseOverlay.gd`
exists per CLAUDE.md and GID-073 introduced a shared theme — check whether other
overlays like Settings extend it, and match that). Contents:
- A `LineEdit` for IP, prefilled `127.0.0.1`.
- Host button → `NetworkManager.host()`.
- Join button → `NetworkManager.join(ip_line.text)`.
- Back button → close overlay / return to menu.
- A status `Label` reflecting `connection_succeeded` / `connection_failed` /
  `server_started` / `peer_connected`.
- All controls sized as fractions of viewport height/width; re-apply sizes in
  `_notification(NOTIFICATION_RESIZED)`. Mobile + desktop parity: these are tap
  targets already, so touch works; ensure the LineEdit is usable on mobile.

**Entering the shared map:**
- **Host flow:** on Host pressed (or on `server_started`), call
  `SceneManager.enter_map_coop("madrian")`. When `NetworkManager.peer_connected(id)`
  fires on the host, RPC the client to load the same map (e.g. a `load_coop_map`
  RPC on a small node, or have the client load madrian itself on
  `connection_succeeded` — simplest: client loads `enter_map_coop("madrian")` on
  its own `connection_succeeded`). Decide the simplest reliable ordering so both
  are in madrian before TID-323's NetSync starts broadcasting.
- **Client flow:** on `connection_succeeded`, route into madrian via
  `enter_map_coop("madrian")`.

**SceneManager hook:** `autoloads/SceneManager.gd` owns `enter_map(map_name,
target_door_id)` and the `State` machine; co-op lives entirely in `State.WORLD`.
Add a thin `enter_map_coop(map_name: String)` wrapper that calls the existing
`enter_map` path (reuse it — do not duplicate map-loading logic) and sets any flag
WorldScene/TID-323 needs to know it's a coop session (or rely solely on
`NetworkManager.is_active()`). Keep changes minimal and additive.

**Spawn separation:** for the slice both players may share the madrian SPAWN
marker; a tiny per-peer offset (e.g. nudge by peer index) avoids exact overlap.
Respect the spawn rules in CLAUDE.md "Named Map Player Spawn vs. Saved Position"
— do not add extra spawn guards.

**CLAUDE.md conventions:** viewport-relative UI; preload referenced scripts;
explicit types; `.uid` sidecar for the new `.tscn`; validate with headless import.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
