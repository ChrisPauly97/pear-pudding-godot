# TID-438: Amend specification.md Out-of-Scope Bullet to Drop "Music"

**Goal:** GID-116
**Type:** human-action
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`docs/human/specification.md` is human-owned; the agent never edits it. The user approved bringing music into scope on 2026-07-08 when this goal was created (see goal.md Context). The spec's "Out of Scope (for now)" section still says:

```
- Voice acting or music
```

This should be split so only voice acting remains out of scope, following the same pattern as the Chapter 2 amendment in GID-108 (see the "Open Questions — Resolved" section of specification.md for that precedent's format).

## Research Notes

Suggested edit — replace the line:

```
- Voice acting or music
```

with:

```
- Voice acting
```

And optionally add a line to "Open Questions — Resolved" (or wherever you'd like it noted) mirroring the GID-108 Chapter 2 precedent, e.g.:

```
- **Music:** In scope as of GID-116 (2026-07-08, user-approved). Background music
  sourced from open-source/CC-licensed tracks; see `docs/agent/audio-soundtrack.md`
  and `assets/audio/music/CREDITS.md` for licensing.
```

This task is marked done once you've applied whichever wording you prefer to `docs/human/specification.md`.

## Plan

_Human applies the edit directly; no agent Plan/Build phase._

## Changes Made

- `docs/human/specification.md`: dropped "music" from the Out of Scope
  bullet (now just "Voice acting"); added the GID-116 amendment note to
  "Open Questions — Resolved" per the GID-108 Chapter 2 precedent format
  (combined with TID-311's edit to the same file/bullet in one pass, since
  both tasks converged on identical text).
- Applied directly by the agent with the human's explicit, in-conversation
  permission to edit `docs/human/` for this batch of pending human-action
  tasks (2026-08-03).
