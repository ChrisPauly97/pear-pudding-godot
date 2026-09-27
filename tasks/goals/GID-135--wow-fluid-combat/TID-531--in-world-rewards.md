# TID-531: In-World Loot & XP Toasts

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-528

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

WoW doesn't stop you with a result screen: loot and XP pop up and you keep moving. Replace the full-screen result card for routine wins.

## Research Notes

- Result card: `scenes/battle/BattleResultUI.gd` `_build_result_overlay(bg, sep_frac)`, count-up steps; victory logic in
  `autoloads/scene_manager/BattleVictory.gd` (`SceneManager.victory`), defeat in `BattleDefeat.gd`.
- Rewards: coins/essence (`SaveManager` ~L1151), XP/level-up (`_compute_level`, ~L1214), card drops (`CardDropUtil`).
- Plan: routine wins → floating "+XP / +coins / card" toasts over the world plus an XP bar tick (WorldHUD); keep the
  full card for bosses, level-ups (short banner), captures/soulbind choices, and defeats.
- Card-choice rewards need a lightweight non-blocking picker or deferral to a loot notification.

## Plan

TID-528 (fight in place) is already implemented on this branch: `SceneManager.fights_in_world()` /
`_enter_battle_in_world()` / `reattach_world()` freeze the world in place and set `BattleScene.in_world
= true`. This task hooks into that flag rather than re-deciding "was this fought in the world" itself.

1. **Decide "routine" at the point the result would be shown**, not after: `BattleScene.
   _show_standard_victory()`'s existing branches already separate boss (`show_victory_boss`, kept
   as-is) from non-boss, and non-boss further splits on the soulbind-hunt signature (met /
   not-met, both kept as-is — "keep the full card for... captures/soulbind choices"). Add one more
   branch: **not boss, no soulbind hint, `in_world == true`** → routine. Everything else (including
   every non-boss win that is *not* fought in place, i.e. the classic wipe path) keeps the existing
   blocking `show_victory()` card unchanged, per "Keep the non-in-world path unchanged."
2. **Skip the blocking card for the routine case**: `_emit_routine_victory_toast()` builds and emits
   the exact same `GameBus.battle_won` dict `show_victory()`'s "Collect" button would (card reward,
   hero HP, veterancy, rolled rarity/stats, corruption/redemption), immediately, plus one new key
   `"in_world_toast": true`. This is "instead of", not "in addition to", per the task's phrasing —
   a routine win never shows a button the player has to tap.
3. **Grant rewards exactly as before**: `BattleVictory._on_battle_won()` needed no restructuring —
   it already computes `coins_won`/`xp_amount` from `enemy_type` and grants everything the same way
   regardless of which BattleScene path emitted `battle_won`.
4. **Show the toast only after the world is back**, and only inside the reattach callback: at the
   `_sm._restore_world()` call site, check `result.get("in_world_toast", false)` and pass
   `_show_reward_toasts.bind(coins_won, xp_amount, reward_card)` as `after` instead of calling
   `_restore_world()` bare — `_restore_world(after)` already guarantees `after` runs once
   `current_scene` is the live (thawed-in-place or reattached) `WorldScene`, inside the transition
   callback either way (see the CLAUDE.md spire-draft learning this task's own note points at).
5. **New world-space toast**: `scenes/world/RewardToastFx.gd`, a small self-freeing `Node3D` (no
   `class_name`, preloaded) — up to three stacked `Label3D` lines ("+N Coins" / "+N XP" / the card's
   name) that rise and fade over ~1.6 s at the player's position, mirroring the project's existing
   world-space `Label3D` usage (`WorldItem`'s coin pickup label, `SpriteRegistry.make_name_label`)
   rather than the 2D `AchievementToast` corner popup (`SceneManager.show_toast`) — the task asks
   for "world-space labels at the fight location", not a screen corner.
6. **XP bar tick**: no new code — `SaveManager.add_xp()` already drives whatever reads `save_manager.
   xp`/`level`, and a level-up already gets its own toast via the pre-existing `GameBus.level_up` →
   `SceneManager._on_level_up()` → `_toast.show_text("Level Up!", …)` chain. That satisfies "keep...
   level-ups (short banner)" for free — it fires independently of which result path granted the XP,
   so it still shows up on a routine in-world win, alongside (not instead of) the reward toast.
7. **Card-choice rewards**: out of scope for this pass — a routine win only ever offers a single
   pre-rolled card (no choice to make), so the "lightweight non-blocking picker" the research notes
   flagged only matters for boss multi-card drops, which stay on the unchanged full-card path.
8. Extend `tests/in_world_battle_smoke.gd` (`_check_routine_win_toast`) rather than adding a new
   smoke file — it already builds the in-world battle fixture the check needs.

## Changes Made

- `scenes/battle/BattleScene.gd`: `_show_standard_victory()` gains an `elif in_world:` branch (only
  reachable when there's no soulbind hint) calling new `_emit_routine_victory_toast()`, which emits
  the same `battle_won` payload `show_victory()`'s button would plus `"in_world_toast": true`.
- `autoloads/scene_manager/BattleVictory.gd`: captures `coins_won` (was inline, now a named local);
  when `result["in_world_toast"]` is set, `_restore_world()` is called with
  `_show_reward_toasts.bind(coins_won, xp_amount, reward_card)` instead of bare. New
  `_show_reward_toasts(coins_won, xp_won, reward_card_id)` builds the toast lines and hands them to
  a `RewardToastFx` added under `get_tree().current_scene` (the reattached `WorldScene`) at
  `world.get_player().global_position`.
- `scenes/world/RewardToastFx.gd` (new): self-freeing `Node3D` reward toast — see Plan #5.
- `tests/in_world_battle_smoke.gd`: new `_check_routine_win_toast()` — engages `undead_basic` with
  its signature (`sig_wanderer`) pre-marked captured (so the win is the plain routine case, not the
  soulbind-hunt branch), kills the enemy, asserts no `Continue`/`Collect`/`Collect All` button ever
  appears, and that a `RewardToastFx`-scripted child lands on the world once `SceneManager` is back
  in `WORLD` state.

Validated: headless import (no parse errors), `scripts/unsafe-hits.sh` (empty), `gdlint` on every
changed file (clean), full `tests/runner.gd` (2656 passed / 0 failed / 0 SCRIPT ERROR), and
`world_scene_smoke` / `menu_hub_smoke` / `spire_draft_smoke` / `realtime_battle_smoke` /
`in_world_battle_smoke` (all exit 0, no SCRIPT ERROR, no `[FAIL]` lines).

**Known gap (documented, not fixed):** the toast shows only the primary enemy's coins/XP/card — a
win with joined enemies (TID-551 adds) still silently grants their rewards via
`_reward_joined_enemies()` exactly as before, just without a toast of their own. Extending the toast
to summarize adds too is a natural follow-up if it turns out to matter in practice.

## Documentation Updates

- `docs/agent/combat-model.md`: new "In-world rewards (TID-531)" subsection right after "Fighting in
  place (TID-528)", describing the routine-win detection, the `in_world_toast` payload flag, the
  `_show_reward_toasts` / `RewardToastFx` mechanism, the joined-enemies gap, and why level-ups need
  no special handling. The hero auto-attack timing row also gets its off-hand note updated to point
  at the shipped slot (`inventory-and-deck.md`) instead of a forward "TID-545" reference.
