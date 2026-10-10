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
  forest shades, the Martarquas vanguard) resist `physical`.
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
| `forest_shade` | verdant, physical | light, rift | - |
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
| `bog_hag` | verdant, dark | physical | - |
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

`tests/unit/test_enemy_school_profiles.gd` (TID-750) is the guardrail for the enemy profile table: every
enemy has one, no profile resists or immunes every school, immunity only in boss phase 2, and each biome
roster has a weak target for every school.
