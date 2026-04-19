# TID-094: Keyword Game Logic — Ward, Surge, Shroud

**Goal:** GID-025
**Type:** agent
**Status:** pending
**Depends On:** TID-093

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With keywords stored on CardInstance (TID-093), this task implements the three rules in the battle loop.

## Research Notes

**Ward**
- Applies when any entity chooses an attack target among friendly minions
- In `scenes/battle/BattleScene.gd`, find attack target selection for both player and BasicAI
- Rule: if any friendly minion on the target's side has `keywords.has("ward")`, the attacker MUST target one of the Ward minions; non-Ward minions cannot be targeted while a Ward minion is alive
- Multiple Ward minions: attacker can choose any of them
- Hero can still be attacked directly only if NO Ward minion is alive on that side
- BasicAI attack selection needs the same Ward check — it currently picks targets freely; add a filter that restricts valid targets to Ward minions when any exist

**Surge**
- Applies at the moment a minion is placed on the board
- In `BattleScene.gd`, find where `summoning_sick` is set to `true` on placement
- Rule: if the placed CardInstance has `keywords.has("surge")`, set `summoning_sick = false` instead
- No other changes needed — the existing attack eligibility check already uses `summoning_sick`

**Shroud**
- Applies when a minion with `shroud_active == true` takes damage
- In the damage-application function (wherever minion health is reduced), add a check BEFORE applying damage:
  - If `card_instance.shroud_active == true`: set `shroud_active = false`; absorb all damage (health unchanged); emit a signal or call the UI to remove the Shroud badge
  - If `shroud_active == false`: apply damage normally
- Shroud absorbs the entire first hit regardless of damage amount
- Shroud does NOT protect the hero — only minions

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
