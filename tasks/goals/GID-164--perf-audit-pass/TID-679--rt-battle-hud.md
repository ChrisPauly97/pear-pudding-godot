# TID-679: Realtime battle HUD: value-only updates, cached styleboxes, reused status labels

**Goal:** GID-164
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Realtime battle rebuilds hero HUD styling and status labels every frame. Part of GID-164 (3-agent perf audit, 2026-10-05).

## Research Notes

- `scenes/battle/modules/BattleRealtime.gd:487` calls `_view.refresh_hero(player_hero_view…)` every `_process`.
- `scenes/battle/CardViewBuilder.gd:664-695` new `StyleBoxFlat` + `add_theme_stylebox_override` each call → theme change + relayout.
- `scenes/battle/BattleFx.gd:138-153` `_update_status_icons_impl` queue_frees and recreates status Labels.
- Fix: realtime per-frame path updates HP/mana text and bars only; cache styleboxes per state key, reapply only on key change; reuse labels (toggle visible / set text).
- Respect `_bind_state()` / `_seat_idx()` (CLAUDE.md null GameState learning). Run battle smoke tests.

Validation for every task: headless import parse check, `scripts/unsafe-hits.sh`, `gdlint`, `tests/runner.gd` (no `SCRIPT ERROR` in log), relevant smoke tests.

## Plan

- Hero panel: shared per-state styleboxes in new `scenes/battle/HeroPanelStyle.gd` (kept out of the oversized CardViewBuilder, which shrank by 18 lines); override re-applied only when the state key changes.
- Status rows (hero and cards): rebuilt only when the status text signature changes.
- HP/mana label text and bar values: left as is — Label.text / Range.value setters are no-ops on equal values.

## Changes Made

- `scenes/battle/HeroPanelStyle.gd` (new), `scenes/battle/CardViewBuilder.gd`, `scenes/battle/BattleFx.gd` (stays under 500 lines).
- `tests/unit/test_battle_hud_cache.gd`: status row reuses nodes until a status changes; styles shared per state.
- Validation: import, gdlint, unsafe-hits, 3024 passed / 0 failed, 0 SCRIPT ERROR, all smoke tests (incl. realtime_battle_smoke, in_world_battle_smoke).

## Documentation Updates

- `docs/agent/battle-system.md` refresh_hero entry.
