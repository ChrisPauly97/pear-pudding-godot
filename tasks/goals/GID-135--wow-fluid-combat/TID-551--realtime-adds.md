# TID-551: Adds — a Second Enemy Joins a Real-Time Fight

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-546, TID-528

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User: "fight with two monsters … can we have a dual battle where it morphs into a coop battle — two NPC enemies
against me?" Approved building it on the existing `team_battle` state (you vs two AI enemy heroes) instead of
refusing the second engage.

## Research Notes

- `GameState.team_battle` + `player_teams` already give N-hero win rules (`is_game_over` / `winner` per team) and
  `opponent()` = lowest-HP enemy-team member. Co-op PvE is the reverse shape (many heroes vs one boss); team duels
  are networked PvP only.
- `SpellEffectResolver._bury_if_dead` already finds a card's real owner; `resolve_spell` used `opponent()`.

## Plan

Generalise RealtimeCombat to N sides; `add_enemy` turns the fight into a team battle; the module builds the add's
hero + deck, token, row and cast bar; route mid-fight engages into it; reward every joined enemy on victory.

## Changes Made

- `RealtimeCombat` rewritten for players[0] = you, players[1..] = enemies: per-side arrays, `add_enemy()`
  (team battle, teams [0,1,1], ≤ `MAX_ENEMIES` = 2), per-enemy GCD / casts / pushback / swings,
  `target_enemy()` + `focus_enemy`, `owner_of()`, fallen enemy's minions flee (`enemy_down` event). The old
  `enemy_casting` / `enemy_cast_remaining` / `enemy_pushbacks` stay as properties for side 1.
- `BattleRealtime`: `can_join()`, `join_enemy()` (tier-scaled deck, boss HP, 3-card hand, level by tier),
  `refresh_extra_views()` (called from `BattleScene._refresh_all`), `set_focus_enemy()`, `hero_screen_pos()`,
  `hero_view_for()`, per-side `_after_enemy_play` / interrupts.
- `RealtimeVisuals`: side-keyed tokens; enemy cast bars live inside each token; `add_enemy_view()` builds the add's
  token (stacked under the first enemy's), hero strip (tap = target it) and diagonal row; `unit_panel()`;
  fallen enemies grey out; the Cooldown/Auto-attack box moved to the screen's bottom-right corner.
- `BattleInput` / `BattleTargeting`: attacks and hero-targeted spells take the defender index (`_defender_of`,
  `_on_enemy_hero_input(event, pidx)`, `_on_target_chosen_hero(pidx)`); `SpellEffectResolver._explicit_opponent`
  resolves against the targeted enemy.
- `SceneManager`: `accepts_engage()` accepts a mid-fight engage when the real-time battle can take an add;
  `_on_enemy_engaged` routes it to `join_enemy` and records `_joined_enemies`; `BattleVictory._reward_joined_enemies`
  marks each defeated + bestiary/bounty progress + its coins and XP; cleared on defeat, menu and battle start.
- Tests: `tests/unit/test_realtime_adds.gd` (7); `in_world_battle_smoke` engages an add mid-fight, wins both
  through the real result screen, checks the world is back and both ids are defeated. Suite + smokes green.

## Documentation Updates

`docs/agent/combat-model.md` → Adds; CLAUDE.md BattleRealtime row.
