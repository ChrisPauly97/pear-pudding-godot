# TID-436: Acquire & Place Licensed Audio Files at assets/audio/music/*.ogg

**Goal:** GID-116
**Type:** human-action
**Status:** pending
**Depends On:** TID-435

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

An agent session cannot download binary files from general internet asset sites in this sandbox — outbound `curl`/`Bash` to external hosts (OpenGameArt, incompetech, etc.) is blocked by the environment's proxy (confirmed 403 during TID-435/goal research; `WebSearch`/`WebFetch` work because they're routed through Anthropic's own infrastructure, but they return text/markdown, not binary file contents). A human needs to do the actual download.

## Research Notes

- Shortlist and direct URLs live in `docs/agent/audio-soundtrack.md` (produced by TID-435) — follow its "Acquisition Instructions" section.
- Target paths (create `assets/audio/music/` if it doesn't exist):
  - `assets/audio/music/grasslands.ogg`
  - `assets/audio/music/forest.ogg`
  - `assets/audio/music/desert.ogg`
  - `assets/audio/music/scorched.ogg`
  - `assets/audio/music/mountains.ogg`
  - `assets/audio/music/dungeon.ogg`
  - `assets/audio/music/battle.ogg`
- Files must be `.ogg` (Vorbis). If the chosen source track is `.mp3`/`.wav`, convert first, e.g.:
  ```
  ffmpeg -i downloaded_track.mp3 -c:a libvorbis -q:a 5 assets/audio/music/grasslands.ogg
  ```
- No `.uid` sidecar is needed for audio files (unlike `.tres`/`.gdshader`/`.material` — see CLAUDE.md "Godot Resource .uid Files"). Godot generates a `.import` file for audio automatically the next time the editor scans the project; that's handled in TID-437.
- Keep a note of the exact source URL and license for each file you pick — TID-437 needs this to write the CREDITS/attribution file. If you deviate from TID-435's shortlist (pick something else you like better), just make sure it's CC0 or CC-BY (with attribution text available) and not CC-BY-NC or a non-redistributable stock license.

## Plan

1. Open `docs/agent/audio-soundtrack.md`, review the shortlist per slot.
2. Download (or otherwise obtain) the chosen track for each of the 7 slots.
3. Convert to `.ogg` if needed.
4. Place each file at its exact target path under `assets/audio/music/`.
5. Record the final choice (if different from the shortlisted primary pick) — a short note in this task's Changes Made, or directly in `docs/agent/audio-soundtrack.md`, is enough for TID-437 to pick up.

## Changes Made

_Filled in by the human once files are placed._
