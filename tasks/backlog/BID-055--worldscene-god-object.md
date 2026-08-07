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

## Progress

**Status: open — slice 1 of 3 done.** Do not archive; slices 2 and 3 below are
still outstanding.

### The census in this file was stale before slice 1 even started

Re-running the function-prefix census at the start of slice 1 found
`scenes/world/WorldScene.gd` at **3916 lines / 169 functions** — not the 9154
lines / 401 functions this file was originally filed against. The `_coop_*` +
`_request_*` + `_broadcast_*` + `_send_*` cluster this file calls "the
highest-value first slice" (~52 functions) had only **4 surviving matches**
(`_broadcast_guildhall_garden`, `_broadcast_scroll_collected_coop`,
`_coop_apply_scroll_collected`, `_coop_record_scroll_collected`); there were
no `_request_*` or `_send_*` functions left at all.

Reason: this file was authored on a branch (`TID-466: CI test gate,
reproducible dev setup, backlog reconciliation`, commit `849632b`) that was
concurrent with a separate `simplify/dedup` branch doing real god-object
decomposition work — `e57c32b` "Split the social & economy surface out of
WorldScene", `27790a7` "Split the competitive-play surface out of
WorldScene", `1018a49` "Split shared party content out of WorldScene",
`04eafbe` "Split session lifecycle out of WorldScene, completing the
god-object break-up" — landing the four `scenes/world/coop/*.gd` modules this
file lists as GID-072 "prior art". The two branches merged at `973bc6d`,
*after* this BID was already filed, so its census reflects a pre-merge
snapshot that no longer matches the codebase. By the time slice 1 started,
most of what this file asked for was already done.

### Slice 1 (co-op/net cluster) — done

The genuine residual net-sync cluster was much smaller than advertised: 10
functions, all guildhall-garden co-op sync and co-op scroll-collection sync
(the `_broadcast_*`/`_coop_*`/RPC-handler pair for each). Rather than spin up
a fifth near-empty `coop/` module for ~180 lines, they were folded into
**`scenes/world/coop/CoopSession.gd`**, which already owns "world-object
sync" and "guildhall" per its own header and per CLAUDE.md's Scene Modules
table, and which already called two of these functions directly
(`_world._coop_apply_scroll_collected`/`_coop_record_scroll_collected`) before
the move.

Moved (WorldScene.gd → CoopSession.gd, reached as `coop_session.<fn>` from
WorldScene and unqualified from within CoopSession.gd itself):
- `_on_guildhall_garden_request_submitted`, `_broadcast_guildhall_garden`,
  `_on_guildhall_garden_update_received`, `_submit_session_plant`,
  `_on_session_plant_submitted`, `_submit_session_harvest`,
  `_on_session_harvest_submitted` — into CoopSession.gd's existing
  "Party Guildhall (GID-106 / TID-392)" section.
- `_broadcast_scroll_collected_coop`, `_coop_record_scroll_collected`,
  `_coop_apply_scroll_collected` — into CoopSession.gd's existing
  "Co-op world-object sync (GID-096)" section.

Left on WorldScene.gd (out of scope for this slice, or too entangled with
non-net concerns to move cleanly): `_guildhall_garden_cache` (state var, now
read/written by CoopSession.gd via `_world.`), `_refresh_guildhall_garden_visuals`
(`_refresh_*` prefix — UI push, not net), `_spawn_guildhall_garden`/
`_spawn_guildhall_trophies`/`_spawn_guildhall_stash_chest` (`_spawn_*` prefix —
explicitly slice 2's cluster, not this one), `_on_scroll_collected` (`_on_*`
signal handler for the *local* pickup, not itself networked — it now calls
`coop_session._broadcast_scroll_collected_coop()`).

**Before/after:**

| | Lines | Functions |
|---|---|---|
| `WorldScene.gd` before | 3916 | 169 |
| `WorldScene.gd` after | 3786 | 159 |
| `CoopSession.gd` before | 1428 | 68 |
| `CoopSession.gd` after | 1572 | 78 |

**Verification:** `godot --headless --editor --quit` clean (no parse/compile
errors); `tests/world_scene_smoke.gd` PASS (18/18, including "every parsed
NetSync handler resolves to a real method" and "`_route()` successfully
dispatched every called handler" over all 77 handlers); the full suite
(`tests/runner.gd`) PASS 2356/2356 (2355 + the new guardrail test); coop/PvP
smoke tests (`net_coop_smoke`, `net_coop_npeer_smoke`, `net_world_sync_smoke`
— which directly exercises scroll/enemy/chest world-event sync,
`net_session_smoke`, `net_pvp_smoke`, `net_leaderboard_smoke`,
`net_dedicated_server_smoke`, `net_rehost_smoke`) all PASS.

**Guardrail added:** `tests/unit/test_worldscene_line_ceiling_guardrail.gd`
asserts `WorldScene.gd` stays at or under 3850 lines (current size 3786, a
small buffer against incidental drift). Ratchet the ceiling down whenever a
future slice lands — see the test's own doc comment.

### Slices 2 and 3 — not started

1. **Entity spawning** (`_spawn_*`, ~20 functions surviving in the current
   file — `_spawn_card_items`, `_spawn_coin_piles`, `_spawn_guildhall_*`,
   `_spawn_named_map_*`, `_spawn_player*`, `_spawn_rival*`,
   `_spawn_scout_ambush`, `_spawn_siege_raiders`, `_spawn_wilderness_camp`,
   etc.) into a `WorldEntitySpawner`-style module or helper.
2. **Mode routing** (`_start_*` — only `_start_ghost_phase_tween` remains
   directly on WorldScene.gd today; most `_start_*` mode-entry functions,
   e.g. `_start_guildhall`, `_start_dungeon_crawl`, already live in the coop/
   modules). Re-run the prefix census before scoping this slice — it will
   likely need re-scoping the same way slice 1 did.

Re-run the full function-prefix census before starting either slice — as this
slice demonstrated, the numbers in this file's original body (written before
the `simplify/dedup` merge) are no longer reliable.
