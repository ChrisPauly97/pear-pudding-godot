# TID-448: Battle Layout — Reclaim Vertical Space, No Overlap

**Goal:** GID-119
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

`BattleScene.tscn` stacks six full-width rows: EnemyHandView (face-down card backs,
`vh*0.20`), EnemyHeroView (`vh*0.10`), EnemyBoardView (`vh*0.20`), PlayerBoardView,
PlayerHeroView, PlayerHandView. On a landscape phone that leaves each card ~6.5mm wide.
The enemy hand row communicates only "how many cards" — 20% of the screen for one
integer. SidePanel (anchors 0.8–1.0 × full height) floats over the full-width rows, so
its buttons overlap the rightmost board slot and hand card.

## Research Notes

- `_refresh_all()` (`BattleScene.gd`) refreshes `_enemy_hand_view` via
  `refresh_zone(..., "enemy_hand")`; `_make_card_view` returns a styled card-back panel
  for that zone. PvP/coop/team all flow through the same `_refresh_all`.
- `_apply_ui_sizes()` sets per-row `custom_minimum_size`; areas are anchor-driven in
  the tscn (EnemyArea 0–0.45, PlayerArea 0.5–1.0, Divider at 0.5).
- Boss-name display: `CardViewBuilder.refresh_hero` builds the hero vbox once
  (NameLabel/HPLabel/HPBar[/ManaLabel]/StatusRow) and updates HP each refresh.
- The pause button, hero power, potion, gambit badge, battlefield info label, and
  puzzle Give Up button are all appended to `$SidePanel` — keep that container.

## Plan

1. `BattleScene.tscn`: EnemyArea → anchors 0–0.38, PlayerArea → 0.38–1.0, Divider →
   0.38; EnemyArea/PlayerArea/`Divider` anchor_right → 0.86 so the side panel occupies
   its own column (SidePanel anchor_left 0.86).
2. Hide `EnemyHandView` (replaced by a count label); stop refreshing it in
   `_refresh_all()`.
3. `CardViewBuilder.refresh_hero`: accept `hand_count: int = -1`; when ≥ 0 show a
   "Cards in hand: N" line on the enemy hero panel. BattleScene passes
   `players[_opp_idx()].hand.size()`.
4. `_apply_ui_sizes()`: hero rows `vh*0.10`, board rows `vh*0.27`, player hand
   `vh*0.24`; zero out enemy hand row.

## Changes Made

- `BattleScene.tscn`: EnemyArea 0→0.38, Divider/PlayerArea split moved 0.5→0.38, all
  three content containers end at anchor_right 0.86; SidePanel starts at 0.86.
- `BattleScene.gd _apply_ui_sizes()`: enemy hand row hidden (`visible = false`,
  zero min size); hero rows 0.10 vh; board rows 0.27 vh; hand row 0.24 vh.
- `BattleScene.gd _refresh_all()`: enemy-hand `refresh_zone` call replaced by passing
  the opponent hand count into `refresh_hero`.
- `CardViewBuilder.refresh_hero(hero_node, hero, is_enemy, hand_count)`: new optional
  param; enemy panel shows a persistent `HandLabel` ("Cards in hand: N").
- **Co-op/team amendment:** those modes anchor an ally status bar at the top
  (`PRESET_TOP_WIDE`, 8% vh) that previously overlapped the harmless card-back row.
  In `_coop_pve` / `_team_pvp` the collapsed hand row stays visible as an empty
  spacer (8.5% vh), rows compress (hero 8%, boards 22%, hand 20%), and
  `CardViewBuilder.set_card_scale(0.85)` shrinks cards so everything fits.

## Documentation Updates

- `docs/agent/battle-system.md`: new "Mobile Battle Layout (GID-119)" section.
