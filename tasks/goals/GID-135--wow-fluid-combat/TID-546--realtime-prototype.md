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
- Mana ×100 (user follow-up): `HeroState.mana_scale` + `gain_mana`/`drain_mana`; `PlayerState.effective_cost` /
  `base_cost` scale; all mana mutation sites (companion, consumables, spells, PvP hero power, attuned) converted;
  continuous 65 pt/s regen; max = 400 + 35/level + 100/bonus unit, cap 1000. 22 unit tests; PvP smoke passes.
- Playtest round 1 (user): costs shown as their own "N mana" line (blue/green/red) on card faces, inspect overlay
  and enemy cast banner (fixes a freshly built card showing the unscaled cost); Allies are commanded (ready timer,
  off-GCD attack via the normal attack path) instead of auto-swinging; slower pace (enemy GCD 3.5 s, cast 1.5 s,
  minion swing 4.5 s, hero 3 s, regen 50/s, draw 6 s); clock stops under pause/inspect/tutorial popups and during
  lunges; Turn label hidden, bars labelled. `_can_local_act(ignore_gcd)`. Smoke test covers popup freeze +
  commanded attack on GCD. 26 unit tests.
- Playtest round 2 (user): regen 20 pt/s; board caps 3 Allies / 2 enemy minions (`PlayerState.max_units`,
  empty over-cap slots hidden); enemy minions alternate weakest Ally / hero; both heroes auto-attack (enemy by
  tier); spell cast times with cast bar (`run_cast` wraps the 4 solo spell paths; GCD is a minimum); enemy cast
  bar; `RealtimeVisuals.gd`: hero tokens with sprites that lunge on auto-attack, per-unit charge/ready/wind-up
  bars, enemy unit lunges. Smoke covers cast deferral. 30 unit tests.
- Playtest round 3 (user): diagonal arena — hero strips moved into the hero tokens (you bottom-left, enemy
  top-right), board rows re-placed diagonally top-left → bottom-right by `DiagonalBoard.gd` (runtime script on
  the board HBoxes, sorts after the native BoxContainer pass), divider hidden, hand at the bottom; smoke asserts it.
- Rows moved close together (user): `row_origins()` places parallel front lines one card height + a thin
  gap apart, centred; `tests/unit/test_realtime_layout.gd`.
- Layout round 5 (user): lines attached to their heroes with a wide middle gap (`arena_layout`), arena spans
  the full width (hand centred), pause/Effects top-left, cooldown/auto-attack/target box bottom-right.
- **Awaiting user playtest** (Settings > Battle Mode > Real-time). Mark done on approval; tuning notes go to TID-547.

## Documentation Updates

`docs/agent/combat-model.md`: Real-Time Combat section (rules table, prototype architecture, known gaps). CLAUDE.md BattleScene module table: `BattleRealtime.gd` row.
