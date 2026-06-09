# TID-150: Death/Exit Flow + Run Summary Integration

**Goal:** GID-038
**Type:** agent
**Status:** pending
**Depends On:** TID-147, TID-148

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The run's ending is its payoff: death (or voluntary retreat) ends the climb, discards the draft deck, and shows the run summary. Without a satisfying ending screen the mode feels like punishment instead of a score chase.

## Research Notes

- **Death in the Spire:** Hero death in a spire battle must NOT route to the standard GameOverScene flow. Branch in `scenes/battle/BattleScene.gd`'s defeat handler: if a spire run is active → `SaveManager.end_spire_run()` → transition to RunSummaryScene with the stats dict. The player respawns at the Spire entrance (use `SceneManager.exit_spire()` from TID-149).
- **Voluntary retreat:** Each floor's entrance area includes a "Leave the Spire" door/prompt. Retreating banks nothing extra but still shows the summary — keep it simple for v1 (no partial rewards).
- **Permanent reward:** To make runs worthwhile, award coins on run end: e.g. `floor × 5` coins (uses the GID-007 economy). Stated on the summary screen.
- `scenes/ui/RunSummaryScene.gd` — exists from GID-024 (meta-progression session stats). Check its input contract; extend with a spire variant: floors cleared, enemies defeated, cards drafted (names list), coins earned. Reuse layout; mobile-first sizing.
- **Best-floor record:** Add `spire_best_floor: int` to SaveManager (with migration) and show "New record!" on the summary when beaten. Cheap, high-motivation.
- **Achievement hooks:** `game_logic/AchievementRegistry.gd` (GID-024): e.g. "Reach floor 5", "Reach floor 10". Follow existing registration pattern.
- `autoloads/GameBus.gd` — `spire_run_ended(stats: Dictionary)` signal so the summary and achievements decouple from BattleScene.
- **Tests:** Headless test for `end_spire_run()` stat payload and `spire_best_floor` update logic.
- `docs/agent/meta-progression.md` — document the spire summary variant and achievements.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
