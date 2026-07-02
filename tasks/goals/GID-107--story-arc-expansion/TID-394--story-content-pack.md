# TID-394: Draft Story Pack — Ch1 Enrichment, Ending, Dialogue Table, Ch2 Outline

**Goal:** GID-107
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Chapter 1 lacked an ending definition, a flag-gated dialogue table (GID-020 TID-063/TID-066 human TODOs, backlog BID-016), and any Chapter 2 direction. This task drafts the full story content pack for human approval.

## Research Notes

- Story bible: docs/human/story.md (human-owned; agent normally never edits — the user explicitly authorized writing the approved pack into it in the GID-107 approval session, 2026-07-02).
- Spec: docs/human/specification.md had resolved "Chapter 2 is out of scope"; amended with user approval.
- Chapter 1 flag spine: story_intro_complete → chapter1_left_madrian → chapter1_warned_farsyth → chapter1_received_letter → chapter1_reached_blancogov → chapter1_temple_council (see game_logic/ObjectiveTracker.gd).
- Existing systems to reuse in Ch2: town siege (GID-054, game_logic/SiegeDefs.gd), DungeonGen, boss framework (GID-021), scrolls/journal (ScrollRegistry).

## Plan

Draft: (1) Chapter 1 ending definition; (2) full before/after dialogue table for 11 NPCs across 5 maps; (3) Chapter 2 "The Road to Larik" 7-beat outline with parents-mystery spine; (4) rabbit-hunt tutorial battle design. Present at the /new-goal review gate.

## Changes Made

Drafted in-session as the GID-107 proposal document (two review iterations). User approved on 2026-07-02 and authorized writing the content directly into docs/human/story.md and amending docs/human/specification.md. Content was written by the main session (see TID-395).

## Documentation Updates

Content landed in docs/human/story.md (Chapter 1 Victory Condition, Flag-Gated Dialogue States table, Chapter 2 section, Wilderness Encounters tutorial-battle notes) and docs/human/specification.md (Chapter 2 scope amendment).
