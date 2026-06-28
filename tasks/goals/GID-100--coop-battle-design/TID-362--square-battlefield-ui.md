# TID-362: Square battlefield arena UI — render all ally boards + boss

**Goal:** GID-100
**Type:** agent
**Status:** pending
**Depends On:** TID-360

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The visible payoff: a co-op battle that shows the whole party's boards at once around a
shared boss, instead of the two-zone top/bottom stack. This is the "square battlefield"
the user described.

## Research Notes

- **Current layout:** `scenes/battle/BattleScene.gd`
  - `@onready var _enemy_board_view = $EnemyArea/EnemyBoardView` (top),
    `@onready var _player_board_view = $PlayerArea/PlayerBoardView` (bottom). Hand views
    `$.../EnemyHandView` / `PlayerHandView`. Sizing is viewport-relative
    (`_vh * 0.20` board height, `BoxContainer.ALIGNMENT_CENTER`) — keep this discipline
    (CLAUDE.md "UI Sizing: Relative to Viewport").
  - Rendering is delegated to a `_view` helper (`_view.setup(...)`,
    `_make_card_view`, board views are `BoxContainer`s). Find the board-render module
    (likely `scenes/battle/` view/board builder from the GID-071 decomposition).
  - `_local_player_idx` drives the perspective swap (your side at the bottom).
- **Design — square/diamond arena (co-op only):**
  - Boss board at the **top/head**; the **local** player's board+hand at the **bottom**;
    other allies' boards on the **left/right edges** (and top corners for the 4th).
    Reflow by participant count (2 → you bottom + 1 ally; 3 → +sides; 4 → all edges).
  - Label each ally board with their **name + avatar color** (reuse the identity from
    `_remote_identities` / roster colors, GID-094).
  - Build the co-op layout behind a `coop_battle` flag set when entering via the
    TID-360 co-op-battle entry; the 2-player branch keeps the existing `$EnemyArea` /
    `$PlayerArea` scene tree untouched.
  - Keep everything **viewport-relative** and test mobile (portrait/landscape); a 4-board
    arena is tight — consider compact ally boards (read-only-ish) vs the full local board.
- **Input scope:** the local player only acts on **their** turn and (for cross-board
  cards, TID-363) targets ally boards; ally boards are display + valid drop/target
  surfaces, not places you summon your own minions.
- **Render the mirror:** the client renders from `_state` (the host mirror); ally boards
  come straight from the N-player `GameState` (TID-359). No new simulation here — pure
  presentation over the mirrored state.
- Run the headless import after scene/script edits (parse errors in BattleScene cascade).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
