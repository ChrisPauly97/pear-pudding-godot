# TID-077: Floating Damage and Heal Numbers

**Goal:** GID-023
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Attacks and spells currently produce no visual number feedback. Floating numbers are a baseline expectation in TCG games — they confirm what happened and how much.

## Research Notes

- `scenes/battle/BattleScene.gd` — find where damage is applied to minions and heroes; this is where to spawn floating labels
- Implementation: create a `FloatingLabel` scene or inline function that:
  1. Instantiates a Label node as a child of a CanvasLayer over the battle scene
  2. Sets the text (e.g. "-4" for damage in red, "+3" for healing in green)
  3. Starts at the screen position of the affected card/hero
  4. Tweens: move upward by ~60px over 0.8s, fade alpha from 1 to 0 over 0.8s
  5. `queue_free()` on tween completion
- Use a CanvasLayer at the top of the battle scene tree so numbers render above all cards
- Get screen position of a Control node: `node.get_global_rect().get_center()`
- Colors: damage = red (#FF4444), healing = green (#44FF88), armor = blue (#44AAFF)
- Strict mode: do not use `:=` with Tween return values that are Variant

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
