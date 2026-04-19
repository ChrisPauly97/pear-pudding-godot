# TID-078: Hit Flash on Minions and Heroes

**Goal:** GID-023
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

When a minion or hero takes damage there is no visual reaction — they simply update their health number. A brief color flash signals impact and makes combat feel responsive.

## Research Notes

- `scenes/battle/BattleScene.gd` — find the card/hero display nodes; they are likely Control nodes with a background ColorRect or TextureRect
- Flash approach: when damage is applied, tween the node's `modulate` color:
  1. Instantly set `modulate = Color(1, 0.3, 0.3, 1)` (red tint)
  2. Tween back to `Color(1, 1, 1, 1)` over 0.25s
- For healing: flash green `Color(0.3, 1, 0.5, 1)` then back to white
- Encapsulate in a helper method `_flash_node(node: Control, flash_color: Color)` in BattleScene to avoid repetition
- Minion cards: the card display container or its background panel
- Hero panel: the hero HP display container
- Godot Tween: `var tw := create_tween(); tw.tween_property(node, "modulate", flash_color, 0.0); tw.tween_property(node, "modulate", Color.WHITE, 0.25)`
- Strict mode: `create_tween()` returns a `Tween` — do not use `:=` unless the call site is typed

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
