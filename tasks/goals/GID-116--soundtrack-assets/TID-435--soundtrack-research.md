# TID-435: Research & Curate CC0/CC-BY Soundtrack Shortlist Per Music Slot

**Goal:** GID-116
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`AudioManager.play_music()` and its call sites in `WorldScene.gd`/`BattleScene.gd` already expect 7 specific files that don't exist yet (see GID-116 goal.md for exact line numbers/paths). This task is pure research: produce a curated, license-verified shortlist a human can act on in TID-436 without re-searching. No code or asset files are touched in this task — output is a single new doc.

## Research Notes

### Exact slots to fill (path → in-game context)

| File | Used when | Mood target |
|---|---|---|
| `assets/audio/music/grasslands.ogg` | Infinite-world biome 0 | Pastoral, warm, adventurous (Zelda-overworld energy) |
| `assets/audio/music/forest.ogg` | Infinite-world biome 1 | Mysterious but gentle, woodwinds/strings |
| `assets/audio/music/desert.ogg` | Infinite-world biome 2 | Sparse, arid, subtle percussion, wide open |
| `assets/audio/music/scorched.ogg` | Infinite-world biome 3 | Tense, low drones, embers-and-ash mood (not full combat-intensity) |
| `assets/audio/music/mountains.ogg` | Infinite-world biome 4 | Grand, echoing, brass/horns, sense of scale |
| `assets/audio/music/dungeon.ogg` | Every non-infinite (named) map: towns (madrian, maykalene) AND dungeons — see caveat below | Calm-but-mysterious; must not read as threatening since it also plays in peaceful towns |
| `assets/audio/music/battle.ogg` | `BattleScene._ready()`, every card battle | Energetic, rhythmic, Hearthstone-tempo tension |

**Caveat on `dungeon.ogg`:** `WorldScene.gd` plays this single track for *all* named maps, not just dungeons — including the peaceful town of madrian. Pick something that reads as "adventurous fantasy interior/settlement," not overtly dungeon-crawl-scary. (A follow-up backlog item, BID-048, tracks splitting this into separate town/dungeon tracks later — out of scope here.)

### Creative direction (from docs/human/specification.md and docs/human/story.md)

- Aesthetic: classic pixel-art RPG scaled into 3D isometric view.
- World exploration feel: early Zelda games.
- TCG battle tone: Hearthstone (mana curve, board zones) — battle music should match that upbeat-tactical energy, not orchestral-epic bombast.
- Story tone: The Hobbit / Redwall — grounded, warm, adventurous fantasy for a young protagonist. Avoid grimdark/horror music even for Scorched/dungeon slots — tension yes, horror no.
- Format constraint: must be `.ogg` (Vorbis) — Godot-native, already the format every call site expects. If a source track is `.mp3`/`.wav`, note that conversion (e.g. `ffmpeg -i in.mp3 -c:a libvorbis -q:a 5 out.ogg`) will be needed in TID-436/432.
- Looping: all 7 are looped via `AudioManager`'s `finished` signal reconnect — a seamless loop point matters more than track length. Prefer tracks explicitly advertised as "loopable"/seamless, or note where a loop point needs trimming.

### License constraints

- **Godot/Android export note:** license files ship in the repo, not the APK — no runtime attribution UI is required by this goal, but CC-BY tracks still need attribution recorded in-repo (satisfied by TID-437's CREDITS file).
- Prefer **CC0 / public domain** tracks (zero attribution burden, safest for an Android store listing). CC-BY (and CC-BY-SA if compatible with redistribution) is acceptable as a fallback if a CC0 track isn't a strong fit — just make sure the exact attribution text is captured verbatim for TID-437.
- Do **not** pick anything under a non-commercial-only license (e.g. CC-BY-NC) — this project has no stated non-commercial restriction and shouldn't inherit one from an asset.
- Do **not** pick anything requiring a paid license, watermarked previews, or "royalty-free but not redistributable" stock-music-site tracks (those typically forbid embedding the raw file in a redistributable game repo).

### Good source starting points (found via WebSearch this session — verify current licensing on the actual page before finalizing, sites update their catalogs)

- **OpenGameArt.org** — search terms like "CC0 fantasy music", "CC0 RPG music", "loopable dungeon ambience". Filter to CC0 explicitly; the site also hosts CC-BY/CC-BY-SA content mixed in, so check each track's individual license tag.
- **incompetech.com (Kevin MacLeod)** — large catalog, licensed CC-BY 4.0, explicit per-track attribution text generator on the site.
- **Free Music Archive (freemusicarchive.org)** — filter by CC0/CC-BY, instrumental/fantasy tags.
- **itch.io** — many CC0 game-music asset packs (search "CC0 music pack" on itch.io).
- Godot Asset Library is not a music source — skip.

### Output format

Create `docs/agent/audio-soundtrack.md` with this structure:

```markdown
# Soundtrack Assets

## Key Features
...

## Shortlist Per Slot

### grasslands.ogg
- **Primary pick:** <track name> — <artist> — <license> — <direct URL>
  - Attribution text (verbatim, if CC-BY): "..."
  - Format/conversion needed: yes/no
- **Backup pick:** ...

... (repeat for forest, desert, scorched, mountains, dungeon, battle)

## Acquisition Instructions (for TID-436)
Step-by-step: where to download, what filename/path to save as, any conversion command.

## Asset Requirements
...
```

Add a row for this new file to the docs/agent index table in `CLAUDE.md` (project root), following the existing table format — this is expected upkeep per CLAUDE.md's own instructions ("When adding a new major feature or system, create a corresponding .md file in docs/agent/ and add a row to this table").

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
