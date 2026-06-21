# TID-307: BattleScene keyword integration tests + resolve hero freeze/stun

**Goal:** GID-085
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

Session: none
Acquired: —
Expires: —

## Context

BattleScene-level tests are absent per BID-012. Ward/Surge/Shroud keyword interactions and spell resolution are only covered by pure-logic unit tests, not end-to-end.

Additionally, hero `freeze`/`stun` tick handling (BattleScene.gd:1665-1678, PlayerState.gd:65) is unreachable — no effect ever applies these to a hero. This task must make a decision: either wire hero freeze/stun to a real card effect or delete the dead paths.

## Plan

## Changes Made

## Documentation Updates
