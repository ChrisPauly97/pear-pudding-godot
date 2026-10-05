# TID-685: Profile before/after, docs + CLAUDE.md

**Goal:** GID-164
**Type:** agent
**Status:** done
**Depends On:** TID-672..TID-684

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Prove the gains and keep agent docs current. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- Baseline first (before any task lands, record in this file): `godot --headless --path . -s tools/profile_world.gd -- --frames 900`. Earlier numbers (600 frames): prepare_terrain town 26 ms / wild 13 ms; CharacterPresence 167 µs, WalkCycle 122 µs, TownLife 116 µs, AmbientTouches 115 µs; quest_tracker.refresh ~0.5 ms.
- Re-run after; report deltas in goal.md.
- Battle/UI/save changes have no profiler (see BID-089) — verify by tests + review.
- Update docs: world-generation.md, terrain-rendering.md, visual-polish.md, battle-system.md, save-system.md, inventory-and-deck.md, ui-and-scene-management.md; CLAUDE.md learnings if any.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

- Baseline taken before TID-673 (TID-672 is rendering-only, invisible headless); re-profiled after TID-684 with the same 900-frame walk.
- Results table in goal.md; follow-ups in BID-090.

## Changes Made

- goal.md results table + acceptance criteria; BID-090 logged; CLAUDE.md learning (measure before fixing; exact skips + equivalence tests; idle nodes stop processing).
- Agent docs were updated per task (visual-polish, terrain-rendering, enemies-and-npcs, ui-and-scene-management, story-implementation, multiplayer-coop, battle-system, named-maps-and-dungeons, save-system, inventory-and-deck).

## Documentation Updates

- CLAUDE.md Bug Fix Learnings entry.
