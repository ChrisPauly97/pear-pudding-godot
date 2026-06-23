# TID-324: MultiplayerLobbyScene UI + MenuScene entry + SceneManager coop hook

**Goal:** GID-090
**Type:** agent
**Status:** done
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

1. Create `scenes/ui/MultiplayerLobbyScene.gd` extending `BaseOverlay` (script-only,
   instantiated via `.new()` — matching SettingsScene/DiagnosticsScene; no `.tscn`).
   - Dark-glass panel: title, info line, IP `LineEdit` (prefill `127.0.0.1`),
     Host/Join buttons, status label, Close button. Viewport-relative via `_vh/_vw/_ref`.
   - Rebuild on `NOTIFICATION_RESIZED`.
   - Host: `NetworkManager.host()`; on OK → `SceneManager.enter_map_coop("madrian")`.
   - Join: `NetworkManager.join(ip)`; on `connection_succeeded` →
     `enter_map_coop("madrian")`; on `connection_failed` → status + `leave()`.
   - On `closed` while a session is half-open (joining), call `NetworkManager.leave()`.
2. MenuScene: add preload + a "Co-op (Beta)" button opening the lobby overlay
   (same pattern as Settings: `add_child` + `closed`→`queue_free`).
3. SceneManager: add `enter_map_coop(map_name)` — `_exit_world_cleanup()` then reuse
   `enter_map(map_name, "")` (save() is a no-op when no game loaded; current_map
   cleared so no stale stack push).
4. WorldScene `_spawn_player`: nudge the non-host avatar +2 tiles so the two
   avatars don't perfectly overlap at spawn (guarded by `NetworkManager.is_active()`).
5. Headless compile + full test run.

## Changes Made

- Created `scenes/ui/MultiplayerLobbyScene.gd` (+ editor `.gd.uid`) extending
  `BaseOverlay`, script-only `.new()` overlay (matches SettingsScene — **no `.tscn`
  needed**, deviating from the task's suggestion to follow the established pattern):
  - Dark-glass panel with title, info line, IP `LineEdit` (prefill `127.0.0.1`),
    Host/Join buttons, status label, Close button; viewport-relative via `_vh/_vw/_ref`
  - Rebuilds UI on `NOTIFICATION_RESIZED` (preserving IP text + status)
  - Host → `NetworkManager.host()`; on OK → `SceneManager.enter_map_coop("madrian")`
  - Join → `NetworkManager.join(ip)`; on `connection_succeeded` →
    `enter_map_coop("madrian")`; on `connection_failed` → status + `leave()`
  - On `closed` with a half-open session, calls `NetworkManager.leave()`
- `scenes/ui/MenuScene.gd`: preload + "Co-op (Beta)" button (after New Game)
  opening the lobby overlay (same add_child + `closed`→`queue_free` pattern as Settings)
- `autoloads/SceneManager.gd`: added `enter_map_coop(map_name)` — `_exit_world_cleanup()`
  then reuse `enter_map(map_name, "")`. `save()` is a no-op without a loaded game,
  so this is safe launched cold from the menu; cleared current_map avoids a stale
  stack push.
- `scenes/world/WorldScene.gd` `_spawn_player`: non-host avatar nudged +2 tiles
  (guarded by `NetworkManager.is_active() and not multiplayer.is_server()`) so the
  two avatars don't overlap at the shared madrian spawn.
- All 1530 tests pass; headless compile clean. Live 2-instance run is verified in TID-325.

## Documentation Updates

None required — `docs/agent/multiplayer-coop.md` is created by TID-326.
