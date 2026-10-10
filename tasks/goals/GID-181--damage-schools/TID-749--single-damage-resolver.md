# TID-749: Single school-aware damage resolver

**Goal:** GID-181
**Type:** agent
**Status:** done
**Depends On:** TID-748

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

School multipliers must apply everywhere damage happens, identically in turn-based, real-time, PvP/co-op and the balance sim. Today damage is applied directly in ~30 places, so a per-site bolt-on would drift.

## Research Notes

- `take_damage` call sites (grep): `scenes/battle/SpellEffectResolver.gd` (12 — `resolve_spell` L168, `resolve_enemy_play` L50, `resolve_emergence`), `game_logic/battle/RealtimeCombat.gd` (6 — `_resolve_swing` ~L664 already applies `BattlefieldRules.modify_damage` + `_gap_scaled` + crit; poison ticks L373/396; heavy L799), `scenes/battle/modules/BattleInput.gd` (4), `scenes/battle/net/BattleNet.gd` (4), `scenes/battle/BattleFx.gd` (2), `game_logic/battle/PlayerState.gd` (1), `BattleModifiers.gd` (1).
- Balance sim runs through `SpellEffectResolver` (BalanceBot.act takes one) and RealtimeCombat, so covering those covers the sim.
- Approach: one pure entry, e.g. `DamageSchools.apply(target, amount, school, source_side, state)` or a `GameState.deal_damage(...)` that resolves the target's profile (enemy hero/units → enemy type profile on GameState; player side → hero resist from TID-751, stub {} now) and returns `{dealt, outcome}` for UI. Keep `take_damage` as the raw HP op.
- Poison/burn DoTs: carry the school of the card that applied them, or treat as the status's own school — decide in Plan and document.
- GameState needs the enemy type id (check what BattleSetup.configure stores) to look up the profile; profile itself arrives in TID-750 — default {} = neutral, so this task is behaviour-neutral. Verify with balance bands unchanged (`tests/balance_bands.gd`).
- Add a guardrail test that greps for new direct `take_damage(` calls outside the resolver (pattern: test_hud_registry_guardrail.gd).
- Run `scripts/unsafe-hits.sh`, world/battle smoke tests and PvP smoke tests after (CLAUDE.md → Scene Modules).

## Plan

1. `game_logic/battle/DamageResolver.gd` (new, pure RefCounted): `deal(defender: PlayerState, target: Variant, amount, school, tune = null) -> {dealt, outcome}` is the one entry. It reads the defender's profile, applies `DamageSchools.scale`, calls the target's raw `take_damage` (armor/shroud unchanged), and reports HP actually lost plus the outcome. `scaled_amount(defender, amount, school, tune)` covers the one non-`take_damage` HP op (curse).
2. Profile seam: `PlayerState.school_profile: Dictionary = {}` on the defending side (not a GameState field). The resolver needs no GameState, and fatigue in `PlayerState.draw_card` has no GameState to ask. TID-750 fills enemy sides at setup, TID-751 fills player sides. Not serialized.
3. Route every production `take_damage(` call through `deal`: SpellEffectResolver (emergence, all spell arms), RealtimeCombat (`_resolve_swing` for minion and hero swings, poison ticks, scorch, heavy blow), BattleInput and BattleNet attacks + counters, BattleFx status ticks, BattleModifiers desert scorch, BasicAI attacks, PlayerState fatigue.
4. School per source: a card hits as `DamageSchools.school_of(card)` (spells, minion attacks, emergence). Hero swings, heavy blows, poison/burn ticks, scorch, fatigue and environmental damage use `PHYSICAL`. Poison and burn carry physical for now. Give statuses a school later if needed.
5. Tune: real time passes `rt.tune`. Turn-based sites pass null (defaults). Documented, not wired further.
6. Guardrail `tests/unit/test_damage_resolver_guardrail.gd`: a source scan of production dirs fails on any `take_damage(` outside the allow-list (resolver + HeroState/CardInstance definitions). Tests are excluded, since unit fixtures set HP directly.
7. Behaviour tests `tests/unit/test_damage_resolver.gd`. Empty profile is neutral; scaling, armor, shroud, null defender, knob overrides.
8. Balance bands and smoke tests must pass unchanged, since all profiles are empty.
9. Skipped: moving SpellEffectResolver out of `scenes/` (BID-097). Not trivial, so it stays a backlog item.

## Changes Made

- `game_logic/battle/DamageResolver.gd` (new): `deal(defender, target, amount, school, tune = null) -> {"dealt": int, "outcome": String}`, `scaled_amount(defender, amount, school, tune = null) -> int`, `profile_of(defender) -> Dictionary`. Typed branches for HeroState and CardInstance, so no unsafe access.
- `game_logic/battle/PlayerState.gd`: `school_profile: Dictionary = {}` (per defending side); fatigue goes through `DamageResolver.deal`.
- `game_logic/battle/RealtimeCombat.gd`: `_resolve_swing` (minion and hero hits, school from the attacker), poison ticks, scorch, and heavy blow route through `deal`. `_tick_hero_status` now takes the PlayerState.
- `scenes/battle/SpellEffectResolver.gd`: emergence and every spell arm use `deal` with `school_of(card)`. The curse `health -=` hit uses `scaled_amount` (it skips armor by design, so it stays a direct HP op).
- `scenes/battle/modules/BattleInput.gd`, `scenes/battle/net/BattleNet.gd`: attacks and counterattacks, school of each attacker/target, plus hero hits.
- `scenes/battle/BattleFx.gd`: poison/burn ticks on cards and heroes (`_tick_statuses_on_hero` takes the owner as a third arg).
- `scenes/battle/modules/BattleModifiers.gd`: desert scorch. `ai/BasicAI.gd`: AI attacks.
- `tests/unit/test_damage_resolver.gd` (new): neutral behaviour, resist/weak/immune, outcome, knob overrides, null defender, scaled_amount.
- `tests/unit/test_damage_resolver_guardrail.gd` (new): fails on any `take_damage(` in production code outside the resolver and the raw definitions.

Deviations from the task text:
- The profile seam is `PlayerState.school_profile`, not a GameState field. Each damage site already has its defending PlayerState, and fatigue in PlayerState has no GameState.
- Base: TID-748 (97e9da9) was not on `main`. It is on `origin/ccr-1880dcfb-mgp29a`, so this worktree was fast-forwarded to that branch before the work.
- `BattleConsumables` has no `take_damage` any more, so there is nothing to route there.
- The guardrail excludes `tests/`, since unit fixtures set HP through `take_damage`.

Validation: parse check clean; `scripts/unsafe-hits.sh` no hits; gdlint clean on changed files; `tests/runner.gd` exit 0 with 0 SCRIPT ERROR; `tests/balance_bands.gd` RESULT: PASS.

## Documentation Updates

- `docs/agent/damage-schools.md`: new "Damage resolver" section (entry point, profile seam, school per source, tune and sites), the Integrations list, and the Tests list.
