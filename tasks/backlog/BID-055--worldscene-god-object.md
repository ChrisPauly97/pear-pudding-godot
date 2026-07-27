# BID-055: `WorldScene.gd` is a 9154-line god object with 401 functions

Category: code-smell / design-gap
Discovered during: GID-124 research (code-health survey)

## Summary

`scenes/world/WorldScene.gd` is **9154 lines and 401 functions** — 13% of all
GDScript in the repo (71,664 lines total) in a single file. It is 2.3x the next
largest file (`BattleScene.gd`, 3925) and 9x the `max-file-lines: 500` limit the
project sets for itself in `.gdlintrc`.

## Why this matters

- Every co-op, siege, dungeon, rally, auction and spawn feature has landed in
  the same file, so unrelated features share one merge surface. Two of the
  agents in this very session had to be serialised because both needed to touch
  it.
- 109 of the 401 functions are `_on_*` signal handlers, so control flow is
  almost entirely implicit — there is no way to see which subsystem owns what.
- It is the single biggest contributor to the `max-file-lines` and
  `max-public-methods` counts in BID-053.

## Prior art

`GID-072 — World Layer Decomposition` is marked **done (4/4)** and did extract
real collaborators — `ChunkRenderer`, `ChunkStreamingManager`, `DayNightCycle`,
`Minimap`, `NetSync`, `WeatherParticles`, `WorldHUD`, `DungeonSessionUI`. But
the file kept growing afterwards: everything shipped by GID-096 through GID-122
(co-op world sync, siege, rally, dungeon crawl, auction, tap-to-move, cantrips)
was added straight back into `WorldScene.gd`. The decomposition was a one-time
event with no structural pressure to keep it decomposed.

## Function-prefix census

| Count | Prefix | Suggested owner |
|-------|--------|-----------------|
| 109 | `_on_*` | (spread across all of the below) |
| 22 | `_spawn_*` | `WorldEntitySpawner` |
| 21 | `_coop_*` | `WorldCoopController` |
| 19 | `_show_*` | existing `WorldHUD` / overlay layer |
| 13 | `_request_*` | `WorldCoopController` |
| 11 | `_start_*` | session/mode entry — `WorldModeRouter` |
| 10 | `_broadcast_*` / 8 `_send_*` | existing `NetSync` |
| 10 | `_tick_*` | a per-frame `WorldTicker` |

The co-op/net cluster alone (`_coop_*` + `_request_*` + `_broadcast_*` +
`_send_*` = 52 functions) is a coherent, mostly self-contained extraction and
would be the highest-value first slice.

## Suggested resolution

Promote to a goal. Extract in slices, one merge-window each, tests green between
slices:

1. **Co-op/net controller** (~52 functions) — biggest win, cleanest seam.
2. **Entity spawning** (~22 functions) — `_spawn_*` into a `WorldEntitySpawner`.
3. **Mode routing** (~11 `_start_*`) — siege / dungeon crawl / guildhall / spire.

Add a guardrail test asserting a line-count ceiling for `WorldScene.gd` that
ratchets downward, in the same spirit as the existing
`tests/unit/test_hud_registry_guardrail.gd` — otherwise slice 1 will silently
refill, exactly as it did after GID-072.

## Acceptance

- `WorldScene.gd` under a documented, test-enforced line ceiling.
- The ceiling ratchets down rather than being a one-time cleanup.
