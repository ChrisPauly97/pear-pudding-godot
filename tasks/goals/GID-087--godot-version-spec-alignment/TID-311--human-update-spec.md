# TID-311: Human: update specification.md engine version and narration audio scope

**Goal:** GID-087
**Type:** human-action
**Status:** done
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

`docs/human/specification.md` (human-owned) has two stale entries:

1. **Engine version** — "Engine: Godot 4.4.1" under Architecture & Technical Constraints should be updated to 4.6.

2. **Narration audio scope** — "Voice acting or music" in Out of Scope conflicts with the lore scroll narration audio added in GID-013. The clarification needed:
   - Voiced character dialogue (lip-sync, real-time conversation VO) remains out of scope
   - Lore scroll narration audio (background ambient storytelling, similar to Diablo 3 lore books) is now in scope
   - Music remains out of scope

## Research Notes

- File: `docs/human/specification.md`
- Section to update: "Architecture & Technical Constraints" → Engine line
- Section to update: "Out of Scope (for now)" → voice acting line

## Plan

N/A — human-authored content.

## Changes Made

- `docs/human/specification.md`: engine line updated to "Godot 4.6"; the Out
  of Scope bullet now reads "Voice acting (voiced character dialogue —
  lip-sync, real-time conversation VO)"; added an "Open Questions —
  Resolved" entry documenting the GID-116 music amendment and clarifying
  that lore scroll narration audio has been in scope since GID-013.
- Applied directly by the agent with the human's explicit, in-conversation
  permission to edit `docs/human/` for this batch of pending human-action
  tasks (2026-08-03) — the normal flow (agent proposes, human applies) was
  waived for this specific request.

## Documentation Updates

N/A — human-owned doc, no `docs/agent/` changes.
