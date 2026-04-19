# TID-085: Run Summary Screen

**Goal:** GID-024
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

When players return to the main menu there is no record of what they accomplished in their session. A summary screen gives a satisfying sense of closure and shows progress concretely.

## Research Notes

- New scene `scenes/ui/RunSummaryScene.gd` — displayed between world and main menu when the player explicitly exits (not on death, which uses GameOverScene)
- Stats to display:
  - Battles won / lost
  - Enemies defeated (total and by type)
  - Cards earned this session
  - Coins earned / spent
  - Chests opened
  - Named maps visited
  - Time played (seconds, formatted as mm:ss)
- `autoloads/SaveManager.gd` — add a `session_stats: Dictionary` that resets on new game / manual reset at session start; increment counters via GameBus signals or direct calls
- Session stats are ephemeral (not persisted to save file between sessions) — store them in a static Dictionary on SceneManager or a new SessionStats autoload
- `autoloads/SceneManager.gd` — add a `go_to_summary()` method that routes to RunSummaryScene; RunSummaryScene has a "Return to Menu" button that calls `SceneManager.go_to_menu()`
- Trigger: the "Return to Menu" option in the pause/exit flow in WorldScene should route through RunSummaryScene instead of going directly to MenuScene
- Follow CLAUDE.md UI sizing; the layout should be clean and readable at mobile resolution

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
