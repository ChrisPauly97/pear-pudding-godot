# BID-024: Co-op map (madrian) has no enemies/chests to exercise world sync

**Type:** gap (product/content)
**Discovered during:** GID-096 (Co-op World State Sync)
**Severity:** low

## Context

GID-096 built authority-owned sync + session persistence for shared enemies and chests in
co-op. However, co-op only ever lands on **madrian** (`SceneManager.enter_map_coop("madrian")`,
hardcoded in `MultiplayerLobbyScene`), and `assets/maps/madrian.tres` has `enemies = []` and
`chests = []`. So the world-sync system, while correct and map-agnostic, is **dormant in
practice** — there is no live enemy or chest to fight/open in a real session.

The system is verified end-to-end with synthetic ids by `tests/net_world_sync_smoke.gd`, so
this is a content/reachability gap, not a code bug.

## Options to make it live

- Add enemies/chests to a co-op-reachable map (e.g. a second town/field map, or place a few
  in madrian's outskirts), **or**
- Allow co-op to enter a different named map / a co-op-enabled dungeon (would also need the
  finite-map constraint honored — dungeons are finite named maps, so this is plausible).

## Notes

- Infinite chunk world is explicitly out of co-op scope (chunk sync), so the live target must
  be a finite named map.
- No code change is required for the sync itself — only map content or the `enter_map_coop`
  destination.
