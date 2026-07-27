# TID-472: Rally From Inside a Shared Dungeon

Goal: [GID-125](goal.md) · Backlog: BID-040 · Type: agent · Status: done

## Problem

Rally buttons reused the waystone fast-travel gate, which blocks travel whenever
`SceneManager.current_map` starts with `dungeon_`. So a player could not rally to
teammates while inside a shared dungeon crawl — the exact situation rally exists
for (e.g. auto-respawned at the entrance while the party pushed on).

## Changes Made

`scenes/ui/MapViewOverlay.gd` (`_build_fast_travel_panel`) — split the single
`is_blocked` flag in two:

- `is_blocked` (unchanged: not in `WORLD` state **or** inside a dungeon) still
  gates waystone buttons.
- `is_rally_blocked` (not in `WORLD` state only) now gates rally buttons, so
  only an active battle blocks rallying.

Reworded the block label to "Waystone travel unavailable…" since it no longer
describes the rally section beneath it.

## Why No Transport Changes Were Needed

`WorldScene._rally_to_peer` already calls
`_net_sync.rpc("recv_map_transition", target_map, "")` +
`SceneManager.enter_map(target_map, "")` — the same mechanism as the Dungeon
Crawl and Guildhall buttons. `SceneManager.enter_map()` pushes the current map
(dungeon included) onto `map_stack` and calls `save_manager.sync_stacks()` +
`save()` before loading, so map-stack and save correctness on the way out of a
dungeon was already handled. This was purely a UI gating bug.

## Documentation Updates

`docs/agent/multiplayer-coop.md` — Rally waystones section; removed the stale
"known limitation" note.
