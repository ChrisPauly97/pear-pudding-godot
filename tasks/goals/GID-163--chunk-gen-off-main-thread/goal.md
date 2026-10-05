# GID-163: Chunk Generation Off the Main Thread (BID-088)

## Objective

Move infinite-world chunk data generation (neighbour tile data, entity data, snapshot) from the
main-thread kick into the worker task, removing the remaining chunk-boundary hitch.

## Context

User asked to do BID-088. After GID-162, kicking a chunk near a town still cost ~5-8 ms on the main thread.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-671](TID-671--worker-chunk-gen.md) | Worker-side generation + snapshot, commit-side cache insert, warm-up, end-to-end equality check | agent | done | — |

## Acceptance Criteria

- [x] Kick does no generation on the main thread for infinite worlds.
- [x] Streamed chunks identical to main-thread generation (smoke check, mutation-verified).
- [x] No pop-in; frame spikes reduced (profiler).
- [x] Tests, all smoke tests (streaming smoke ×6), gdlint, `unsafe-hits.sh`, headless import clean.
