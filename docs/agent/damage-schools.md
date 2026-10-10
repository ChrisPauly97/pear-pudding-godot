# Damage Schools & Matchups (GID-181)

Breadth as progression: a hit has a **school**, a target has a **school profile**, and one pure
table turns the pair into a damage multiplier. The card you bring for a matchup matters more
because the school lives on the card. TID-748 added the module and its knobs. TID-749 added the
single damage resolver that every damage event now goes through. With empty profiles (the default
until TID-750 / TID-751) no gameplay number moves.

## Key Features

- **Schools:** `physical` plus the four magic types from `MagicTypes` (`light`, `dark`, `verdant`,
  `rift`). The magic type list is read from `MagicTypes`, never re-listed.
- **Profiles:** a target lists schools it **resists**, is **weak** to, or is **immune** to.
- **Three knobs** in `CombatTuning` (the one tuning table): `resist_mult` 0.5, `weak_mult` 1.5,
  `immune_mult` 0.0. The in-battle tuning panel edits them live under the "Damage schools" group.
- **Pure:** `game_logic/battle/DamageSchools.gd` is a RefCounted with no autoloads or scene tree,
  so the balance sim and `-s` tests load it directly.

## How It Works

Module: `game_logic/battle/DamageSchools.gd` (`const _DamageSchools = preload(...)`).

| Function | Returns |
|---|---|
| `all_schools() -> Array[String]` | `physical` first, then `MagicTypes.all_types()` |
| `is_school(school) -> bool` | whether the string is a known school |
| `school_of(card: Variant) -> String` | the card's `magic_type` if valid, else `physical`. Takes a `CardInstance`, any Object with a `magic_type` property, or a template Dictionary |
| `outcome(school, profile) -> String` | `"immune"`, `"resist"`, `"weak"` or `""` (neutral) |
| `mult(school, profile, tune = null) -> float` | the knob for that outcome, else `1.0`. `tune` null uses defaults |
| `scale(damage, school, profile, tune = null) -> int` | `damage * mult`, rounded to nearest; a zero multiplier gives 0; a positive hit is never below 1; non-positive damage gives 0 |

Profile shape (any key may be absent):

```gdscript
{"resist": {"dark": true}, "weak": {"light": true}, "immune": {"rift": true}}
```

Precedence when one school is tagged more than once: **immune > resist > weak**.

Schools for cards: a card's school is its `magic_type` (from its `data/cards/*.tres`). Cards with
no magic type (plain minions, Strike, Kick, Mend) are `physical`. `TechniqueDefs` has no separate
school field: technique cards already carry `magic_type` in their `.tres`, so `school_of` covers
them.

## Damage resolver (TID-749)

Module: `game_logic/battle/DamageResolver.gd`. Every production damage event goes through it.
Raw `take_damage` lives only on HeroState and CardInstance.

| Function | Returns |
|---|---|
| `deal(defender: PlayerState, target, amount, school, tune = null)` | `{"dealt": int, "outcome": String}`. Scales `amount` by the defender's profile, applies it with the target's `take_damage` (armor and shroud still soak), and reports the HP actually lost plus the outcome for UI |
| `scaled_amount(defender, amount, school, tune = null) -> int` | the scaled amount for HP loss that skips armor (the Curse arm in SpellEffectResolver) |
| `profile_of(defender) -> Dictionary` | `defender.school_profile`, or `{}` for a null side |

- **Profile seam:** `PlayerState.school_profile: Dictionary = {}`, one per defending side. TID-750
  fills enemy sides at battle setup from the enemy type, and TID-751 fills player sides. It is
  not serialized, so it is re-derived at setup.
- **School per source:** a card hits as `DamageSchools.school_of(card)`: spells, minion swings,
  emergence damage, and counterattacks (the struck card's school). Hero swings and hero counters,
  heavy blows, poison and burn ticks, desert scorch, fatigue and environmental damage use
  `DamageSchools.PHYSICAL`. Statuses have no school of their own yet.
- **Tune:** real-time sites pass the fight's `CombatTuning` (`rt.tune`). Turn-based sites pass
  null, so the knob defaults apply.
- **Guardrail:** `tests/unit/test_damage_resolver_guardrail.gd` fails if a `take_damage(` call
  appears in production code (`game_logic/`, `scenes/`, `autoloads/`, `ai/`, `tools/`) outside the
  resolver and the raw definitions. Tests are excluded, since unit fixtures set HP directly.

Damage sites routed: SpellEffectResolver (emergence and all spell arms), RealtimeCombat (swings,
poison, scorch, heavy blow), BattleInput and BattleNet (attacks and counters), BattleFx (status
ticks), BattleModifiers (desert scorch), BasicAI (AI attacks), PlayerState (fatigue).

## Integrations

- **CombatTuning:** the three knobs above. Knob reads go through `tune.get_f(...)`.
- **MagicTypes:** the source of truth for magic type names and validity.
- **Planned (later GID-181 tasks):** enemy profiles (TID-750); enemy attack schools and hero
  resistances (TID-751); combat UI feedback (TID-752); bestiary reveal (TID-753); player school
  sources (TID-754); balance sim sweeps (TID-757).

## Asset Requirements

None. Pure logic, no art or audio.

## Tests

`tests/unit/test_damage_schools.gd` (auto-discovered by `tests/runner.gd`). Covers school lookup,
tag precedence, knob overrides, and rounding of scaled damage.

`tests/unit/test_damage_resolver.gd`: neutral behaviour with empty profiles, resist / weak / immune
scaling, armor and shroud, null defender, knob overrides. `tests/unit/test_damage_resolver_guardrail.gd`:
the `take_damage(` source scan.
