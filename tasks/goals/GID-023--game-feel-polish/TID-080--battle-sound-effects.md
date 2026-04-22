# TID-080: Battle Sound Effects

**Goal:** GID-023
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

AudioManager has SFX pool support (GID-004) but no battle sounds are wired up. Card draw, card play, attacks, and win/loss stings are the minimum set expected by players.

## Research Notes

- `autoloads/AudioManager.gd` — `play_sfx(sound_name)` looks up `SFX_PATHS` dict, loads the wav, plays via pooled AudioStreamPlayer; graceful no-op if file absent.
- `scenes/battle/BattleScene.gd` — call AudioManager at the appropriate moments
- Sound events to wire (graceful no-op if audio file absent — AudioManager already handles this per GID-004):
  - `card_draw` — when player draws a card at turn start
  - `card_play` — when player drops a card to play it
  - `minion_attack` — when a minion attacks another minion or hero
  - `spell_resolve` — when a spell effect fires
  - `battle_win` — when player hero HP > 0 and enemy hero reaches 0
  - `battle_lose` — when player hero reaches 0 HP
- Audio file paths (create placeholder paths; actual files are human-provided assets):
  - `assets/audio/sfx/card_draw.ogg`
  - `assets/audio/sfx/card_play.ogg`
  - `assets/audio/sfx/minion_attack.ogg`
  - `assets/audio/sfx/spell_resolve.ogg`
  - `assets/audio/sfx/battle_win.ogg`
  - `assets/audio/sfx/battle_lose.ogg`
- The graceful no-op pattern (check AudioManager source from GID-004): if the file doesn't exist, AudioManager should log a warning and return without error

## Plan

Audit what was already wired vs what's missing:
- Already wired: `card_play` (line ~244+), `attack` for minion attacks (lines ~594, 629, 696), `battle_win`, `battle_lose`.
- Missing: `card_draw` and `spell_resolve`.

`GameBus.turn_ended(player_idx)` is emitted at the START of a player's turn (after draw). `player_idx == 0` = player's turn starting → player drew → play `card_draw`.
`spell_resolve` plays at the top of `_resolve_spell_effect` so it fires for all spell types including AI-played spells.

## Changes Made

- `autoloads/AudioManager.gd`:
  - Added `"card_draw": "res://assets/audio/sfx/card_draw.wav"` to SFX_PATHS.
  - Added `"spell_resolve": "res://assets/audio/sfx/spell_resolve.wav"` to SFX_PATHS.
- `scenes/battle/BattleScene.gd`:
  - `_on_turn_ended(player_idx == 0)`: play `card_draw` after game-over check, before auto-spell flush.
  - `_resolve_spell_effect`: play `spell_resolve` at the top of the function (fires for player and AI spells, including auto-resolved spells).

## Documentation Updates

- Updated `docs/agent/battle-system.md` to document full SFX coverage.
