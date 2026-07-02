# TID-063: Human — Author Flag-Gated NPC Dialogue

**Goal:** GID-020
**Type:** human-action
**Status:** done — satisfied by GID-107/TID-394+395 (user-approved story pack written into story.md, 2026-07-02)
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

TownspersonNPC currently returns one static dialogue string regardless of story state. To support flag-gated dialogue, the human must specify what each NPC says before and after each relevant story flag. This data lives in `docs/human/story.md` under "Flag-Gated Dialogue States".

## What the Human Needs to Do

Open `docs/human/story.md` and fill in the **Flag-Gated Dialogue States** table (added during goal creation). For each NPC that should have different dialogue at different story points:

1. Copy the table row template
2. Fill in: NPC name, map, flag_key, before-flag text, after-flag text
3. The flag_key must match an existing or new entry in `SaveManager.story_flags`

**Existing story flags (from GID-001):**
- `chapter1_met_maiteln` — set when Saimtar speaks to Maiteln in Madrian
- `chapter1_visited_farsyth` — set after Lord Farsyth scene
- `chapter1_received_letter` — set after Isfig encounter
- `chapter1_entered_temple` — set on entering blancogov_temple

**Suggested NPCs to gate (at minimum):**
- Blancogov gate guard: suspicious before `chapter1_received_letter`, welcoming after
- Maykalene townsperson: generic before `chapter1_met_maiteln`, mentions the wizard after
- Any NPC in blancogov_temple: different line after `chapter1_entered_temple`

## When Done

Notify the agent. TID-065 can then proceed to wire the logic.

## Plan

_N/A — human action._

## Changes Made

_N/A — human action._

## Documentation Updates

_N/A — human action._
