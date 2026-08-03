# TID-358: Pluralize authored story dialogue in story.md

**Goal:** GID-098
**Type:** human-action
**Status:** done
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

Agent authored `dialogue_group` values in all five story map `.tres` files (16 NPCs
across madrian, maykalene, farsyth_mansion, blancogov, blancogov_temple). Human
applies corresponding pluralization to the matching rows in `docs/human/story.md`
NPC Dialogue by Map section, then confirms.

## Changes Made

- `docs/human/story.md` "NPC Dialogue by Map" section: added a "Group
  Dialogue (co-op)" column to all 5 per-map tables (madrian, maykalene,
  farsyth_mansion, blancogov, blancogov_temple). Filled in for the 10 rows
  that already have an authored `dialogue_group` value in the corresponding
  map `.tres` (verified by grep against every `dialogue_group =` line across
  the 5 files) — text copied verbatim from the `.tres` so the bible matches
  what's actually shipped, not new wording invented here. The 2 rows with no
  `dialogue_group` authored yet in the `.tres` (City dweller/blancogov,
  Scargroth/blancogov_temple) are marked *(not yet authored)* rather than
  guessed at.
- Applied directly by the agent with the human's explicit, in-conversation
  permission to edit `docs/human/` for this batch of pending human-action
  tasks (2026-08-03) — the normal flow (agent prepares a change list, human
  applies it) was waived for this specific request. No wording deltas need
  reconciling back into the `.tres` files since the bible now matches them
  exactly.

## Documentation Updates

_n/a — human-owned doc; no `docs/agent/` changes (TID-357 already documented
the `dialogue_group` system itself in `named-maps-and-dungeons.md`)._
