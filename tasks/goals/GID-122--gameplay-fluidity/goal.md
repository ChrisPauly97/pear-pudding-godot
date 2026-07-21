# GID-122: Gameplay Fluidity & Intuition

## Objective

Reduce input friction and invisible-mechanic gaps in the overworld and cantrip
HUD identified in a fluidity/intuition audit. Each task closes a confirmed gap
in the current codebase (not a re-implementation of things already shipped).

## Context

Research pass (2026-07-20, branch `claude/gameplay-fluidity-intuition-i3et9e`)
surveyed camera/player, tap-to-move, battle UI, and HUD registry docs plus the
open backlog. Several intuition gaps that looked plausible up front turned out
to already be solved and were dropped from scope:

- Contextual interact prompt labels ("OPEN"/"TALK"/"ATTACK" etc.) — already
  computed per-entity in `WorldScene._check_interactions()` and passed to
  `WorldHUD.show_interact_prompt()`.
- Tap-to-play minions in battle — already implemented via
  `BattleScene._on_hand_card_tap()` → `_enter_slot_select_mode()` (GID-119).
- Unaffordable-card dimming + colorblind-safe target marks — already in
  `CardViewBuilder.apply_card_style()` (GID-119 / TID-451).
- Battle engage telegraph (the "!" alert beat before the fight transition) —
  already shipped as `EnemyNPC.engage()` (GID-114 / TID-427).
- Camera micro-stutter (BID-014) — already fixed by GID-084 (TID-303 camera
  lerp + pixel-snap, TID-304 `AnimatedSprite3D` walk animation).
  `tasks/index.md` already noted the promotion but the backlog file was
  never moved to `tasks/archive/backlog/` and its index row never moved to
  Resolved Backlog — pure bookkeeping, fixed by TID-465 below since that
  task also touches player movement feel.

Confirmed gaps became four tasks:

1. Tapping a chest/door/NPC/waystone/etc. only walks the player near it —
   `WorldScene._handle_tap_to_move()` never fires the interaction on arrival,
   so mobile players still need a second tap on USE.
2. The tap-to-move destination marker gives no visual feedback for a
   rejected/failed tap beyond a text tip — no marker flashes at the tapped
   tile.
3. Locked cantrip buttons (`[G] Phase` / `[D] Dig`) are hidden entirely when
   the deck doesn't qualify (BID-050) — the mechanic that makes deck-building
   affect exploration can't teach itself to a new player.
4. `Player.gd` has no jump input buffering or coyote time — a jump pressed a
   few frames before landing or after leaving a ledge is dropped.

## Tasks

| ID | Name | Type | Status | Depends On |
|----|------|------|--------|------------|
| TID-461 | Tap-to-Interact on Arrival | agent | done | — |
| TID-462 | Failed-Tap Marker Feedback | agent | done | — |
| TID-463 | Locked Cantrip Discoverability (BID-050) | agent | done | — |
| TID-464 | Jump Buffer & Coyote Time | agent | done | — |
| TID-465 | Movement-Feel Doc Sweep + Archive BID-014 | agent | done | TID-464 |

## Acceptance Criteria

- [ ] Tapping directly on a chest/door/NPC/waystone/mailbox/etc. walks the
      player there and fires the same interaction E/USE would, without a
      second input — unless the path is interrupted (manual input, battle
      start, map change), in which case nothing auto-fires
- [ ] A tap that resolves to an unreachable/unwalkable tile shows a brief
      red marker at the tapped tile in addition to the existing text tip
- [ ] `[G] Phase` / `[D] Dig` are visible (not hidden) even when locked, shown
      dimmed with an "X/4" family-card progress count in the label; tapping a
      locked button still surfaces the existing "requires N+ family cards"
      message
- [ ] Pressing jump up to ~0.12s before landing, or up to ~0.12s after
      leaving a ledge, still jumps
- [ ] BID-014 moved to `tasks/archive/backlog/` with its resolution noted;
      `tasks/index.md` updated

## Verification Note

Same sandbox constraint as GID-119/GID-120: no Godot binary obtainable in
this environment (network policy blocks the engine download), so headless
import and the GUT suite could not run locally. Changes were written by
close reading of the exact call sites and existing conventions (typed arrays,
`Callable`-based tile lookups, `has_method()`/`has_signal()` dynamic dispatch
for the `CharacterBody3D`-typed `_player` reference). CI must be watched on
push.
