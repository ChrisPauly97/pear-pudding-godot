# TID-436: Acquire & Place Licensed Audio Files at assets/audio/music/*.ogg

**Goal:** GID-116
**Type:** human-action (completed by agent — see Changes Made)
**Status:** done
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

**Completed by agent session `claude/work-task-tid-436-50bw8x` on 2026-07-16.** This task
was typed `human-action` solely because the TID-435 session's outbound proxy returned 403
for asset sites. This session's proxy allows those hosts (verified: opengameart.org and
incompetech.com both return 200), so the agent performed the acquisition directly,
following the doc's instructions including on-page license verification.

All 7 slots use the **primary pick** from `docs/agent/audio-soundtrack.md`. Licenses were
re-verified from each source page's license tag at download time (2026-07-16):

| File | Track | Author | License (on-page) | Source URL |
|---|---|---|---|---|
| `grasslands.ogg` | GrassLands Theme | DST | CC0 | https://opengameart.org/content/grasslands-theme |
| `forest.ogg` | Woodland Fantasy | Matthew Pablo | CC-BY 3.0 | https://opengameart.org/content/woodland-fantasy |
| `desert.ogg` | Desert Theme | Tarush Singhal | CC0 | https://opengameart.org/content/desert-theme-0 |
| `scorched.ogg` | Dark Times | Kevin MacLeod (incompetech.com) | **CC-BY 4.0** (page confirms 4.0) | https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1100747 |
| `mountains.ogg` | Unforgiving Himalayas (Looping) | **Eric Matyas (soundimage.org)** — shortlist wrongly said Matthew Pablo | CC-BY 3.0 | https://opengameart.org/content/unforgiving-himalayas-looping |
| `dungeon.ogg` | Crystal Cave + Mysterious Ambience | cynicmusic (pixelsphere.org / The Cynic Project) | CC-BY 3.0 (chosen from CC-BY 3.0 / CC-BY-SA 3.0 / GPL 3.0 multi-license) | https://opengameart.org/content/crystal-cave-mysterious-ambience-seamless-loop |
| `battle.ogg` | Battle Theme A | cynicmusic | CC0 | https://opengameart.org/content/battle-theme-a |

**Verbatim attribution notices copied from the source pages (for TID-437's CREDITS file):**
- Woodland Fantasy: "Please read this page for attribution instructions: http://www.matthewpablo.com/services" — use `Music: "Woodland Fantasy" by Matthew Pablo — https://matthewpablo.com — CC-BY 3.0`
- Unforgiving Himalayas: `Please credit as: "UNFORGIVING HIMALAYAS" by Eric Matyas www.soundimage.org`
- Crystal Cave: `Credit pixelsphere.org / The Cynic Project. Please link to cynicmusic's website and, as a courtesy not a requirement, notify him if you use the music.`
- Dark Times (incompetech standard form): `"Dark Times" Kevin MacLeod (incompetech.com). Licensed under Creative Commons: By Attribution 4.0 License. http://creativecommons.org/licenses/by/4.0/`
- CC0 courtesy credits: DST, Tarush Singhal, cynicmusic.com / pixelsphere.org.

**Processing applied:**
- MP3 sources converted with `ffmpeg -c:a libvorbis -q:a 5` (grasslands, forest, desert, scorched, battle).
- `mountains.ogg` and `dungeon.ogg` were already Ogg Vorbis — copied as-is, renamed only.
- Loop-seam check via `silencedetect` (−45 dB, ≥1.5 s): forest had a 7.6 s silent tail
  (trimmed to 143.5 s with 1 s fade-out); scorched had 4.1 s leading / 3.5 s trailing
  silence (cut to 4.0 s→180.6 s of the source with 1 s fade-out). Both re-cut from the
  original MP3s to avoid a double lossy re-encode. All other tracks: no silence regions.
- Final durations: grasslands 164 s, forest 143 s, desert 126 s, scorched 177 s,
  mountains 140 s, dungeon 86 s, battle 96 s. Total ~22 MB.

## Documentation Updates

- `docs/agent/audio-soundtrack.md`: corrected the mountains author (Eric Matyas, not
  Matthew Pablo), pinned Dark Times to CC-BY 4.0, and added an "Acquired Files" section
  recording the final picks and processing so TID-437 can write CREDITS from it.
