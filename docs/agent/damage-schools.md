# Damage Schools & Matchups (GID-181)

Breadth as progression: a hit has a **school**, a target has a **school profile**, and one pure
table turns the pair into a damage multiplier. The card you bring for a matchup matters more
because the school lives on the card. TID-748 added the module and its knobs. TID-749 added the
single damage resolver that every damage event now goes through. TID-750 gave every enemy type a
profile, and TID-751 wires them in at battle setup, so school matchups now move fights. The player
side gets hero school resistances (`HeroState.school_resist`); no source feeds them yet (TID-754).

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

## Enemy School Profiles (TID-750)

Every enemy type in `autoloads/EnemyRegistry.gd` (`_ensure_loaded()`) has a `schools` entry: the
schools it **resists** and is **weak** to. Lore and biome set the themes:

- **Undead** (undead, ghouls, spectres, the Barrow King, the Hollow Steward) resist `dark` and are weak
  to `light`. The scorched revenant and the Warlord are also weak to `verdant` and `rift` respectively.
- **Forest and bog creatures** (wolves, bog hags, forest shades, the imbued stag, the mimic's wood)
  resist `verdant`.
- **Living beasts** (wolves, the cactus worm, the imbued stag) are weak to `dark`, which drains life.
  Humans lean the same way (duelists, the ember cultist), except the Martarquas raiders, who are weak to `physical`.
- **Rift-touched** (rift echo, duelist novice and champion, ember cultist) resist `rift`; the rift echo is weak to `light`.
- **Armoured, spectral or wild** (stone golem, cactus worm, scarab swarm, frost wendigo, wraiths,
  the Martarquas vanguard) resist `physical`. Forest shades resist only `verdant` (TID-751 tune: the
  physical resist made them a wall to a physical starter deck, 0 % one level up).
- **Biome rosters** (`BiomeDef.ENEMY_POOLS`) mix profiles so every school has a weak target.

Bosses with a phase 2 deck may add `schools_phase2`, a full replacement profile used at phase 2.
That is the only place `immune` appears (Barrow King: phase 2 is immune to `dark`).

Accessor: `EnemyRegistry.get_school_profile(type_id: String, phase: int = 1) -> Dictionary`. It
returns `{"resist": {...}, "weak": {...}, "immune": {...}}` with every key present (possibly
empty). Unknown ids give an all-empty, neutral profile. Pure static data, so chunk-gen worker
threads can read it.

| Enemy | Resists | Weak to | Phase 2 immune |
|---|---|---|---|
| `undead_basic` | dark | light | - |
| `undead_horde` | dark | light | - |
| `undead_elite` | dark | light, rift | - |
| `ghoul_pack` | dark | light, verdant | - |
| `wraith` | physical, dark | light, rift | - |
| `forest_shade` | verdant | light, rift | - |
| `sand_stalker` | dark | physical | - |
| `cactus_worm` | physical, verdant | dark | - |
| `imbued_stag` | verdant | dark | - |
| `scorched_revenant` | dark | light, verdant | - |
| `mountain_troll` | rift | light, physical, dark | - |
| `stone_golem` | physical, light | verdant, rift | - |
| `hollow_steward` | dark | light | - |
| `martarquas_vanguard` | physical | light, dark | - |
| `training_dummy` | dark | verdant | - |
| `duelist_novice` | rift | dark | - |
| `duelist_adept` | light | dark | - |
| `duelist_champion` | light, rift | dark | - |
| `roaming_terror` | rift | light | - |
| `martarquas_raider_1` | dark | physical | - |
| `martarquas_raider_2` | dark | physical | - |
| `martarquas_raider_3` | dark, physical | light | - |
| `martarquas_warleader` | dark | physical, light | - |
| `wolf_pack` | verdant | dark, physical | - |
| `bog_hag` | verdant, dark | - | - |
| `martarquas_scout` | dark | verdant | - |
| `scarab_swarm` | physical | verdant, rift | - |
| `ember_cultist` | rift | physical, dark | - |
| `frost_wendigo` | physical | light | - |
| `rift_echo` | rift | light | - |
| `barrow_king` | dark | light | dark |
| `rival_isfig_1` | rift | dark | - |
| `rival_isfig_2` | rift | dark, physical | - |
| `rival_isfig_3` | light, rift | dark | - |
| `spectre_wisp` | dark | light | - |
| `spectre_haunt` | dark, physical | light, rift | - |
| `spectre_dread` | dark, physical | light | - |
| `mimic` | verdant | rift | - |
| `blight_heart` | dark | light, verdant | - |

**Guardrails** (`tests/unit/test_enemy_school_profiles.gd`): every enemy has a non-empty profile;
all school names come from `DamageSchools.all_schools()`; no profile resists or immunes every school;
immunity only appears in a boss's phase 2 (with a phase 2 deck); a non-boss's phase 2 equals its
phase 1; each biome roster has at least one weak target per school and no school resisted by the
whole roster (sampled through `type_for_biome`); and the same for the whole roster.

## Damage resolver (TID-749)

Module: `game_logic/battle/DamageResolver.gd`. Every production damage event goes through it.
Raw `take_damage` lives only on HeroState and CardInstance.

| Function | Returns |
|---|---|
| `deal(defender: PlayerState, target, amount, school, tune = null)` | `{"dealt": int, "outcome": String}`. Scales `amount` by the defender's profile, applies it with the target's `take_damage` (armor and shroud still soak), and reports the HP actually lost plus the outcome for UI |
| `scaled_amount(defender, amount, school, tune = null) -> int` | the scaled amount for HP loss that skips armor (the Curse arm in SpellEffectResolver) |
| `profile_of(defender) -> Dictionary` | `defender.school_profile`, or `{}` for a null side |

- **Profile seam:** `PlayerState.school_profile: Dictionary = {}`, one per defending side. Enemy
  sides are filled at battle setup (see TID-751 below). It is not serialized: a resumed fight
  re-derives it from the saved enemy type. The player side keeps its profile empty; hero resists
  apply through `HeroState.school_resist` instead (see below).
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

## Enemy Attack Schools and Hero Resistances (TID-751)

**Enemy profiles go live at battle setup.** `BattleSetup.setup_enemy` sets
`enemy.school_profile = EnemyRegistry.get_school_profile(type, 1)`. That one call covers the solo
scene and the balance sim. `BattleScene._check_boss_phase2` swaps the enemy side to the phase 2
profile when a boss turns. A resumed fight saves `_enemy_type` in the battle dict and re-derives
the profile (phase 2 if `_boss_phase2` is set). Co-op and PvP enemies (other players) get no profile.

**Enemy attack school.** `EnemyRegistry.get_attack_school(type)` reads an optional `attack_school`
per type (default `physical`). It is set on: undead and dark spectres (`dark`), forest shades, bog
hags, imbued stags and mimics (`verdant`), and rift echoes, roaming terrors, ember cultists and the
Isfig rivals (`rift`). `BattleSetup.configure_realtime` copies it to `RealtimeCombat.enemy_attack_school`.
Enemy hero swings (`_resolve_swing` with no attacker, from the enemy side) and heavy blows
(`_land_heavy`) hit as that school. Enemy minions already hit as their card's school (TID-749).

**Hero school resistances.** `HeroState.school_resist: Dictionary` maps school → fraction of damage
soaked (0..`max_player_resist`, default 0.75 per school). It is serialized (`to_dict` / `from_dict`).
`BattleModifiers._apply_school_resists` fills it at solo battle start from `_school_resist_sources()`,
which returns `{}` for now; TID-754 feeds gear, skill and companion sources there.
`DamageSchools.capped_resists` drops unknown schools and clamps each fraction.

- **Why a fraction and not tags:** the player side's `school_profile` stays empty. Resist tags would
  apply the `resist_mult` knob on top of the fraction and double-count. `DamageResolver.scaled_amount`
  multiplies the profile result by `1 - fraction`, and `deal` reports `"resist"` for a school that
  only a hero resistance touches. A profile tag and a fraction stack, as in the test
  `test_hero_resist_stacks_with_a_weak_profile`.
- **Knob:** `CombatTuning` `max_player_resist` (Damage schools group, live in the tuning panel).

**Balance (TID-751 run).** Win rates (same level / one level up), before the profiles → after:

| Cell | Before | Wired, untuned | After tuning |
|---|---|---|---|
| `forest_shade` 6 | 100 / 100 | 95 / 0 | 100 / 100 |
| `bog_hag` 7 | 100 / 77.5 | 100 / 100 | 100 / 77.5 |
| `wolf_pack` 5 | 100 / 100 | 100 / 100 | 100 / 100 (median 30.1 s → 19.9 s at +0) |

The other cells were unchanged. The one-level-up mean was 74 % untuned, 86 % with forest shade fixed
and bog hag not yet, and 83 % after both tunes (band 65–85 %). Forest shade lost its physical resist
(it made a physical starter deck a wall); bog hag lost its physical weakness (it made the same deck
too strong). Baseline regenerated with `--write-baseline` (measured at `b320079`); only the two
wolf pack medians changed.

## Integrations

- **CombatTuning:** the three matchup knobs and `max_player_resist`. Knob reads go through `tune.get_f(...)`.
- **MagicTypes:** the source of truth for magic type names and validity.
- **Planned (later GID-181 tasks):** combat UI feedback (TID-752); bestiary reveal (TID-753); player
  school sources that feed `_school_resist_sources` (TID-754); weather and biome boosts (TID-755);
  matchup loadouts (TID-756); balance sim sweeps (TID-757).

## Asset Requirements

None. Pure logic, no art or audio.

## Tests

`tests/unit/test_damage_schools.gd` (auto-discovered by `tests/runner.gd`). Covers school lookup,
tag precedence, knob overrides, and rounding of scaled damage.

`tests/unit/test_enemy_school_profiles.gd` (TID-750) is the guardrail for the enemy profile table: every
enemy has one, no profile resists or immunes every school, immunity only in boss phase 2, and each biome
roster has a weak target for every school.

`tests/unit/test_damage_resolver.gd`: neutral behaviour with empty profiles, resist / weak / immune
scaling, armor and shroud, null defender, knob overrides. `tests/unit/test_damage_resolver_guardrail.gd`:
the `take_damage(` source scan.

TID-751 adds: hero resist scaling and stacking with profiles, `capped_resists` clamping, and the
`school_resist` round-trip (`test_damage_resolver.gd`); enemy attack schools are valid, undead and forest
types strike with their school, and `setup_enemy` fills the enemy profile (`test_enemy_school_profiles.gd`).
The balance bands (`tests/balance_bands.gd`) are the absolute check on the profile tuning.
