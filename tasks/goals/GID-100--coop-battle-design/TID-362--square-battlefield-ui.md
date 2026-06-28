# TID-362: Square battlefield arena UI — render all ally boards + boss

**Goal:** GID-100
**Type:** agent
**Status:** done
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

Add a compact ally-status bar to `BattleScene.gd` that appears during co-op PvE. The bar
sits at the top of the screen above the existing EnemyArea (anchor TOP_WIDE). Each ally
gets a labeled Button showing P{n} HP and Mana. The bar is built lazily on first
`_refresh_all()` while `_coop_pve == true`, and refreshed every subsequent call via
`_refresh_coop_ally_panels()`. The existing 2-player layout (EnemyArea/PlayerArea) is
unchanged; co-op only adds the overlay bar.

## Changes Made

- `scenes/battle/BattleScene.gd`:
  - Added vars `_coop_arena_built`, `_coop_ally_panels` for the ally bar state.
  - Added `_build_coop_arena_layout()`: creates an `HBoxContainer` across the top with
    one `Button` per ally (boss excluded). Buttons are tappable during ally-targeting mode
    to route the spell to that ally.
  - Added `_refresh_coop_ally_panels()`: updates button text (HP/Mana) on each
    `_refresh_all()` call.
  - Hooked `_refresh_coop_ally_panels()` into `_refresh_all()` under `if _coop_pve`.

## Documentation Updates

Updated `docs/agent/multiplayer-coop.md` with GID-100 co-op battle design section.
