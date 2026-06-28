# TID-358: Pluralize authored story dialogue in story.md

**Goal:** GID-098
**Type:** human-action
**Status:** pending
**Depends On:** TID-357

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

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

_Agent prepares the change list during/after TID-357; human applies._

## Changes Made

_Human confirms when applied._

## Documentation Updates

_n/a — human-owned doc._
