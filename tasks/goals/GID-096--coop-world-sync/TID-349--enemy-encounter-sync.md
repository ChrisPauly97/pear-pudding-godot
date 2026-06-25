# TID-349: Authoritative enemy & encounter sync

**Goal:** GID-096
**Type:** agent
**Status:** pending
**Depends On:** GID-094

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The single biggest sync task: make enemies authority-owned and visible/shared to
all players, with synced positions and defeat state. Enemies are currently
spawned and simulated per-instance with no networking.

## Research Notes

_To be expanded when GID-094 lands._

- **Survey first:** how WorldScene spawns/owns enemies today (the `Entities` node,
  `_enemy_nodes[id]` registry referenced in GID-090 research, enemy AI in
  `scenes/world/` / `game_logic/`). Identify the wander/track/engage AI
  (`docs/agent/enemies-and-npcs.md`) and where defeat is recorded
  (`SaveManager.defeated_enemies`).
- **Model:** authority owns enemy spawns + AI; broadcast enemy state (id, type,
  pos, facing, hp/alive) at a low Hz with interpolation, reusing the AvatarSync
  interp helper / a sibling `EnemySync` pure helper. Clients render display-only
  enemy nodes (like RemotePlayer) — no local AI when in a session.
- **Encounter rule (decide + document):** what happens when player A starts a
  battle with a shared enemy? Options: enemy becomes "engaged/locked" for others;
  or each player fights their own instance. Pick the simplest coherent rule and
  write it in the goal/docs. Defeat marks the enemy down for all and records into
  the session file (GID-095) — not `save.json`.
- **Guarding:** single-player path (no session) keeps local AI + local
  `defeated_enemies`. All net code behind `NetworkManager.is_active()` /
  `_coop_active`.
- This task may be split if it grows (separate spawn-ownership vs AI-sync vs
  battle-trigger). Flag during Plan.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
