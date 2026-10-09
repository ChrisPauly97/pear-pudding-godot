# TID-752: Combat UI: school-coloured numbers, Weak!/Resisted, nameplate icons

**Goal:** GID-181
**Type:** agent
**Status:** pending
**Depends On:** TID-749, TID-750

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Players must see why a hit was big or small, or schools are invisible numbers.

## Research Notes

- Floating numbers: `scenes/battle/BattleFx.gd` `spawn_float_labels` L231 / `spawn_float_label(pos, text, color, amount)` L251. Feed the resolver's `outcome` through; colour by school using `MagicTypes` colours (physical = neutral white/grey); suffix text "Weak!" / "Resisted" / "Immune".
- Real-time presentation: `scenes/battle/modules/RealtimeVisuals.gd` (unit bars, hero tokens), `SwingFx.gd` for auto-attack impacts. Net replay: `scenes/battle/net/NetBattleFx.gd` carries fx in state mirrors — outcome must ride along for PvP/co-op viewers.
- Nameplate/hero strip school icons: small coloured pips for weak (and resist) schools. Until TID-753 lands show all; TID-753 gates by bestiary knowledge.
- UI sizing relative to viewport, factories from `UiUtil` (CLAUDE.md). Mobile parity: icons tappable for a tooltip.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
