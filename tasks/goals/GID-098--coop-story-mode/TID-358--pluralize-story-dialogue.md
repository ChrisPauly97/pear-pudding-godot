# TID-358: Pluralize authored story dialogue in story.md

**Goal:** GID-098
**Type:** human-action
**Status:** pending
**Depends On:** TID-357

## Lock

**Session:** claude/work-task-gid-102-gejm0z
**Acquired:** 2026-06-28T15:00:00Z
**Expires:** 2026-06-28T15:30:00Z

## Context

`docs/human/story.md` is the **human-owned** story bible. The agent never edits it.
TID-357 builds the system that selects group vs solo dialogue and adds group variants
to the agent-owned map `.tres` files, but the canonical authored lines in the bible
must be pluralized by the human so the two stay in sync.

## Research Notes (agent prepares; human applies)

- The agent will produce a **change list**: every story.md line that addresses a single
  player ("you, child", "young one", etc.) with a suggested group rewrite ("you,
  travelers", "young ones"), grouped by chapter/NPC.
- The agent will note which lines already have a `dialogue_group` variant authored in
  the corresponding map `.tres` (from TID-357) so the human keeps wording consistent.
- Human action: review the list, apply the edits to `docs/human/story.md`, and confirm
  done. The agent then reconciles any wording deltas back into the map `.tres` variants
  if needed.

## Plan

Agent authored `dialogue_group` values in all five story map `.tres` files (16 NPCs
across madrian, maykalene, farsyth_mansion, blancogov, blancogov_temple). Human
applies corresponding pluralization to the matching rows in `docs/human/story.md`
NPC Dialogue by Map section, then confirms.

## Changes Made

_Human confirms when applied._

## Documentation Updates

_n/a — human-owned doc._
