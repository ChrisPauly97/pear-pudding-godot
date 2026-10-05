# TID-684: Deck builder: debounced search, persistent tiles, incremental add/remove

**Goal:** GID-164
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Every keystroke / add / remove / filter rebuilds the whole collection UI. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `scenes/ui/InventoryScene.gd:324-368` `_refresh_cards` frees + rebuilds loadout bar, backpack grid, deck list.
- Callers: search `:253-255`, add/remove/filter/tab `:458, :501, :941`.
- Fix: 150 ms debounce timer on search; tiles in dict keyed by uid, filtering toggles `visible`; add/remove updates the affected tile + deck list row only; loadout bar rebuilt only when loadouts change.
- Use UiUtil factories; keep drag-scroll behaviour.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

- Search: 0.15 s one-shot Timer restarted on each keystroke.
- Bag tiles: new `scenes/ui/inventory/TileCache.gd` (kept out of the oversized InventoryScene) — detach before the grid is freed, reuse on equal signature (instance hash, deck tag, selected, select mode, face, size), sweep unshown. The deck list (small) still rebuilds.
- Loadout bar: skipped when its signature is unchanged.
- `_template()` → cached read-only `get_template_view` (sort comparator, search and tiles only read it).

## Changes Made

- `scenes/ui/InventoryScene.gd`, `scenes/ui/inventory/TileCache.gd` (new), `.github/workflows/tests.yml` (smoke list).
- Tests: `tests/unit/test_tile_cache.gd`; `tests/inventory_tiles_smoke.gd` (live scene: unchanged tiles reused, debounced search applies only after the pause; mutation-checked).
- Validation: import, gdlint, unsafe-hits, 3029 passed / 0 failed, 0 SCRIPT ERROR, all smoke tests.

## Documentation Updates

- `docs/agent/inventory-and-deck.md` loadout bar + refresh cost.
