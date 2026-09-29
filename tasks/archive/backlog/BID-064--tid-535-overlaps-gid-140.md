# BID-064: GID-136 / TID-535 overlaps shipped GID-140

**Category:** design-inconsistency
**Discovered During:** GID-141 research

## Description

TID-535 (Quest Log & On-Screen Tracker, GID-136) is still pending, but GID-140 shipped `QuestLog`, a tracked quest
driving compass/beacon/minimap, a Journal Quests tab and NPC "!"/"?" marks. Most of TID-535's scope is done.

## Evidence

`tasks/goals/GID-136--wow-rpg-loop/TID-535--quest-log-tracker.md`; `game_logic/quests/QuestLog.gd`,
`scenes/world/modules/QuestTracker.gd` (GID-140 / TID-581..586).

## Suggested Resolution

When TID-533 lands, re-scope TID-535 to "register TID-533 side quests in QuestLog" (likely a small change) or close it
as superseded.
