# TID-062: Status Effect UI Indicators

**Goal:** GID-019
**Type:** agent
**Status:** done
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

- Add `StatusRow` HBoxContainer to board card vboxes and hero panel vboxes
- Color-coded abbreviated labels: P=poison (green), A=armor (blue), F=freeze (cyan), S=stun (yellow)
- `_build_card_vbox(card, with_status_row)` param controls when to add the row
- Board zones (board, enemy_board) get status rows; hand/enemy_hand do not
- `_update_status_icons_card()` and `_update_status_icons_hero()` rebuild icons on each refresh

## Changes Made

- `scenes/battle/BattleScene.gd`: modified `_build_card_vbox()`, `_update_card_view()`, `_make_card_view()`, `_refresh_hero()` for status rows; added `_update_status_icons_card()` and `_update_status_icons_hero()`; named all label nodes (NameLabel, StatsLabel, DescLabel)

## Documentation Updates

- Updated `docs/agent/battle-system.md`
