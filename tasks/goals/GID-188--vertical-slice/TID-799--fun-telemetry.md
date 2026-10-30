# TID-799: Playtest telemetry for fun metrics (AppLog)

**Goal:** GID-188
**Type:** agent
**Status:** todo
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

## Changes Made

## Documentation Updates
