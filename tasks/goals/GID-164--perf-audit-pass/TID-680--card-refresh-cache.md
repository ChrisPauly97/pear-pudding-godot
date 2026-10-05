# TID-680: Card refresh: cached face templates, badge signature diff

**Goal:** GID-164
**Type:** agent
**Status:** done
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

- `CardRegistry.get_template_view(id, face)`: cached read-only template, used only by the render paths (CardViewBuilder.apply_card_style, CardArt) — the other ~30 callers keep fresh dicts since several store or edit them.
- Keyword badges rebuilt only when keywords / shroud / font size change (`badge_sig` meta); card status rows got the same treatment in TID-679.

## Changes Made

- `autoloads/CardRegistry.gd`, `scenes/battle/CardViewBuilder.gd`, `scenes/battle/CardArt.gd`.
- `tests/unit/test_battle_hud_cache.gd::test_template_view_is_cached_and_equal` (every card, both faces).
- Validation: import, gdlint, unsafe-hits, 3025 passed / 0 failed, 0 SCRIPT ERROR, all smoke tests.

## Documentation Updates

- `docs/agent/battle-system.md` refresh entry.
