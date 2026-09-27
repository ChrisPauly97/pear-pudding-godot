# TID-580: Docs

**Goal:** GID-139
**Type:** agent
**Status:** done
**Depends On:** TID-579

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Agent docs for the quest model and wayfinding.

## Research Notes

- `docs/agent/story-implementation.md`, `ui-and-scene-management.md`, CLAUDE.md doc table.

## Plan

Docs for StoryQuests/QuestLog/tracked quest/realm map. The full suite then failed the WorldScene line-ceiling guardrail (BID-055), so the quest wayfinding code moved into a world module first.

## Changes Made

- New world module `scenes/world/modules/QuestTracker.gd` (`quest_tracker`): quest cache, beacon, new-objective tip, realm map toggle; WorldScene back under its pre-goal size (2118 lines). WorldHUD / Minimap / smoke test read `quest_tracker`.
- RealmMapOverlay: title + close inside the panel (overlapped the compass caption in an xvfb screenshot), larger player dot, wider margin.
- Docs: story-implementation.md (StoryQuests table, Quest Log & Tracked Quest section), ui-and-scene-management.md (realm map, compass/beacon), CLAUDE.md module table + doc row.

## Documentation Updates

story-implementation.md, ui-and-scene-management.md, CLAUDE.md.
