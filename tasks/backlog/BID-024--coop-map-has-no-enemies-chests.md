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

## Update (GID-102 / TID-380 — Shared dungeon crawl)

TID-380 implements the second option above: a host-only "Dungeon Crawl" HUD button
(`WorldScene._ensure_dungeon_button` / `_start_dungeon_crawl`) lets the co-op party enter a
procedural `DungeonGen` dungeon together, broadcasting the shared seed via the existing
TID-355 `recv_map_transition` RPC. Every generated dungeon has 3-4 combat rooms plus an end
room, so co-op sessions now have a real, reachable source of live enemies/chests, and
GID-096's engage-lock / first-opener-takes sync is exercised for real (not just by
`net_world_sync_smoke.gd`'s synthetic ids) — confirmed by reasoning from `DungeonGen`'s
purely index-based, seed-deterministic entity ids (see `docs/agent/multiplayer-coop.md`).

**Not closing this item**: madrian itself — the map co-op actually lands on by default via
`enter_map_coop("madrian")` — still has `enemies = []` / `chests = []`. The dungeon crawl is
an *opt-in side trip* the host must trigger; it doesn't change madrian's own content. If a
future task adds enemies/chests directly to madrian (the first option above), that would
fully close this item. Leaving open, scoped down to "madrian itself has no content."
