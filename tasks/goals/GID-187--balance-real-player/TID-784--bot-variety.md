# TID-784: Bot variety (second policy)

**Goal:** GID-187
**Type:** agent
**Status:** todo
**Depends On:** TID-778

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Every number so far comes from one very consistent bot, so win rates move in cliffs and tuning can fit its quirks.
Add a second policy (e.g. "casual": slower reactions, misses some Kicks, no focus swaps; and optionally "sharp":
commands Allies, swaps focus) and require bands to hold for the default and casual bots (casual with a lower bar).

## Research Notes

- `BalanceBot.gd` policy knobs (`heal_below`, `summon`, `interrupt`, `focus`); `BalanceFight.run(cfg, policy)`.
- Missing actions today: focus changes, commanded Ally attacks (`docs/agent/balance-sim.md` → Limits).
- A reaction-delay knob (seconds before acting on a telegraph) likely matters most for heavies / interrupts.

## Plan

## Changes Made

## Documentation Updates
