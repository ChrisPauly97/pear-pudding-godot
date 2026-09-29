# TID-602: Docs

**Goal:** GID-142
**Type:** agent
**Status:** done
**Depends On:** TID-599, TID-600, TID-601

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Record the rift design.

## Research Notes

- Rewrite the Spire sections of `docs/agent/` (find with `grep -rln -i spire docs/agent`) into a rifts description:
  RiftDefs, tier ladders, boons, anti-spam reward rule, rift quests, entrances, co-op/leaderboard.
- CLAUDE.md: update the SaveManager module mention (`spire`) and any Spire bug-fix learnings that reference renamed APIs.
- `docs/agent/game-appeal.md` §5 retention layer: Spire best-floor → per-biome rift tiers.
- Spec mentions (human-owned) → fold into GID-141 / TID-596 human-action notes.

## Plan

`rifts.md` was written task by task; point the older Spire sections at it, record the save fields/migrations, fix the in-game Spire tutorial text.

## Changes Made

`TutorialRegistry` `spire_intro` rewritten for rifts (title "The Rifts").

## Documentation Updates

`rifts.md` (complete), GID-142 notes in `inventory-and-deck.md`, `named-maps-and-dungeons.md`, `multiplayer-coop.md`, `player-home.md`; `save-system.md` fields/migrations v44–v45; `game-appeal.md` retention line.
