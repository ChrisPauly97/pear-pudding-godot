# TID-547: Real-Time Combat — Full Mode

**Goal:** GID-135
**Type:** agent
**Status:** pending
**Depends On:** TID-546

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Take the prototype to the default combat mode after user playtest: fill the known gaps and tune timings.

## Research Notes

- Gaps listed in `docs/agent/combat-model.md` → Known prototype gaps: periodic pulse for status effects /
  per-turn passives / weather / gambits; per-unit swing bars and a real cast bar (BattleFx); mid-battle save of
  timers (`to_dict`); enemy ability cards (with TID-541); tutorials (`BattleTutorials.gd`, TutorialRegistry) rewritten
  for real time; make real time the default for solo PvE; decide PvP/co-op (host-authoritative tick over
  `BattleNet` is feasible later).
- Replace `BattlePacing` turn budgets with real-time budgets (GCD, cast time, swing interval) and keep the guard test.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
