# TID-546: Real-Time Combat Prototype

**Goal:** GID-135
**Type:** agent
**Status:** review
**Depends On:** TID-540

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User (2026-09-26): "real time parallel combat is what makes WoW's combat dynamic — enemy attacks on its own schedule, I use my abilities on mine … a global cooldown per player/enemy?" Prototype it behind a setting for one solo PvE fight so the user can feel it before committing the rest of GID-135.

## Research Notes

See `docs/agent/combat-model.md` → Real-Time Combat. Battle state is pure (`GameState`/`PlayerState`); turn coupling is ~25 `current_player_idx` references, so a driver that pins the player index and acts for the enemy via events avoids touching GameState.

## Plan

1. Pure `RealtimeCombat.gd`: GCDs, mana/draw clocks, per-unit swing timers, Ward/focus targeting, enemy cast telegraph.
2. `BattleRealtime.gd` scene module: setting-gated start, `_process` clock, event rendering, GCD bar, focus label.
3. Hooks: `_can_local_act` GCD gate, play hooks, enemy-minion tap → focus. Settings row "Battle Mode".
4. Unit tests + scene smoke test (added to CI).

## Changes Made

- New `game_logic/battle/RealtimeCombat.gd`, `scenes/battle/modules/BattleRealtime.gd` (+ `.uid`s).
- `BattleScene.gd`: creates `realtime` module; `maybe_start()` after setup; GCD in `_can_local_act`; GCD start in `_do_play_card`.
- `BattleTargeting.gd`: GCD start on slot plays. `BattleInput.gd`: tap enemy minion → focus in real time
  (`_on_enemy_card_tap` extracted). `SettingsScene.gd`: Battle Mode row (Turn-based / Real-time / Real-time (slow)).
- Tests: `tests/unit/test_realtime_combat.gd` (11), `tests/realtime_battle_smoke.gd` (added to CI scene smokes).
  Full suite exit 0, 0 SCRIPT ERRORs; coop/world/realtime smokes pass; gdlint + unsafe-hits clean.
- Always-on hero auto-attack (user follow-up): main hand `2 + hero.attack` every 2.5 s, off hand on its own 2.0 s
  timer (`offhand_damage`), orange swing bar; tapping the enemy hero clears focus (`BattleInput._on_enemy_hero_tap`
  extracted). +5 unit tests (16 total).
- Max mana fixed per fight (user follow-up): `RealtimeCombat.max_mana_for(level, bonus_mana)`; player level from
  `SaveManager.level`, enemy from difficulty tier (`BattleRealtime.enemy_level_for_tier`). No in-fight max growth. 19 unit tests.
- **Awaiting user playtest** (Settings > Battle Mode > Real-time). Mark done on approval; tuning notes go to TID-547.

## Documentation Updates

`docs/agent/combat-model.md`: Real-Time Combat section (rules table, prototype architecture, known gaps). CLAUDE.md BattleScene module table: `BattleRealtime.gd` row.
