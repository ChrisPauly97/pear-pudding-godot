# TID-578: Essence Surge Free-Cast Procs

**Goal:** GID-139
**Type:** agent
**Status:** done
**Depends On:** TID-576

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Plan

`on_player_hit` rolls `proc_chance` (skills) / `auto_proc_chance` (swings) and
banks `PlayerState.next_card_free` (effective_cost 0, cleared by play_card), so
affordability styling needs no special case. Auto-hit procs arrive as a
`proc` event; skill procs via `out.proc`. Hand pulses gold; free cards cast instantly.

## Changes Made

See TID-576 (same commit).
