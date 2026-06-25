# TID-350: Chest / loot / world-object state sync + persist into session file

**Goal:** GID-096
**Type:** agent
**Status:** pending
**Depends On:** GID-095, TID-349

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Sync the state of lootable/interactable world objects (chests, dig spots, etc.) so
opening one reflects for all players, and persist that state into the GID-095
session file so it survives reconnect.

## Research Notes

_To be expanded when TID-349 + GID-095 land._

- **Survey:** chest open state (`SaveManager.opened_chests`), dig spots
  (`docs/agent/treasure-maps.md`), and other interactables spawned in WorldScene's
  `Entities`. Determine which are per-player vs shared. Chests/loot are shared
  world state; loot *rewards* go to the per-player character (GID-095) of whoever
  opens it (decide + document: first-opener-takes, or each player loots once).
- **Model:** authority owns object state; a small `WorldObjectSync` (pure helper
  for encode/decode) + reliable RPC for state changes (open/close is discrete, not
  continuous — reliable, not interpolated). Clients reflect the authority's state.
- **Persistence:** opened/looted state writes into the `SessionState` world-progress
  block (GID-095 / TID-345), not `save.json`. Resume on reconnect.
- Reuse the GID-091 host-authoritative intent → apply → broadcast pattern.
- Guard by `is_active()`; single-player unchanged.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
