# TID-138: Simplified Battle UI Layout

**Goal:** GID-034
**Type:** agent
**Status:** pending
**Depends On:** TID-134

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The battle scene is the most visually dense part of the game and the one played most on mobile. This task redesigns the hand-card strip and board slots for larger touch targets, enlarges the HP/mana readouts, and removes redundant status text to reduce clutter — all without changing game logic.

## Research Notes

### BattleScene layout (`scenes/battle/BattleScene.gd`)

Current measured fractions:
- Hero view height: `_vh * 0.09`
- Board view height: `_vh * 0.18`
- End Turn button: `_vh * 0.16` × `_vh * 0.10` — already good
- Menu button: `_vh * 0.14` × `_vh * 0.07` — already good
- Hand card width: inferred from `HBoxContainer` with separation `_vh * 0.01` — cards likely `_vh * 0.14–0.17` wide
- Side panel separation: `_vh * 0.025`

### Changes to make

**1. Hand card size increase**
- Increase card `custom_minimum_size` height from current value to `_vh * 0.22` (was likely `_vh * 0.17–0.19`).
- Card art texture region: scale accordingly.
- Allow horizontal scroll in hand if more than 5 cards — wrap in `ScrollContainer` with `horizontal_scroll_mode = SCROLL_MODE_AUTO`.

**2. Board slot hit zones**
- Board slot buttons: minimum size `_vh * 0.14` height (same as card height guidance), `_vw * 0.16` width.
- Add clear visual border so slots are obviously tappable on mobile.

**3. HP / mana labels**
- Hero HP and enemy HP labels: increase font to `_vh * 0.038` (was likely `_vh * 0.022–0.026`).
- Mana label: `_vh * 0.032`.
- Make HP/mana displays icon-based if icons exist (heart ♥ / star ★ prefix in label text is fine).

**4. Remove visual clutter**
- If there are redundant "ATK:" / "HP:" column labels on board minion cards that duplicate the card art info, hide them (set `visible = false`).
- Reduce board separation `_vh * 0.015` (tighten to give hand more height).

**5. Card font sizes**
- Card name label: `_vh * 0.022` minimum.
- Card stat labels (atk/hp on card): `_vh * 0.020` minimum.

### Files to modify

- `scenes/battle/BattleScene.gd` — only file changed

### Do NOT change

- Game logic, card play validation, AI behaviour.
- `CardInspectOverlay.gd` (touched by TID-136).
- End Turn / Menu button sizing — already large enough.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
