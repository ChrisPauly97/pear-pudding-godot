# GID-004: Audio Foundation

## Objective

Add an `AudioManager` autoload and wire sound effects for battles and world exploration, giving the game its first layer of audio feedback.

## Context

There is currently zero audio code in the project. Even minimal SFX (card play, attack, chest open, footsteps) dramatically improves game feel and makes the game feel finished rather than prototype-quality. This goal builds a decoupled audio system that other scenes can trigger via `GameBus` signals or direct calls, without coupling scenes to specific audio files.

Godot 4 constraint: no geometry shaders, but `AudioStreamPlayer` and `AudioStreamPlayer3D` are fully supported.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-009 | Create `AudioManager` autoload with SFX playback API | agent | done | — |
| TID-010 | Wire battle sound effects | agent | done | TID-009 |
| TID-011 | Wire world exploration sound effects | agent | pending | TID-009 |

## Acceptance Criteria

- [ ] `AudioManager` autoload exists, registered in `project.godot`
- [ ] `AudioManager.play_sfx(name)` plays a named sound without error (graceful no-op if file missing)
- [ ] Battle SFX fire on: card played, attack landed, battle won, battle lost
- [ ] World SFX fire on: enemy engaged, chest opened, door entered
- [ ] Footstep SFX fires while the player is moving (throttled to avoid spam)
- [ ] All SFX use placeholder `.wav` files or generate a simple tone so the hooks are testable without real audio assets
- [ ] No audio file is hard-coded in a scene script — all calls go through `AudioManager`
