# GID-159: Codebase Cleanup — Dead Code Sweep

## Objective

Delete functions, constants and signals nothing references (BID-087).

## Context

User approved removing the 37 functions + 8 `IsoConst` constants found during GID-157 research.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| [TID-667](TID-667--remove-unreferenced.md) | Remove unreferenced functions, constants and the orphaned `quest_abandoned` signal | agent | done | — |

## Acceptance Criteria

- [x] Every BID-087 item removed; rescan finds no newly orphaned code.
- [x] Tests, smoke tests, gdlint, `unsafe-hits.sh`, headless import clean.
