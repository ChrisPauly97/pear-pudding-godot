# TID-442: Elevator Pitch & Positioning Statement for specification.md

**Goal:** GID-117
**Type:** human-action
**Status:** done
**Depends On:** TID-439

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`docs/human/specification.md` is human-owned — the agent never edits it. Yet it is the
natural home for the one-sentence answer to "why would people play this?": every goal and
store-page draft downstream should be able to cite it. The agent drafts; the human reviews,
edits, and pastes.

## Research Notes

**Agent's part (do first, present to user):**
Draft, from `docs/agent/game-appeal.md` (TID-439):
1. A one-sentence elevator pitch. Working draft to refine:
   *"An open-world isometric RPG where every fight is a card battle, every enemy can be
   captured into your deck, and your deck changes how you explore the world — solo or with
   three friends."*
2. A short positioning statement (audience / genre neighbors / key differentiators), ~5
   lines, using the classic "For [audience] who [need], X is a [category] that [benefit];
   unlike [alternatives], it [differentiator]" frame.
3. A suggested placement: new "Positioning" section directly under "Overview" in
   `docs/human/specification.md`.

**Human's part:** review/edit the draft, paste it into `docs/human/specification.md`,
confirm done. Agent then marks this task done and updates goal/index status.

**Notes:**
- Keep pitch honest against shipped reality — cite only mechanics that exist (soulbinding
  GID-061, cantrips GID-065, resonance GID-059, 4-player co-op GID-090+).
- The pitch should also be usable later for an Android store listing.

## Plan

Draft presented to the user in-session (2026-07-13). The user replied "just insert that
pls, i give you permission" — explicit, one-off permission for the agent to edit the
human-owned spec on the user's behalf.

## Changes Made

- Inserted a `## Positioning` section (elevator pitch + positioning statement, marked as
  drafted by GID-117/TID-442 and inserted with explicit user permission) directly under
  `## Overview` in `docs/human/specification.md`. This does not change the standing rule:
  `docs/human/` remains human-owned and the agent edited it only under this task's
  explicit grant.

## Documentation Updates

- None beyond the spec insertion; the analysis source lives in `docs/agent/game-appeal.md`.
