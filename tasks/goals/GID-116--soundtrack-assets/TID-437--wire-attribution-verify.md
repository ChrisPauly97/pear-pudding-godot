# TID-437: Wire Attribution, Verify Integration, Update Docs, Clean Up Stale Duplicate Task

**Goal:** GID-116
**Type:** agent
**Status:** pending
**Depends On:** TID-436

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Once the 7 `.ogg` files exist at `assets/audio/music/` (TID-436), no code changes are needed for music to actually play — `AudioManager.play_music()` and its call sites in `WorldScene.gd`/`BattleScene.gd` already exist (see GID-116 goal.md for exact line references). This task is verification, attribution/licensing paperwork, and doc/task hygiene cleanup discovered during this goal's research.

## Research Notes

- **Verification:** run the standard headless editor import (see CLAUDE.md "GDScript: Always Validate Compilation") to confirm the new `.ogg` files import cleanly with no errors:
  ```bash
  godot --headless --editor --quit 2>&1 | grep -iE "Parse Error|Compile Error|Failed to load script" | grep -viE "imported/|Make sure resources"
  ```
  Empty output = clean. Also spot-check that `ResourceLoader.exists()` finds each new path (the existing `play_music()` no-op behavior means a typo'd filename fails silently, so confirm filenames match `_BIOME_MUSIC` / the hardcoded paths in `WorldScene.gd` and `BattleScene.gd` exactly).
- **Attribution:** write a `CREDITS` file (suggest `assets/audio/music/CREDITS.md`) listing, per track: filename, track title, artist, license, source URL, and verbatim attribution text where the license requires it (CC-BY). Pull this from `docs/agent/audio-soundtrack.md` (TID-435) plus whatever TID-436 recorded if the human deviated from the shortlist.
- **Docs:** update `docs/agent/audio-manager.md`:
  - Its "Asset Requirements" table currently says music files are absent/optional — update to note real assets now exist, with a pointer to `assets/audio/music/CREDITS.md` and `docs/agent/audio-soundtrack.md`.
  - No new "Integrations" rows needed — `play_music()` call sites are already documented via GID-023.
- **Stale duplicate task file cleanup (discovered during GID-116 research):** `tasks/goals/GID-023--game-feel-polish/TID-081--background-music-loop.md` is an orphaned duplicate — it shares TID-081 with the already-completed `TID-081--background-music-loop-integration.md` in the same folder, but is itself stuck at `Status: pending` with an unfilled Plan/Changes Made. The real TID-081 work is done (see `goal.md`'s task table, which lists TID-081 as done, and the `-integration` file's filled-in Changes Made). Delete the stale duplicate file. This was logged as BID-047 — move it to `tasks/archive/backlog/` and mark resolved in `tasks/index.md` as part of this task's doc updates.
- **Design note, NOT to be fixed here:** `dungeon.ogg` plays for every named map (towns and dungeons alike) — logged as BID-048, left open for a future goal to consider splitting into distinct town/dungeon tracks. Do not expand scope to fix this in TID-437.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
