# TID-604: Generated Named-NPC Sprites

**Goal:** GID-143
**Type:** agent
**Status:** pending
**Depends On:** TID-603

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BID-065: quest givers and trainers look like random townsfolk.

## Research Notes

- Generator: one humanoid body with outfit/colour/prop parameters (apron + loaf, herbalist satchel, friar robe, old soldier with pike, chandler with candle, trainer, gravedigger with spade, rift warden robe, bounty master).
- `SpriteRegistry.townsperson_texture(seed)` → add `npc_texture_for(npc_id)` map; `TownspersonNPC` uses it when the id is known.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
