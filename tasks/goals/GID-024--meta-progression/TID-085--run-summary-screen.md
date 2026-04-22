# TID-085: Run Summary Screen

**Goal:** GID-024
**Type:** agent
**Status:** done
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

Create RunSummaryScene showing session stats (battles won/lost, enemies defeated, cards earned, coins earned, chests opened, time played); ephemeral session_stats Dictionary on SceneManager reset on new/continue game. go_to_menu() routes through summary when leaving from world. go_to_menu_direct() goes straight to menu (used by summary's Return button). Track chests_opened in WorldScene, battles_won/lost/enemies/coins in SceneManager.

## Changes Made

- Created `scenes/ui/RunSummaryScene.gd` + `.uid` + `.tscn` + `.tscn.uid` — summary screen with 7 stat rows and Return to Menu button
- `autoloads/SceneManager.gd`: added session_stats Dictionary; _reset_session_stats(); go_to_menu() now routes through RunSummaryScene when leaving world; go_to_menu_direct() bypasses summary; _on_battle_won/_on_battle_lost track session stats; RUN_SUMMARY state added
- `scenes/world/WorldScene.gd`: chests_opened tracked in session_stats on chest open

## Documentation Updates

_Updated in meta-progression doc._
