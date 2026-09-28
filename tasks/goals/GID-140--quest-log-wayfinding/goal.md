# GID-140: Quest Log & Wayfinding

## Objective

Tie the story into the world and make it obvious where to go next: a quest
model covering story, treasure and bounty work, a tracked quest that drives the
compass / beacon / minimap, a realm map for the overworld, and a Journal
Quests tab with the story so far.

## Context

Raised by the user (2026-09-27): "what can we do to tie the story in and make
it easier for a player to know where to go" → "just build it". Before this goal
only the single main-story objective (`ObjectiveTracker`) was marked, on the
compass and a beacon; the minimap never showed it, the map view (M) did not
open at all in the overworld where the story now happens (GID-138), there was
no quest log, and after Chapter 2 the objective went blank.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-581 | Quest Model — Story Steps Table & QuestLog | agent | done | — |
| TID-582 | Tracked Quest Drives Compass, Beacon & Minimap | agent | done | TID-581 |
| TID-583 | Realm Map in the Overworld | agent | done | TID-581 |
| TID-584 | Journal Quests Tab & Quest-Updated Toasts | agent | done | TID-582 |
| TID-585 | Docs | agent | done | TID-584 |
| TID-586 | NPC "!" / "?" Quest Marks | agent | done | TID-585 |

## Acceptance Criteria

- [x] Every story step carries a chapter, giver and a line of "why"
- [x] Active quests: story, treasure dig site, accepted bounties; never an empty story entry after Chapter 2
- [x] The tracked quest is persisted and drives compass chevron, beacon and minimap pin
- [x] M / minimap tap opens a realm map in the overworld with towns, roads, player and quest pins
- [x] Journal has a Quests tab (track button, story so far) — tap and keyboard reachable
- [x] A toast announces each new story step
- [x] "!" / "?" over the story NPC and bounty boards
