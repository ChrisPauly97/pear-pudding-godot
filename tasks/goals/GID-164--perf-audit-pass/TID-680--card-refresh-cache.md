# TID-680: Card refresh: cached face templates, badge signature diff

**Goal:** GID-164
**Type:** agent
**Status:** pending
**Depends On:** TID-679

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Each realtime swing refreshes every card and allocates template dicts. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `BattleRealtime.gd:518` → `_refresh_all` per swing event.
- `CardViewBuilder.gd:567-569` `update_keyword_badges` + status rows free/rebuild children for every card.
- `CardViewBuilder.gd:490` `apply_card_style` → `CardRegistry.get_template_for_face` (`autoloads/CardRegistry.gd:243`) builds ~19-key Dictionary (`data/CardData.gd:44-80`).
- Fix: static cache keyed `id|face` (treat read-only — audit callers for mutation; duplicate at mutating sites); store badge signature (keywords + statuses) as meta/field, skip rebuild when equal.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
