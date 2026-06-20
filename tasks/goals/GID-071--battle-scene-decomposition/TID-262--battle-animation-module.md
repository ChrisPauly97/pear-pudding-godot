# TID-262: Extract battle animation & feedback module

**Goal:** GID-071
**Type:** agent
**Status:** done
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

1. Create `scenes/battle/BattleFx.gd` (RefCounted) with:
   - `setup(vh, float_layer, enemy_hero, player_hero, enemy_board, player_board, root)` + `set_game_state(state)`
   - Intent banner: `show_intent_banner`, `hide_intent_banner`
   - Status processing: `process_start_of_turn_statuses`, private `_tick_statuses_on_card/hero`
   - Status icons: `update_status_icons_card` / `update_status_icons_hero` both delegating to unified `_update_status_icons_impl`
   - Float labels: `snapshot`, `spawn_float_labels`, `spawn_float_label`, `pos_of_hero`
   - Card panel helper: `get_card_panel`
   - Flash: `flash_node`, `flash_from_snapshot`
   - Haptic + shake: `haptic`, `trigger_shake`, `check_shake`
   - Convenience: `trigger_fx(snap)` = spawn_float_labels + flash_from_snapshot + check_shake
2. Create `scenes/battle/BattleFx.gd.uid` sidecar
3. Modify `BattleScene.gd`:
   - Add `const BattleFx = preload(...)`, `var _fx: BattleFx`
   - Remove `var _is_shaking`, `var _intent_panel` (moved to BattleFx)
   - In `_ready()`: create `_fx`, call `setup()`, call `set_game_state(_state)` after state is determined
   - Replace all call sites with `_fx.*` equivalents
   - Replace triple snapshot pattern with `_fx.trigger_fx(snap)` at all 9 sites
   - Remove all 16 extracted function definitions

## Changes Made

- Created `scenes/battle/BattleFx.gd` (RefCounted, ~270 lines): holds all visual feedback logic extracted from BattleScene — intent banner, status ticking/icons, floating damage numbers, hit flash, screen shake, haptic, card panel helper, and the `trigger_fx(snap)` convenience that replaces the 3-line snapshot pattern.
- Created `scenes/battle/BattleFx.gd.uid` sidecar.
- Modified `scenes/battle/BattleScene.gd` (3309 → 3004 lines): added `const BattleFx` preload and `var _fx: BattleFx`, wired up `_fx.setup()` and `_fx.set_game_state()` in `_ready()`, removed `_is_shaking` and `_intent_panel` local vars, replaced 30+ call sites with `_fx.*` equivalents, removed 16 extracted function definitions.
- Unified `_update_status_icons_card`/`_update_status_icons_hero` into `_update_status_icons_impl(hbox, entity)` with untyped `entity` duck-typing.
- Replaced 8 occurrences of the 3-line snapshot pattern with `_fx.trigger_fx(snap)`.

## Documentation Updates

- No doc-level changes needed; `docs/agent/battle-system.md` describes the battle system at a feature level and does not need to enumerate internal implementation files.
