# GID-075: Dead Code, Constants & Test Hygiene

## Objective

Remove orphaned files and dead functions, consolidate duplicated constants into IsoConst, and fix stale test assertions.

## Context

The June 2026 simplification sweep found 8 orphaned .uid sidecars, ~11 never-called functions, CHUNK_SIZE redefined in 7 files despite IsoConst being the canonical source (spec: "All tile types, sizes, and ranges in IsoConst — no duplicates elsewhere"), a terrain-constant mismatch between the named-map and infinite-chunk paths, and a test that will fail because it asserts a stale card count. Resolves backlog items BID-004 (orphaned .uid sidecars) and BID-007 (stale card registry test count) — when each is fixed, the executor moves its file from tasks/backlog/ to tasks/archive/backlog/ and updates tasks/index.md. Coordination: GID-064 TID-236 (dead code & config cleanup sweep from the earlier audit) is pending and may overlap — whichever runs second checks the other's Changes Made to avoid re-doing work. All three tasks are independent.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-276 | Orphaned files and dead functions | agent | pending | — |
| TID-277 | Constants consolidation | agent | pending | — |
| TID-278 | Stale test fixes | agent | pending | — |

## Acceptance Criteria

- [ ] No .uid sidecar exists without its primary file
- [ ] All listed dead functions are removed
- [ ] CHUNK_SIZE/TILE_SIZE have exactly one definition in IsoConst with all call sites referencing it
- [ ] Named-map vs chunk terrain-radius discrepancy is resolved or explicitly documented as intentional
- [ ] Full test suite passes headless (`godot --headless --path . -s tests/runner.gd`)
