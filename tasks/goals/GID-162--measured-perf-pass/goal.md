# GID-162: Measured Perf Pass — Chunk Streaming Spikes, Leaks, Steady Costs

## Objective

Find and fix world performance problems by measurement (headless profiler), not guesswork.

## Context

User asked to find new perf issues. Added `tools/profile_world.gd`: walks the hero through the stitched towns
and wilderness with the real WorldScene, reports frame-time percentiles, tags each spike with chunk-streaming
events (kick / commit / physics / unload) and WorldScene's share, times every `_process` in isolation, times the
main-thread chunk-landing stages, and prints engine monitors (orphan nodes).

Baseline (12 u/s, 900 frames, 4-core container): p99 27.5 ms, max 50-58 ms; 74→112 orphan nodes growing with
distance. The flat 6.9 ms median is the 144 fps cap, not work.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-670](TID-670--measured-perf-fixes.md) | Profiler; realm stamp per-chunk context; quest-mark one-pass states; shared ring material; far-walker throttle; WallCollision leak + guard | agent | done | — |

## Acceptance Criteria

- [x] Spikes reduced (p99 27.5 → ~17 ms, max ~55 → ~29 ms in the same walk); no pop-in (0 frames on an unbuilt chunk).
- [x] Orphan-node leak fixed and guarded in a CI smoke test.
- [x] Behaviour-preserving changes proven by equivalence tests.
- [x] Tests, all smoke tests, gdlint, `unsafe-hits.sh`, headless import clean.
