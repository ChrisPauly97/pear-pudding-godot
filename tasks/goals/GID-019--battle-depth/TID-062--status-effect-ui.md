# TID-062: Status Effect UI Indicators

**Goal:** GID-019
**Type:** agent
**Status:** pending
**Depends On:** TID-060

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

With statuses stored and processed, players need visual feedback showing which minions/heroes are affected and for how long. This task adds icon overlays and stack/duration labels to board cards and hero panels.

## Research Notes

- Board cards are rendered in `scenes/battle/BattleScene.gd` or a CardDisplay/CardSlot subscene — find the node that displays a minion on the board
- Add a small HBoxContainer of status icons in the corner of each board slot and the hero panel
- Each icon: a colored Label or TextureRect (can use colored squares if no art yet) + a number showing remaining duration/stacks
- Color coding suggestion: poison=green, armor=blue, freeze=cyan, stun=yellow
- Update icons whenever a status is applied (connect to GameBus signal) or a status ticks (TID-061 emits signal)
- When a status is removed (duration=0), remove its icon
- Follow CLAUDE.md UI sizing: icons sized relative to viewport height (e.g. vh * 0.03 square)
- Mobile: ensure icons don't obscure the card's attack/health numbers

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
