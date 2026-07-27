# TID-437: Wire Attribution, Verify Integration, Update Docs, Clean Up Stale Duplicate Task

**Goal:** GID-116
**Type:** agent
**Status:** done
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

1. Write the Music section of `CREDITS.md` from TID-436's verified licence table.
2. Add a Music Channel section to `docs/agent/audio-manager.md`.
3. Verify headless import is clean with the audio present.
4. Delete the stale duplicate `TID-081--background-music-loop.md` (BID-047).
5. Correct the now-stale "no soundtrack" weakness in `docs/agent/game-appeal.md`.

## Changes Made

### `CREDITS.md` — Music section (the licence obligation)

Removed the "music credits will be added by GID-116/TID-437" placeholder and
wrote the real section from TID-436's on-page-verified table.

**Four of the seven tracks are CC-BY, so their attribution is a licence
condition, not a courtesy** — this was the actual outstanding obligation, and
until now the repo shipped the audio with no attribution at all:

| File | Track | Author | Licence |
|---|---|---|---|
| `forest.ogg` | Woodland Fantasy | Matthew Pablo | CC BY 3.0 |
| `scorched.ogg` | Dark Times | Kevin MacLeod | CC BY 4.0 |
| `mountains.ogg` | Unforgiving Himalayas | Eric Matyas | CC BY 3.0 |
| `dungeon.ogg` | Crystal Cave | cynicmusic | CC BY 3.0 |

Each uses the verbatim notice the source page requires (Kevin MacLeod's
standard incompetech form, Eric Matyas's "please credit as" wording, etc.),
captured by TID-436. The three CC0 tracks (DST, Tarush Singhal, cynicmusic) are
listed as courtesy credit and marked as not required, so a future editor can
tell which lines are legally load-bearing. Added an explicit note that the
CC-BY block must survive into any distributed build and that a track should be
removed before its attribution is.

Also added a per-slot index table mapping each file to its track, author and
licence.

### `docs/agent/audio-manager.md`

The doc covered the SFX pool and narration channel but had **no music section
at all** — `play_music` / `stop_music` / `set/get_music_volume` and the
`_music_player` were entirely undocumented. Added a Music Channel section
covering the API, the auto-loop via the `finished` signal, the
idempotent-on-same-path behaviour, the 7-slot table with what selects each, and
a pointer to `CREDITS.md` as the authoritative attribution record. Added a
Music row to Asset Requirements.

### `docs/agent/game-appeal.md`

Weakness #5 ("all 7 tracks are missing files ... first impressions currently
carry no soundtrack") was stale — the files landed in TID-436. Marked resolved
and replaced with the accurate residual gap: every hand-authored town shares one
peaceful track, so per-location variety (e.g. a town under siege) is still worth
having.

### BID-047 (stale duplicate task file)

`tasks/goals/GID-023--game-feel-polish/TID-081--background-music-loop.md`
deleted; BID-047 archived and its index row moved to Resolved Backlog. Done
ahead of this task as part of GID-124's backlog reconciliation.

## Verification

- `godot --headless --editor --quit` — clean, zero parse/compile errors, and
  **zero `invalid UID` warnings**; all 7 `.ogg` files have their `.import`
  sidecars generated.
- Full suite green at the time of this change.
- Audited every tracked `.gdshader`/`.tres`/`.material`/`.theme`/`.gdextension`
  for a `.uid` sidecar: 0 missing. (Audio files correctly need none.)

## Documentation Updates

- `CREDITS.md` — new Music section (required + courtesy attribution, per-slot index).
- `docs/agent/audio-manager.md` — new Music Channel section; Asset Requirements row.
- `docs/agent/game-appeal.md` — weakness #5 marked resolved, residual gap stated.
