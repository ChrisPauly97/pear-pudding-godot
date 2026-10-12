# BID-105: Deprecating turn-based combat leaves co-op without a real-time mode

**Category:** design
**Discovered During:** GID-187 (user decision 2026-10-11: "we'll deprecate turn based combat")

## Description

`BattleRealtime.eligible()` only runs real time for fresh, solo, non-puzzle, non-scripted fights. Co-op PvE
(`BattleNet` joint battles), team battles, puzzles, scripted battles, resumed saves and PvP all run turn-based.
Deprecating turn-based needs real-time paths for those (or cutting them), plus removing the `battle_mode` setting.
The spec (human-owned) may also mention turn-based play.

## Suggested Resolution

A goal: real-time co-op (networked `RealtimeCombat` with host authority), real-time puzzles / scripted tutorials (or
retire them), resumed fights restart in real time, then remove the turn-based UI and the setting. PvP is out of
balance scope (user) but still needs a decision.
