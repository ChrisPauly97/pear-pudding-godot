# TID-262: Extract battle animation & feedback module

**Goal:** GID-071
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

BattleScene lines 1687–1967 hold approximately 280 lines of visual feedback (enemy intent banner, status ticking/icons, floating damage numbers, hit flash, screen shake). A 5-line "snapshot → resolve → float labels → flash → shake" pattern repeats 9+ times across the file. This task extracts animation and visual feedback logic into a dedicated module, unifies duplicated status icon rendering, and creates a reusable animated-effect helper to replace the repeated snapshot pattern.

## Research Notes

**Floating damage numbers:** BattleScene.gd:1815–1869 (~55 lines). Text formatting, float path math, screen-space positioning, and tween setup for damage/heal labels.

**Hit flash:** 1875–1924 (~50 lines). Modulate color transition and whiteness overlay for card attack confirmation.

**Screen shake:** 1930–1966 (~37 lines). Camera position oscillation on damaging hits, configurable amplitude and duration.

**Enemy intent banner:** 1691–1718 (~28 lines). Enemy behavior text label (e.g. "Enemy will attack for 5 damage"), positioned above enemy card, dismissed on action.

**Status turn processing:** _process_start_of_turn_statuses (1373–1383), _tick_statuses_on_card (1484–1534), _tick_statuses_on_hero (1536–1587): ~50 lines across all three. Iterates status effects (poison, armor, freeze, stun), applies damage/healing, updates UI icons.

**Status icon duplication:** _update_status_icons_card (1779–1793) and _update_status_icons_hero (1795–1809) are near-identical — both iterate ["poison","armor","freeze","stun"] and build Label nodes with the same color/sizing logic. Should be unified with a parameterized _build_status_icon_label(effect, value) helper.

**Snapshot pattern:** The repeated snapshot sequence appears at lines 391–395, 397–401, 721–725, 738–742, 1115–1128, 1153–1163, 1180–1184, 1190–1194, 1220–1228:
```
var snap := _snapshot_hp_positions()
[resolve action]
_spawn_float_labels_from_snapshot(snap)
_flash_from_snapshot(snap)
_check_shake_from_snapshot(snap)
```
This pattern is the canonical way to trigger feedback after any card action. Extract a helper (e.g. `_trigger_effect_animation(snap)`) or animate-around-Callable abstraction and replace all 9 call sites.

**Suggested new file:** scenes/battle/BattleFx.gd (or BattleAnimationManager.gd), preloaded by BattleScene per the CLAUDE.md preload rule (never rely on class_name for new files). Owns all floating label, flash, shake, and status icon rendering. Receives snapshots and effect parameters from BattleScene, emits no signals (pulls state, doesn't push back to game logic).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
