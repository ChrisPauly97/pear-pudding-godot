# TID-405: Chapter 1 Ending Scene + Post-Council Epilogue World Reactivity

**Goal:** GID-108
**Type:** agent
**Status:** pending
**Depends On:** TID-400

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Chapter 1 currently dead-ends at `chapter1_temple_council`. The approved ending (docs/human/story.md "Chapter 1 Victory Condition") gives it a payoff: a narration-overlay ending at King Eldar, the `chapter1_complete` flag, and a playable epilogue world. This task supersedes GID-020/TID-067.

## Research Notes

- **Approved definition (docs/human/story.md):** Trigger = speaking to King Eldar in blancogov_temple AFTER `chapter1_temple_council` is set AND the Queen and Scargroth have each been spoken to (track via two sub-flags, e.g. `chapter1_spoke_queen` / `chapter1_spoke_scargroth`, set on their dialogue interactions). Flag set: `chapter1_complete`. Presentation: narration overlay, three short pages — (1) the alliance is re-sworn, (2) Maiteln tells Saimtar he has earned his place at his side, (3) Scargroth's aside: "there is a name from Larik in the old registers you should see" (Chapter 2 hook). After: return to the world (NOT the menu) as a playable epilogue.
- **Narration overlay reuse:** the scroll narration UI (GID-013) — see docs/agent/story-narration-scrolls.md, scenes/world/entities/StoryScroll.gd and the Journal presentation (scenes/ui/JournalScene.gd). Reuse the same overlay style for multi-page ending text; BaseOverlay patterns in scenes/ui/BaseOverlay.gd (preload it — CLAUDE.md class_name rule).
- **ObjectiveTracker:** game_logic/ObjectiveTracker.gd already returns empty for `chapter1_temple_council`/`chapter1_complete` — update so the pre-ending state shows "Speak with the Queen and Scargroth, then the King" and chapter1_complete shows empty. Update tests/unit/test_objective_tracker.gd.
- **Epilogue reactivity:** the chapter1_complete after-lines in the flag-gated dialogue table (TID-404) provide the war-preparation world state; verify they display after the ending. Consider an achievement hook (game_logic/AchievementRegistry.gd already references chapter1 flags — check for an existing chapter-completion achievement).
- **GID-020 bookkeeping:** TID-067 was marked superseded by this task when GID-108 was created; on completion, tick GID-020's remaining acceptance criteria or note them satisfied here.
- Ending must be reachable on mobile (tap-through pages) and desktop; audio: optional narration audio hook exists in the scroll system.

- **Co-op (up to 4 players):** this feature must follow the TID-408 design rules (shared-flag arbitration via SessionState, exactly-once beat effects, authority-broadcast narration, single synced Maiteln, no write-through to solo saves). Read TID-408--coop-story-compatibility.md before Plan.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
