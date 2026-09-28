# TID-580: Hit Feel — Hit-Stop & Shake in Real Time

**Goal:** GID-139
**Type:** agent
**Status:** todo
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`BattleFx` has `hit_stop` (animate_attack) and `trigger_shake`; real-time swings
and skill hits don't use them. Add short hit-stop + light shake on player hits,
bigger on crits/procs/full-combo cards; respect the Effects setting.
