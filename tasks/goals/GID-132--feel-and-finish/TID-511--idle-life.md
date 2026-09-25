# TID-511: Idle Life for World Sprites

**Goal:** GID-132
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

World NPC/enemy billboards are completely still.

## Research Notes

Billboards from `SpriteRegistry.make_billboard()` (EnemyNPC, MerchantNPC, TownspersonNPC). Prefer a per-node phase-offset bob in a shared cheap update, or Sprite3D offset animation.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
