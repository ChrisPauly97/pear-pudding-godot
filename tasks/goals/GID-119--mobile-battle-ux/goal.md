# GID-119: Mobile Battle UX & Accessibility

## Objective

Make card battles comfortable on small landscape phone screens: reclaim wasted vertical
space, enlarge cards to real touch-target size, make every play possible by tapping
(no drag required), raise card-face text to the readability floor, wire the existing
`text_scale` setting into the battle UI, and add non-color targeting cues.

## Context

The game runs landscape on Android (`sensor_landscape`, 1920×1080 canvas-items stretch).
In landscape, viewport height is the scarce resource and every battle element is sized
off vh. User report: battles are cramped and hard to use on a small phone.

Research findings (2026-07-17, branch `claude/mobile-card-battle-ux-99rrw9`):

- Card panels are `vh*0.10` × `vh*0.19` (`BattleScene.gd _make_card_view`,
  `CardViewBuilder._slot_size()`) — ~6.5mm wide on a 6.1" phone, below the ~9mm
  touch-target minimum GID-036 set for every other scene.
- Six full-width rows stack vertically (`BattleScene.tscn`): enemy hand (face-down
  backs, ~20% vh of near-zero information), enemy hero, enemy board, player board,
  player hero, player hand.
- Card-face fonts are 1.4–1.8% vh (`CardViewBuilder.build_card_vbox`), below the
  2.2% vh floor GID-036 established.
- Tapping a hand spell that isn't slot-targeted falls through to the inspect overlay
  (`BattleScene._on_hand_card_tap`) — targeted/untargeted spells are only castable by
  drag. Minions already have tap-to-slot (TID-293).
- `PlayerHandView` is a plain HBoxContainer: large hands overflow off-screen with no
  scroll or fan.
- `SidePanel` (anchor 0.8–1.0 full height) overlaps the full-width board rows.
- Settings `text_scale` (0.85/1.0/1.25, GID-070/TID-260) is persisted in
  SettingsScene but **never consumed anywhere** — it currently does nothing.
- `screen_shake` + `haptics` settings and `BattleFx.haptic()` already exist — out of
  scope here.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-448 | Battle Layout — Reclaim Vertical Space, No Overlap | agent | done | — |
| TID-449 | Bigger Cards + Overlap-Fan Hand + Card-Face Simplification | agent | done | TID-448 |
| TID-450 | Tap-First Spell Casting | agent | done | — |
| TID-451 | Readability & Accessibility Pass (text_scale wiring, target markers) | agent | done | TID-449 |
| TID-452 | Battle Tutorial Updates for Tap-First Flow | agent | done | TID-450 |

## Acceptance Criteria

- [ ] Enemy hand row no longer consumes a board-height band; enemy hand size is still
      visible (count on the enemy hero panel)
- [ ] Battle cards are ≥ `vh*0.13` wide and ≥ `vh*0.23` tall in hand and on boards
- [ ] Board rows / hand / hero rows fit their areas without overflowing the screen,
      and the side-panel controls never overlap a board slot or hand card
- [ ] A hand larger than the screen width fans (overlaps) instead of overflowing
- [ ] Every card class — minion, targeted spell, untargeted spell, slot spell — can be
      played with taps only (no drag)
- [ ] Card-face name/stat fonts ≥ `vh*0.02`; the `text_scale` setting scales battle text
- [ ] Valid spell/attack targets carry a non-color cue (marker), not just a colored border
- [ ] Battle tutorial text teaches the tap flow

## Verification Note

The sandbox for this goal could not download a Godot binary (GitHub release downloads
blocked by session network policy; tuxfamily mirror dead), so
`godot --headless --editor --quit` validation and the GUT test suite could not be run
locally. CI headless import must be watched on push.
