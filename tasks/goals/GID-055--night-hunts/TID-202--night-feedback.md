# TID-202: Night-Hunt Feedback — Minimap, Audio, Tutorial

**Goal:** GID-055
**Type:** agent
**Status:** done
**Depends On:** TID-200, TID-201

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Player feedback on night hunts: minimap shows spectres in a distinct color, a soft ambient sting plays at nightfall (only in infinite world), and a one-time tutorial popup explains the mechanic the first time night arrives.

## Research Notes

- **Minimap spectre color:** Minimap is rendered by **scenes/world/Minimap.gd** lines 158–189. The `_on_draw()` method at line 159 calls `_draw_group()` for each entity type. Enemies are drawn at line 166 in red: `Color(0.95, 0.20, 0.20)`. To distinguish spectres, add a condition in `_draw_group()` that checks if a node has `is_nocturnal: bool == true` (a flag set by TID-200 when spawning spectres), and if so, draw in a distinct pale blue: `Color(0.55, 0.75, 1.00)` (already used for doors at line 168). Implementation: modify the loop at line 175 to check `if n.get_meta("is_nocturnal", false)` or a property/field (whichever is cleaner — verify enemy node structure in **scenes/world/entities/EnemyNPC.tscn** or **scenes/world/entities/EnemyNPC.gd** for the best pattern). If metadata, set it in TID-200 when spawning: `node.set_meta("is_nocturnal", true)`. Alternative: add an actual `is_nocturnal` property to the enemy node. Decision: metadata is simpler and doesn't require script modification; use metadata approach with fallback to property check.

- **Nightfall ambient cue:** Cite **autoloads/AudioManager.gd** lines 110–127. The API is `play_sfx(sfx_name: String)`, which looks up the name in `SFX_PATHS` dict at lines 4–16, loads the `.wav` file, and plays it via a pooled `AudioStreamPlayer`. To add a night-fall sound: (1) create or reuse an existing ambient `.wav` file (e.g., a soft wind/whisper sting ~1.5s), (2) add an entry to `SFX_PATHS` like `"nightfall_ambient": "res://assets/audio/sfx/nightfall.wav"`, (3) call `AudioManager.play_sfx("nightfall_ambient")` from **WorldScene._update_day_night()** when transitioning into night (detect crossing the threshold: `prev_time >= 0.75 and _time_of_day < 0.75` for sunset, or `prev_time < 0.25 and _time_of_day >= 0.25` for dawn — play on sunset, silence on dawn or skip). Actually, simpler: track a flag `_night_cue_played: bool`, and in `_update_day_night()` after updating `_time_of_day`, check if `is_night(_time_of_day)` and not `_night_cue_played`, then play and set flag. On dawn, reset flag. Only play in infinite world: check `_is_infinite`.

- **Alternative:** If no dedicated nightfall asset exists yet, synthesize one via procedural audio (see GID-004 audio foundation patterns from docs). For v1, assume a `.wav` file will be provided or reuse an existing ambient sound (e.g., soft wind). If missing, the call to `play_sfx()` gracefully no-ops (line 114–115 in AudioManager returns if file doesn't exist).

- **Tutorial popup:** Cite **scenes/ui/TutorialPopup.gd** and **game_logic/TutorialRegistry.gd** (part of GID-031, already implemented). Pattern: (1) emit `GameBus.tutorial_popup_requested.emit("night_hunts")`, (2) SceneManager intercepts, checks `SaveManager.get_story_flag("seen_tutorial_night_hunts")`, sets flag if not seen, (3) looks up `"night_hunts"` in `TutorialRegistry._DATA` and instantiates the popup. Implementation: in TID-200's spawn code, on first nocturnal spawn event of a night session, emit the signal. Simpler: emit in `_update_nocturnal_spawns()` when spawning the first spectre and a flag `_night_hunt_tutorial_shown: bool == false` for the session. Set flag after emitting so it only fires once per play session (or per night, depending on design — decision: once per session for simplicity). Store in `SaveManager` as `story_flags["seen_tutorial_night_hunts"]` for persistence across restarts.

- **Registry entry:** Add to **game_logic/TutorialRegistry.gd** `_DATA` dict an entry:
  ```gdscript
  "night_hunts": {
      "title": "Night Hunts",
      "body": "Spectral enemies roam the world after sunset. They drop better loot but are dangerous. Return to town before dawn, or stand and fight!"
  }
  ```
  Adjust body text as needed (max ~150 chars for readable layout at default font sizes).

- **Optional subtle vignette:** At night, apply a subtle darkened vignette around the screen edge (via post-process shader or tint overlay). Check if the day/night tint pipeline in **WorldScene._update_day_night()** already supports this. Looking at lines 986–994, the sky color and ambient lighting shift but no vignette is applied. A vignette would be a visual enhancement but not required for MVP. Implementation: add an optional `ColorRect` child to the HUD `CanvasLayer`, apply a radial gradient shader to darken edges when night, tween opacity at night/dawn transitions. Decision: defer to post-MVP stretch goal; focus on core feedback (minimap, audio, tutorial).

- **Mobile parity:** All three feedback channels are display/audio-only; no new input required. Mobile players see the spectre color on the minimap (same as desktop), hear the nightfall sound, and get the tutorial popup. No changes needed for mobile-specific code.

- **Headless tests:** For minimap coloring, extract entity enumeration into a testable helper; mock nodes with metadata and verify color selection logic. For tutorial once-only, test that the flag is set and never emits twice in a session. For audio, verify the call to `play_sfx()` with the nightfall key happens on transition. Tests don't need to verify actual sound playback, only that the API is called correctly.

## Plan

Minimap: replace single `_draw_group()` call for enemies with a dedicated `_draw_enemy_nodes()` method that checks `is_nocturnal` metadata and selects pale blue for spectres. Audio: add `"nightfall_ambient"` key to `AudioManager.SFX_PATHS`; play it from `WorldScene._update_day_night()` on entering night. Tutorial: add `"night_hunts"` entry to `TutorialRegistry._DATA`; emit `tutorial_popup_requested` on first spectre spawn per session.

## Changes Made

- **`scenes/world/Minimap.gd`**: Replaced `_draw_group(canvas, _enemy_nodes, ...)` call in `_on_draw()` with a new `_draw_enemy_nodes(canvas, origin)` method that iterates `_enemy_nodes`, skips `"roaming_boss"`, checks `n.get_meta("is_nocturnal", false)`, and draws spectres in `Color(0.55, 0.75, 1.00)` vs normal red `Color(0.95, 0.20, 0.20)`.
- **`autoloads/AudioManager.gd`**: Added `"nightfall_ambient": "res://assets/audio/sfx/nightfall.wav"` to `SFX_PATHS`. Gracefully no-ops if file doesn't exist.
- **`game_logic/TutorialRegistry.gd`**: Added `"night_hunts"` entry with title "Night Hunts" and body explaining spectral enemies and loot boost.
- **`tests/unit/test_night_hunts.gd`**: 26 tests covering `_is_night()` math, spectral enemy data (tier, coin reward, tracking, deck not empty, drop boost flag), drop tier capping math, and `TutorialRegistry` entry. All pass headless.
- **`tests/runner.gd`**: Added `test_night_hunts.gd` to SUITES array.

## Documentation Updates

Updated `docs/agent/night-hunts.md`.
