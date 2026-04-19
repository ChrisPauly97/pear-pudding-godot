# TID-080: Battle Sound Effects

**Goal:** GID-023
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

AudioManager has SFX pool support (GID-004) but no battle sounds are wired up. Card draw, card play, attacks, and win/loss stings are the minimum set expected by players.

## Research Notes

- `autoloads/AudioManager.gd` — `play_sfx(sound_name)` or similar method; check exact API from GID-004 implementation
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
