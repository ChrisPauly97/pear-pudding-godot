# TID-587: Unlock Ladder Table & XP Curve

**Goal:** GID-141
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Single source of truth for "what unlocks when, where, for how much". Every other GID-141 task reads it. See the ladder in `goal.md`.

## Research Notes

- New pure-logic `game_logic/progression/UnlockLadder.gd` (RefCounted, static, no autoloads): `LADDER: Array[Dictionary]`
  rows `{id, level_req, cost, trainer, title, how_to}`. `how_to` is the multi-line explanation the trainer shows
  (this is the "forced to read it" text), so it must be complete and concrete. API: `def(id)`, `is_learned(id, learned)`,
  `available_at(level) -> Array[String]` (newly available at exactly that level), `can_learn(id, level, coins, learned)`,
  `trainer_for(id)`, `pending_for_trainer(trainer, level, learned)`.
- Storage: reuse `SaveManager.learned_abilities` (Array[String], already in `PERSISTED_FIELDS`, written by
  `SaveManager.learn_ability(id, cost)`) — feature ids get a prefix-free unique id (e.g. `feat_minions`, `feat_dig`),
  skill ids stay as in `SkillBar.ABILITIES`.
- Skills: `game_logic/battle/SkillBar.gd` — `ALWAYS_KNOWN = ["strike","mend","kick"]` (L21) must shrink to `["strike"]`;
  mend/kick get `level_req` 2/3 + a cost. Existing `level_req`/`learn_cost` on guard/ember_lance/etc. (L41+) must be
  reconciled with the ladder (keep SkillBar as the data owner for skills, ladder rows for skills reference it — no
  duplicated numbers).
- Migration: `game_logic/save/SaveMigrations.gd` (bump `CURRENT_VERSION`, append a row): existing saves get every ladder
  entry with `level_req <= level` added to `learned_abilities`, plus anything already in use (owned mount → `feat_mount`,
  non-empty `magic_type` → skills tab, `spire_best_floor > 0` → spire). No regression for existing players.
- Head start: `SaveManager.new_game(head_start)` (L460) — head start learns all.
- XP curve: `SaveManager.xp_for_level` = `lvl*lvl*50` (L1216) and `EnemyRegistry.get_xp_reward`. Ladder needs levels
  1–6 roughly every ~10 min in the starter zone, ~10 by end of starter/early Chapter 1, 40 as long-term. Evaluate and,
  if needed, retune the curve (and `UpgradeDefs.MAX_LEVEL`/`CombatOnboarding.MAX_LEVEL` interplay). Document the
  resulting pacing table in the task.
- Coins: new game starts with 50 coins (L477). Training costs early must be affordable from starter-quest gold (TID-592)
  — set early costs low (10–40), scale up.
- GameBus: add `feature_learned(id)` and `training_available(ids)` signals (literal `.emit()` calls;
  `test_gamebus_signal_coverage`). Emit `training_available` from level-up in `SaveManager.add_xp` (L1284).
- Tests: new `tests/unit/test_unlock_ladder.gd` — ids unique, levels ascending, every row has trainer + non-empty how_to,
  skill rows exist in SkillBar, migration grants by level.

## Plan

1. `UnlockLadder.gd` with feature rows + skill rows (skill numbers stay in SkillBar).
2. SkillBar: only Strike always known; Mend L2 / Kick L3 and the other trainer skills re-levelled into the ladder
   gaps (11, 13, 14, 16, 18); bar fallback/padding respect what is known.
3. SaveManager: `has_learned`, `learn_ability` slots skills + emits `feature_learned`, `add_xp` emits
   `training_available`, `new_game` resets (head start learns all).
4. Migration v44 keeps existing saves whole.
5. XP curve: evaluated, kept (see doc "XP pacing").

## Changes Made

- New `game_logic/progression/UnlockLadder.gd`; `SkillBar.gd` levels/costs, `ALWAYS_KNOWN = ["strike"]`,
  `LEARNABLE_ORDER` + mend/kick, `_init` fallback + `resolved_bar` padding (fixed a latent bug: it padded with
  DEFAULT_BAR ids whether or not they were known).
- `SaveManager.gd`: `has_learned`, learn_ability changes, `training_available` on level-up, `new_game` resets
  `learned_abilities` / `skill_bar` (it never reset them before — a new game kept the last save's trainer skills).
- `GameBus.gd`: `training_available(ids)`, `feature_learned(id)`.
- `SaveMigrations.gd`: v44 `_m44_unlock_ladder`.
- `NpcInteractions.gd`: trainer header text ("Strike is yours already").
- Tests: new `test_unlock_ladder.gd` (10); `test_skill_bar.gd` updated for trainer-taught Mend/Kick;
  `realtime_battle_smoke.gd` learns them first. Suite 2813 pass; all CI smokes clean; gdlint + unsafe-hits clean.

## Documentation Updates

New `docs/agent/starter-zone-and-training.md`; CLAUDE.md docs row + "Unlocks: UnlockLadder Is the Source of Truth".
