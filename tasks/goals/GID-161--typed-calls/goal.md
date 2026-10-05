# GID-161: Codebase Cleanup — Typed Calls Instead of String Dispatch

## Objective

Replace `obj.call("method")` / `has_method` / `.get("field")` on receivers with one known type by typed calls,
so a renamed method fails at parse time instead of silently no-oping.

## Context

User asked to keep cleaning up. CLAUDE.md: "Unsafe access is an error… `.call()` only for genuinely
one-of-several unrelated types". ~120 `.call("…")` and ~80 `has_method` sites remained, many on receivers whose
type is fixed (and in `ChunkRenderer` already statically typed, making the guards dead code).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-669](TID-669--typed-calls.md) | Type WorldEvents, avatar/follower terrain lookups, co-op avatar calls, ChunkRenderer/TapToMove/WorldScene guards | agent | done | — |

## Acceptance Criteria

- [x] Converted sites are statically checked; behaviour unchanged (except the sparkle-material fix below).
- [x] Tests, all smoke tests, gdlint, `unsafe-hits.sh`, headless import clean.
