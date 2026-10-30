# TID-799: Playtest telemetry for fun metrics (AppLog)

**Goal:** GID-188
**Type:** agent
**Status:** done
**Depends On:** TID-794

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Log the metrics that say whether the slice is fun: time to first fight, time to first capture, fights per session, deck edits, deaths, quit point (last activity before exit), time to slice boss. Viewable in Diagnostics and exportable for playtesters.

## Research Notes

- `docs/agent/app-diagnostics.md` (AppLog ring buffer, auto-logged GameBus signals, DiagnosticsScene).
- Keep literal `GameBus.<signal>.emit()` calls (`test_gamebus_signal_coverage`).

## Plan

Pure `PlaytestMetrics` over one persisted Dictionary; a SaveManager module listens to GameBus and ticks play time;
Diagnostics shows the report and Copy exports it (no network — playtesters paste it to you).

## Changes Made

- `game_logic/PlaytestMetrics.gd` (new): `note`, `tick`, `first_at`, `count_of`, `clock`, `summary`. Events: fight,
  win, loss, capture, deck_edit, level, learn, quest, slice_complete, session.
- `autoloads/save_manager/SavePlaytest.gd` (new, `SaveManager.playtest_log`): GameBus hooks (enemy_engaged,
  battle_won incl. `signature_capture`, battle_lost, level_up, feature_learned, quest_turned_in, story_flag_set →
  `slice_complete`), 1 s play clock outside the main menu.
- `SaveManager`: `playtest` field (PERSISTED_FIELDS), reset + session note in `new_game`; `SceneManager.continue_game`
  notes a session; `InventoryScene._commit_deck` notes a deck edit.
- `DiagnosticsScene`: "Playtest" button shows the report; existing Copy puts it on the clipboard.
- Tests: `tests/unit/test_playtest_metrics.gd` (5). Suite 3657 pass.

## Documentation Updates

- `docs/agent/app-diagnostics.md`: Playtest report section. `docs/agent/vertical-slice.md`: telemetry row.
