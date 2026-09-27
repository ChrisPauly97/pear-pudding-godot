# TID-558: Maiteln Coaching Barks

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-550, TID-552, TID-553

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

During a new player's early real-time fights, show short, non-blocking speech-bubble
hints from Maiteln (Mentor) reacting to teachable moments — an enemy telegraphing a
cast, low HP, empty mana, a skill coming off cooldown for the first time, landing an
interrupt, an ally becoming ready — instead of leaving the player to work out the
real-time clock alone. Rate-limited (one bark per 8 s, each line at most twice per
fight), never overlapping the bottom action strip or the onboarding spotlight.

## Research Notes

By the time this task landed, TID-550/551/552/553 had already built most of the
mechanics the original brief assumed didn't exist yet:

- `game_logic/battle/SkillBar.gd` / `scenes/battle/modules/BattleSkillBar.gd` (TID-550):
  a real fixed 3-slot ability bar. **Kick is a real interrupt** — `SkillBar.apply()`'s
  `"interrupt"` effect calls `RealtimeCombat.interrupt_enemy_cast(side)`, which actually
  cancels the enemy's cast (no mana refunded to it, GCD applied) — not flavor text.
- `game_logic/battle/CombatOnboarding.gd` / `scenes/battle/modules/BattleOnboarding.gd`
  (TID-552/553): the real-time onboarding ramp, keyed on `SaveManager.realtime_fights`
  (already exists — this task does **not** add a duplicate field or increment). Its
  `stage` (-1 = graduated to the full fight) is the natural eligibility gate.
- `RealtimeCombat.gd` (TID-546/551) now reports "ally_ready" as a real event (a ready
  Ally waiting for the player's command), so "an ally is ready" needed no proxy.
- `RealtimeVisuals.gd` places the `SidePanel` top-left, the enemy hero token top-right,
  and the action strip + hand at the bottom, leaving top-center genuinely free —
  `MentorBarks` renders there.

Given that, all six requested moments map to a real mechanism (see the table in
`docs/agent/combat-model.md`'s new "Mentor coaching barks & post-fight tip" section) —
no approximation or proxy needed, unlike this task's first draft (written against an
older checkout of this branch that hadn't merged TID-550–553 yet).

## Plan

1. Pure `game_logic/battle/BarkRules.gd`: rate limit (`MIN_INTERVAL_S` = 8, `MAX_PER_LINE`
   = 2), start delay, `is_eligible(active_companion, onboarding_stage)`, line text.
2. `scenes/battle/modules/MentorBarks.gd`: built by `BattleRealtime.maybe_start()` only
   when eligible (right after `onboarding.begin()`, so `onboarding.stage` is known). Owns
   the per-fight clock/seen-counts, builds candidates each frame from `RealtimeCombat`
   events + `BattleSkillBar.bar` cooldown transitions + hero state, plus a `queue()` inbox
   for the interrupt moment reported out of band by `BattleSkillBar`. Renders a fading
   portrait + label bubble top-center.
3. `BattleSkillBar._resolve()` reports every successful ability use to
   `BattleRealtime.note_skill_used(effect)`, which queues `"interrupt"` on a real `Kick`.
4. `BattleRealtime._process` forwards `(dt, events)` to `mentor_barks.on_frame` right
   after `rt.advance()`.
5. Unit tests for `BarkRules`; a `realtime_battle_smoke` scenario with Maiteln equipped
   proving the module builds and runs a full fight without a SCRIPT ERROR.
6. `test_scene_module_guardrail`'s reviewed-`self` allow-list needs one more entry:
   `MentorBarks.new(_battle, self)` (BattleRealtime handing itself to its own coaching
   module), the same pattern already allow-listed for `BattleOnboarding`.

## Changes Made

- `game_logic/battle/BarkRules.gd` (+ `.uid`): pure rate-limit/eligibility/line-text rules.
- `scenes/battle/modules/MentorBarks.gd` (+ `.uid`): the bark module (see Plan). Uses the
  existing Maiteln portrait (`assets/textures/characters/npc_maiteln.png`), built through
  `UiUtil` factories, no bare `add_child` (module guardrail).
- `scenes/battle/modules/BattleRealtime.gd`: `mentor_barks` field, built in `maybe_start()`
  right after `onboarding.begin()`; `note_skill_used(effect)`; `_process` forwards frame
  data to `mentor_barks.on_frame`.
- `scenes/battle/modules/BattleSkillBar.gd`: `_resolve()` calls `_realtime.note_skill_used`
  on every successful ability use.
- `tests/unit/test_scene_module_guardrail.gd`: allow-listed `_MentorBarks.new(_battle, self)`.
- `tests/unit/test_bark_rules.gd` (10 tests).
- `tests/realtime_battle_smoke.gd`: added a third scenario (Maiteln equipped, fresh
  player) proving `mentor_barks` builds and the fight runs clean.
- Also touched (shared with TID-559, see that task): `BattleRealtime.gd`'s `_process` and
  `fight_stats` wiring; `FightStats.gd` owns the event-feeding logic to keep
  `BattleRealtime.gd` under the 500-line lint ceiling (it was already at 426 lines before
  either task).

## Documentation Updates

- `docs/agent/combat-model.md`: new "Mentor coaching barks & post-fight tip" subsection
  (covers both TID-558 and TID-559, landed together).
- `CLAUDE.md`: `BattleRealtime.gd` module-table row now mentions `MentorBarks.gd` /
  `BarkRules.gd` (TID-558) and `FightStats.gd` (TID-559).

## Validation

- `godot --headless --editor --quit` parse/compile check: clean.
- `bash scripts/unsafe-hits.sh`: clean.
- `gdlint` on every changed/added `.gd`: clean.
- `godot --headless --path . -s tests/runner.gd`: full suite passes, 0 SCRIPT ERROR
  (includes the new `test_bark_rules` suite and the updated guardrail allow-list).
- `tests/world_scene_smoke.gd`, `tests/realtime_battle_smoke.gd` (all three scenarios),
  `tests/in_world_battle_smoke.gd`: all PASS, 0 SCRIPT ERROR.
