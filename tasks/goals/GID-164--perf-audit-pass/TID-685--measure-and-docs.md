# TID-685: Profile before/after, docs + CLAUDE.md

**Goal:** GID-164
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
