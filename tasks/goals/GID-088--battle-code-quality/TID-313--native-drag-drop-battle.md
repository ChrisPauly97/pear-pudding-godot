# TID-313: Migrate battle drag-to-play to native Godot drag-and-drop

**Goal:** GID-088
**Type:** agent
**Status:** pending
**Depends On:** TID-312

## Lock

Session: none
Acquired: —
Expires: —

## Context

`BattleScene.gd:329-421` implements drag-to-play via global `_input` mouse tracking with a manually positioned ghost Control. Godot's native drag-and-drop API (`_get_drag_data`, `_can_drop_data`, `_drop_data` on Control nodes) is the correct pattern: it handles both mouse and touch transparently, reduces manual state, and eliminates the ghost positioning logic.

**Critical**: the long-press-to-inspect interaction must be re-verified on Android after migration. Native drag on touch starts on drag threshold, which may conflict with the tap-to-inspect gesture. The migration plan must document how to disambiguate.

## Plan

## Changes Made

## Documentation Updates
