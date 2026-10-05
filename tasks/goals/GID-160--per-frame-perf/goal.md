# GID-160: Codebase Cleanup — Per-Frame Perf Pass

## Objective

Remove avoidable per-frame allocations and sorts from the world's hot paths (mobile target).

## Context

User asked to check for perf issues. Audit of every `_process` / `_physics_process` and what
`WorldScene._process` calls each frame. Chunk streaming (threaded terrain prep, kick/commit/physics budgets),
save flush (worker thread), interaction scan (throttled), minimap viewport (rendered every N frames) are already
in good shape.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-668](TID-668--hot-path-fixes.md) | Contact-shadow top-K, copy-free realm entity reads, HUD coord label only on change | agent | done | — |

## Acceptance Criteria

- [x] No full sort / whole-array copy per frame in the fixed paths; behaviour unchanged.
- [x] Tests, smoke tests, gdlint, `unsafe-hits.sh`, headless import clean.
