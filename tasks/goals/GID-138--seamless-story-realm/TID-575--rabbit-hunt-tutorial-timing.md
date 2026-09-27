# TID-575: Rabbit Hunt Tutorial — Sickness Line on Play, End Turn Prompt

**Goal:** GID-138 (playtest follow-up)
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User playtest: the rabbit-hunt tutorial says the ghost can't attack the turn it is
summoned, but it only showed at the start of turn 2 (when the ghost *can* attack), and
"Now attack!" came on turn 3. They also wanted a first-time prompt to press End Turn.

## Research Notes

- `ScriptedBattleData.tutorial_steps` were only keyed by player turn number
  (`BattleTutorials._maybe_show_scripted_tutorial_step`, called at turn start).
- Scripted battles are always turn-based (`BattleRealtime.eligible` excludes them), so
  an End Turn prompt is always valid there.

## Plan

Add event-keyed steps (`"played:<text>"`, shown right after the player's first minion
lands); re-key rabbit_hunt: turn 1 "drag it to a slot" → on play "can't strike yet …
press End Turn" → turn 2 "Now attack!".

## Changes Made

- `ScriptedBattleData`: `TUTORIAL_EVENT_KEYS`, `is_valid_step()`; `validate()` uses it.
- `BattleTutorials`: `show_scripted_event_step(key)`; both paths share `_show_scripted_step`
  (dedupe keyed by string).
- `BattleTargeting._do_play_card_at_slot`: fires the `"played"` step for the local player
  in scripted battles.
- `data/scripted_battles/rabbit_hunt.tres`: steps re-keyed as above.
- Tests in `test_scripted_battle.gd`.

## Documentation Updates

- `docs/agent/battle-system.md` "Scripted Story Battles": event-keyed tutorial steps.
