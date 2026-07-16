# GID-116: Open-Source Soundtrack Assets

## Objective

Find and integrate open-source, license-clean background music that fits the game's fantasy/pixel-isometric creative direction, filling the music hooks `AudioManager` already exposes.

## Context

The spec (`docs/human/specification.md`, Out of Scope) currently lists "Voice acting or music." The user has explicitly requested soundtrack assets to liven up the game, approving this as a scope change (2026-07-08). GID-114 (Game Feel — Audio, Impact & Micro-Interaction Juice, in progress) deliberately routed around music and only tackles procedural SFX/ambience, per that note: "Music remains out of scope per spec." This goal is the one that actually brings music in scope.

Critically, **the playback plumbing already exists and is unused**:

- `autoloads/AudioManager.gd` has `play_music(path)`, `stop_music()`, `set_music_volume()`/`get_music_volume()` — dedicated `_music_player: AudioStreamPlayer`, same-track guard, graceful no-op via `ResourceLoader.exists()` if the file is missing, auto-loop via the `finished` signal.
- `scenes/world/WorldScene.gd`:
  - `_BIOME_MUSIC` const array (line ~365) maps biome id → `res://assets/audio/music/{grasslands,forest,desert,scorched,mountains}.ogg`.
  - Line ~693 and ~5436: for any non-infinite (named) map — this includes **towns** (madrian, maykalene) as well as dungeons — calls `AudioManager.play_music("res://assets/audio/music/dungeon.ogg")`.
  - Line ~3486 and ~5429: on biome change while in the infinite world, calls `AudioManager.play_music(_BIOME_MUSIC[biome_id])`.
- `scenes/battle/BattleScene.gd` line ~466: `AudioManager.play_music("res://assets/audio/music/battle.ogg")` at end of `_ready()`.

So the **only missing piece is 7 `.ogg` files** at `assets/audio/music/`: `grasslands.ogg`, `forest.ogg`, `desert.ogg`, `scorched.ogg`, `mountains.ogg`, `dungeon.ogg`, `battle.ogg`. No code changes are needed to make music play — this goal is asset sourcing, licensing, and attribution.

**Sandbox network constraint discovered during research:** `WebSearch`/`WebFetch` work in this environment (routed through Anthropic's own infra), but raw `curl`/`Bash` to external asset sites (OpenGameArt, incompetech, etc.) is blocked by the outbound proxy (403). This means an agent session can research and produce a curated shortlist with direct links, but **cannot itself download the binary `.ogg` files into the repo** — a human must fetch the chosen files.

Creative direction to match (from `docs/human/specification.md` and `docs/human/story.md`): classic RPG pixel art scaled into isometric 3D; Zelda-like exploration feel; Hearthstone-like TCG battle tone; story tone modeled on The Hobbit / Redwall — grounded, warm, adventurous fantasy, not grimdark. Five biomes (Grasslands, Forest, Desert, Scorched, Mountains) each need a distinct tint reflected in music mood; battle needs tension/energy; dungeon/town needs a calmer, mysterious-but-safe bed (see BID-048 below for the town/dungeon sharing caveat).

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-435 | Research & curate CC0/CC-BY soundtrack shortlist per music slot | agent | done | — |
| TID-436 | Acquire & place licensed audio files at assets/audio/music/*.ogg | human-action | done (agent-completed; proxy allowed downloads this session) | TID-435 |
| TID-437 | Wire attribution, verify integration, update docs, clean up stale duplicate task | agent | pending | TID-436 |
| TID-438 | Amend specification.md Out-of-Scope bullet to drop "music" | human-action | pending | — |

## Acceptance Criteria

- [ ] `docs/agent/audio-soundtrack.md` exists with a curated shortlist (primary + backup) per slot: grasslands, forest, desert, scorched, mountains, dungeon, battle — each with direct source URL, license, and required attribution text
- [x] All 7 `.ogg` files exist at `assets/audio/music/` and are correctly licensed for use (CC0 preferred; CC-BY acceptable with attribution) — TID-436, licenses re-verified on-page at download time
- [ ] A `CREDITS`/attribution file documents author, license, and source URL for every included track, satisfying any CC-BY attribution requirements
- [ ] Headless editor import is clean after adding the files (no import errors)
- [ ] `docs/agent/audio-manager.md` updated to reflect real music assets and where credits live
- [ ] Stale duplicate task file `tasks/goals/GID-023--game-feel-polish/TID-081--background-music-loop.md` removed
- [ ] `docs/human/specification.md` Out-of-Scope bullet updated (human-applied) to drop "music" while keeping "voice acting" out of scope
