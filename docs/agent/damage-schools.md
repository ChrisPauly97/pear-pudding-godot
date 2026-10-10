# Damage Schools & Matchups (GID-181)

Breadth as progression: a hit has a **school**, a target has a **school profile**, and one pure
table turns the pair into a damage multiplier. The card you bring for a matchup matters more
because the school lives on the card. TID-748 added the module and its knobs only. No damage
event calls it yet, so no gameplay number has moved.

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

## Integrations

- **CombatTuning:** the three knobs above. Knob reads go through `tune.get_f(...)`.
- **MagicTypes:** the source of truth for magic type names and validity.
- **Planned (later GID-181 tasks):** the single resolver (TID-749) calls `mult`/`scale` at every
  damage site; enemy profiles (TID-750); enemy attack schools and hero resistances (TID-751); combat
  UI feedback (TID-752); bestiary reveal (TID-753); player school sources (TID-754); balance sim
  sweeps (TID-757).

## Asset Requirements

None. Pure logic, no art or audio.

## Tests

`tests/unit/test_damage_schools.gd` (auto-discovered by `tests/runner.gd`). Covers school lookup,
tag precedence, knob overrides, and rounding of scaled damage.
