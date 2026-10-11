# Damage Schools & Matchups (GID-181)

Breadth as progression: a hit has a **school**, a target has a **school profile**, and one pure
table turns the pair into a damage multiplier. The card you bring for a matchup matters more
because the school lives on the card. TID-748 added the module and its knobs. TID-749 added the
single damage resolver that every damage event now goes through. TID-750 gave every enemy type a
profile, and TID-751 wires them in at battle setup, so school matchups now move fights. The player
side gets hero school resistances (`HeroState.school_resist`), and TID-754 feeds them, plus outgoing
school power, from skill nodes, gear affixes and a weapon convert (see "Player School Sources" below).

## Key Features

- **Schools:** `physical` plus the four magic types from `MagicTypes` (`light`, `dark`, `verdant`,
  `rift`). The magic type list is read from `MagicTypes`, never re-listed.
- **Profiles:** a target lists schools it **resists**, is **weak** to, or is **immune** to.
- **Knobs** in `CombatTuning` (the one tuning table): `resist_mult` 0.5, `weak_mult` 1.5,
  `immune_mult` 0.0 for magic schools; physical has its own milder pair, `physical_resist_mult` 0.8 and
  `physical_weak_mult` 1.15 (GID-186: physical is every kit's base channel — auto-attacks, Strike, Allies — so a
  physical tag moved a whole fight, 0 % walls and 100 % walkovers). The in-battle tuning panel edits them live
  under the "Damage schools" group; spell hits read the fight's tuning too (`SpellEffectResolver.tune`, GID-186 —
  before it they always used the defaults).
- **Pure:** `game_logic/battle/DamageSchools.gd` is a RefCounted with no autoloads or scene tree,
  so the balance sim and `-s` tests load it directly.
- **Player sources (TID-754):** skill-tree school nodes, gear school affixes and the weapon convert feed
  outgoing school power and hero resistances. Nothing is on by default.

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

## Battlefield School Boosts (TID-755)

The field lends schools a small edge, read from the same battlefield facts the rules already use.
Module: `game_logic/battle/BattlefieldRules.gd`, table `SCHOOL_ENV` (same row shape as
`BRANCH_AFFINITY`; both use the shared `_condition_met(kind, value, biome, weather, is_night)`).

| School | Condition | Knob (default) |
|---|---|---|
| `dark` | night | `env_time_mult` x1.15 |
| `light` | day | `env_time_mult` x1.15 |
| `verdant` | Forest biome | `env_biome_mult` x1.1 |
| `rift` | Scorched biome | `env_biome_mult` x1.1 |
| `physical` | Mountains biome | `env_biome_mult` x1.1 |
| `verdant` | rain, heavy rain | `env_weather_mult` x1.1 |
| `rift` | ash fall, volcanic | `env_weather_mult` x1.1 |
| `light` | snow, blizzard | `env_weather_mult` x1.1 |
| `physical` | sandstorm, dust devil | `env_weather_mult` x1.1 |

Every matching row multiplies in (Forest in the rain: verdant x1.21). Day always boosts light,
so a battle is never fully neutral by time. WeatherManager has no "storm" weather; the storm-like
rows use the rain, ash and sand weathers.

| Function | Returns |
|---|---|
| `school_env_mult(school, biome, weather, is_night, tune = null) -> float` | product of the matching rows for one school; 1.0 when none |
| `school_env_table(biome, weather, is_night, tune = null) -> Dictionary` | `{school: mult}` for every non-neutral school |
| `school_env_text(biome, weather, is_night) -> String` | banner line, e.g. `"Light x1.15"` |

- **Stored once at battle start:** `BattleModifiers._apply_school_environment()` (called from
  `BattleScene` right after `set_battlefield_context`) computes the table from the battle's biome,
  `_battle_weather` and night, and copies it to each `PlayerState.env_school_mult`. Both sides get the
  same table, so the boost follows the **attacker's school** whichever side is hit. Not serialized.
- **Resolver:** `DamageResolver.scaled_amount` (which `deal()` uses) multiplies the matchup mult by
  `env_mult(defender, school)` and rounds once through `DamageSchools.apply_mult`. Armor, shroud and
  immunity are unchanged: an immune hit stays at 0.
- **Knobs:** read at battle start with `CombatTuning` defaults (`BattlefieldRules._env_knob`). Live
  edits in the tuning panel apply to the next battle, not the current one.
- **Banner:** `BattleArena._show_battlefield_banner` adds a "Schools: ..." line under the rule text.
- **Balance sim:** `BalanceFight` / `tools/balance_sim.gd` never call `_apply_school_environment`, so
  sim fights stay neutral and the bands do not move. Opt in only by calling it deliberately.
- **Known gap:** a battle resumed from a mid-fight save does not re-run the setup path, so its
  `env_school_mult` is empty (neutral) and the weather part cannot be restored (weather is not saved).
  Logged as `tasks/backlog/BID-100--env-school-boost-resume.md`. The TID-754 player sources
  (`school_power`, `convert_school`, hero resists) share that gap: a resumed fight has none of them.

## Combat feedback (TID-752)

Players see why a hit was big or small. Three presentation pieces, all reading the same record.

- **Last-hit record.** `DamageResolver.deal` calls `note_hit(school, outcome)` on the target
  (`HeroState` or `CardInstance`) before applying damage. Each unit keeps `hit_school`,
  `hit_outcome` and `hit_serial` (+1 per hit, so a 0-damage immune hit is still an event). The
  three fields are in `to_dict` / `from_dict`, so they ride the battle state mirror to PvP and
  co-op viewers with no protocol change.
- **Pure rules:** `game_logic/battle/SchoolFeedback.gd` (no autoloads, unit-tested).
  `school_color(school)` is the MagicTypes colour, neutral off-white for physical.
  `outcome_word` gives "Weak!" / "Resisted" / "Immune". `damage_text(amount, outcome)` gives
  "-7 Weak!", "-3 Resisted" or "Immune". `pips_for(profile)` lists one entry per tagged school in
  `all_schools()` order. `pip_tooltip(school, outcome)` states the multiplier.
  `hit_record(unit)` reads the record above.
- **Damage numbers:** `BattleFx.spawn_float_labels` (every turn-based and real-time HP loss, PvP
  viewers included, since they run the same snapshot diff) colours and suffixes each loss from the
  unit's record. A unit that died this action is read from the snapshot's `unit` reference, and
  only if it took a new hit (serial advanced), so a stale outcome never leaks onto a label. An
  immune unit that lost no HP gets an "Immune" label when its serial advanced. The real-time
  heavy blow reads the `outcome` that `RealtimeCombat._land_heavy` gets from `deal()`.
- **Enemy pips:** `scenes/battle/modules/SchoolPips.gd` builds a chip row under each enemy's hero
  strip in `RealtimeVisuals` (the real-time token, for the base enemy and joined enemies). Weak =
  filled chip in the school colour, Resists = dark with a coloured rim, Immune = thick rim.
  Hover shows the tooltip on desktop; a tap calls `toast()` with the same line, which is the
  mobile path. `known_profile(enemy_type, entry)` is the one accessor: the enemy's
  `EnemyRegistry.get_school_profile` gated on its bestiary entry (TID-753, below). `build` takes
  the same entry as its second argument. The pips come from the enemy type, so PvP players (no
  enemy type) show none.

Turn-based enemy strips get no pips yet; they are not in the real-time token.

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

## Bestiary School Knowledge (TID-753)

Knowledge is progression. What a player sees of an enemy's schools depends on its bestiary entry
(`SaveManager.bestiary[type] = {seen, defeated}`, read through `get_bestiary_entry`). No new save
field: the rule derives everything from the two counters.

| Knowledge | Rule |
|---|---|
| Attack school | `seen >= 1` |
| Weak and resist profile | `defeated >= 1` (the whole profile, at once) |

Module: `game_logic/battle/SchoolKnowledge.gd` (pure, unit-tested). `attack_school_known`,
`profile_known`, `known_attack_school(attack, entry)` ("" when unknown), `known_profile(profile,
entry)` (empty until defeated, else a copy), and `journal_view(attack, profile, entry)` (the gated
Journal data). `SchoolFeedback.bestiary_lines(attack, profile, entry)` turns that view into the
Journal's BBCode text. `SchoolFeedback.school_bbcode(school)` is one colour-dot chip plus name.

- **Battle pips:** `SchoolPips.known_profile(enemy_type, entry)` gates the enemy profile on
  `profile_known`, so a seen-but-not-defeated enemy shows no pips. `RealtimeVisuals` passes
  `SaveManager.get_bestiary_entry(enemy_type)` into `SchoolPips.build`.
- **Floating labels stay always-on:** the Weak! / Resisted / Immune damage text is never gated
  (that is how a player learns the matchup). Only the pre-fight pips and the bestiary read the rule.
- **Journal:** the bestiary tab's tier 1 and tier 2 detail gain an "Attack school" row and
  "Weak to" / "Resists" rows, with "?" for anything not yet learned. Immunity is phase-2 only and
  is not listed on the page.
- **Not built:** revealing one school on a Weak! / Resisted hit (would need a new persisted field).

## Player School Sources (TID-754)

The player's side of the school system. Each source is a card-centric choice, not a flat stat bar,
and each one stacks on top of the normal item-level stat rolls rather than replacing them.

| Source | Feeds | Where it is read |
|---|---|---|
| Skill node `school_power` (filter = school, value = %) | `PlayerState.school_power[school]` (fraction) | `BattleSetup.apply_school_power` |
| Skill node `school_resist` (filter = school, value = %) | `HeroState.school_resist[school]` | `BattleModifiers._school_resist_sources` |
| Gear affix `school_dmg` `{school, pct}` | `PlayerState.school_power[school]` | `BattleSetup.apply_school_power` |
| Gear affix `school_resist` `{school, pct}` | `HeroState.school_resist[school]` | `BattleModifiers._school_resist_sources` |
| Gear affix `convert` `{school}` (weapon only) | `PlayerState.convert_school` | `PlayerState.weapon_school()` |

- **Outgoing power (attacker side).** `DamageResolver.deal` and `scaled_amount` take an optional
  trailing `attacker: PlayerState = null`. The resolver multiplies by `power_mult(attacker, school)`
  (= 1 + the school's fraction, never below 0), so the result is
  `amount x matchup x battlefield boost x (1 - hero resist) x (1 + attacker power)`, rounded once.
  Call sites that pass the attacker: spells (`SpellEffectResolver`, every player-side arm and the
  emergence hit, with the caster), real-time swings (`RealtimeCombat._resolve_swing`, from the
  attacking side) and local attacks (`BattleInput._execute_attack`). Enemy sides and the PvP replay
  (`BattleNet`) have no sources, so they pass nothing and stay neutral.
- **Convert.** `PlayerState.weapon_school()` is the school a hero's own auto-attack hits as, and the
  school Strike (`tech_strike`) hits as. Minion attacks and cards keep their own magic type. A
  physical convert is never rolled or accepted.
- **Gear affixes** live on the item's roll: `SaveManager.gear_rolls[id].affix = {kind, school, pct}`.
  `GearRolls.roll(tier, level, rng, weapon)` adds one on a chance by tier (5 / 12 / 20 / 30 %),
  after the rarity draw, so the stat roll is unchanged. Kind weights: `school_dmg` 50, `school_resist`
  35, `convert` 15 (weapons only). Pct: damage 5 + 5 per tier, resist 3 + 3 per tier, in percent of
  the school. `GearRolls.normalize` keeps a well-formed affix and drops anything else, so old saves
  have no affix and need no migration. `SaveGear.roll_for(item, tier, level, rng)` is the drop entry
  point (chests, battle victories, co-op loot); it passes `weapon` from the item's slot.
- **Skill nodes.** Four row-3 nodes, one per Light/Dark branch pair, hang under the column-3 row-2 node
  of their branch (`ember_kindled_light`, `dawn_sunward_ward`, `dusk_umbral_edge`, `bloom_rooted_ward`).
  `SkillMods.school_nodes(ids, effect_type)` sums them per school. They are not card modifiers, so they
  apply in turn-based fights too. Node values are whole percent (10 = 10 %).
- **Stacking.** Affix and node sources for the same school add. Hero resists are summed uncapped, then
  clamped by `DamageSchools.capped_resists` to `max_player_resist`. Outgoing power is not capped (a
  negative total floors at 0).
- **Where they are set.** `BattleModifiers._apply_equipment_effects` builds the equipped items (with
  each roll's affix) and calls `BattleSetup.apply_school_power`, in every solo fight. The headless
  `BattleSetup.build` (balance sim) does the same from its config, so the sim's default config (no
  gear affixes, no nodes) is neutral and the bands do not move.
- **Display.** `GearRolls.affix_label` gives "+15% Dark damage", "+10% Rift resist" or "Strikes as
  Light". It shows under the item name in the CharacterScene gear picker, and after the stats in
  `SaveGear.drop_message` ("Found: Rare Iron Helm (ilvl 5), +10% Rift resist!").
- **Knobs:** the caps stay where they were (`max_player_resist`). The affix chances, kind weights and pct
  tables are data in `GearRolls`, not tuning knobs.

## Matchup Loadouts (TID-756)

Swapping to the right deck before a fight is one tap. The engage prompt and the world offer the
player's saved loadouts (`save_manager.decks`, see `inventory-and-deck.md`) ranked against the enemy's
**known** profile.

- **Pure scorer:** `game_logic/battle/LoadoutMatchup.gd`. `weak_hits(schools, weak)` counts cards whose
  school the enemy is weak to; `resist_hits` counts resisted ones. `rank(entries, weak, resist)` sorts
  loadout entries `{index, name, schools, valid}`: valid first, then most weak hits, then fewer resist
  hits, then index. `best_index(ranked)` is the top valid loadout with at least one weak hit, or -1
  (an unknown profile highlights nothing; an invalid, too-small loadout is never best).
- **Known only:** the weak and resist lists come from `SchoolKnowledge.journal_view` over the enemy's
  bestiary entry, so a seen-but-not-defeated enemy shows "Defeat one to learn its weaknesses" and no star.
- **Row:** `scenes/ui/LoadoutSwapRow.gd` (RefCounted, `attach(parent)`). One button per loadout (the best
  marked with a star and tinted; the active one and too-small ones disabled), and the enemy's weak
  schools as colour chips (`SchoolFeedback.school_color`). Card ids map to schools through
  `DamageSchools.school_of(CardRegistry.get_template(id))`. Tapping a loadout calls
  `save_manager.decks.set_active_loadout(i)`, which syncs `player_deck` before the battle reads it, then
  rebuilds the row. A swap changes only the active loadout, never a battle.
- **Engage prompt:** `GambitPickerOverlay.matchup_enemy_type` (set by `SceneManager._on_enemy_engaged`
  before the overlay enters the tree) shows the row above the gambit list. The picker stays open after a
  swap, so the player still picks a gambit or "No Gambit" to start the fight.
- **Auto-skip (no prompt):** `scenes/world/modules/SwapDeckPrompt.gd` (`swap_deck`, created by
  `WorldScene._ensure_world_modules`). When auto-skip is on and a hostile, not-yet-defeated enemy is within
  `IsoConst.ENEMY_AWARENESS_RANGE`, a "Swap deck" action appears in `WorldHUD.ZONE_CONTEXT` (registered
  through `register_action`, refreshed about every 0.25 s with `set_action_visible`). Tapping it opens the
  row in a `_build_prompt` modal with a Close button. It is off in co-op and outside the plain world state.
- **Engage safety:** the modal holds engage with `SceneManager.hold_engage()` / `release_engage()`
  (a counter read by `accepts_engage()`), so no enemy can start a fight behind it. The hold is released
  when the modal's layer leaves the tree, whichever way it closes. The row never starts a battle, and
  `_enter_battle` still refuses a second one.
- **Controls:** every swap is a button (mouse, touch, keyboard focus); no new key binding.
- **Not built:** tagging a loadout with a school in the deck builder (the research note's optional item).
  A player with an invalid active deck still hits the "Deck too small" refusal before any prompt.

Tests: `tests/unit/test_loadout_matchup.gd` (weak / resist counting, tie-breaks, invalid loadouts,
unknown profile).

## Integrations

- **CombatTuning:** the three matchup knobs, the three boost knobs (`env_time_mult`,
  `env_biome_mult`, `env_weather_mult`) and `max_player_resist`. Knob reads go through `tune.get_f(...)`.
- **Combat UI (TID-752):** `SchoolFeedback` (pure text / colour / pips), `BattleFx` labels, `SchoolPips` on
  the real-time enemy tokens.
- **MagicTypes:** the source of truth for magic type names and validity.
- **Resolver order:** `scaled_amount` = amount x matchup x battlefield boost x (1 - hero resist) x (1 + attacker power), rounded once.
- **Balance sim (TID-757):** `BattleSetup.school_matched_deck` (the default deck with two Allies swapped for
  the school's cards) drives the school bands in `BalanceBands`. The weak-vs-resisted matchup gates CI;
  the per-biome spread and the best-school-everywhere check are report-only until GID-183 / TID-771
  rebalances the magic cards. See `docs/agent/balance-sim.md` ("School bands").

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

`tests/unit/test_school_env.gd` (TID-755): per-condition boost rows, stacking, the banner table and text,
knob overrides, branch affinity still resolving through the shared condition, the resolver applying the
attacker's school boost once with matchup (`10 x 1.5 x 1.15 -> 17`), immunity staying 0, and a null defender.

`tests/unit/test_school_feedback.gd` (TID-752): outcome words, damage text, school colour, pip
data and tooltips, and the last-hit record (set by `deal`, kept through `to_dict` / `from_dict`).

TID-751 adds: hero resist scaling and stacking with profiles, `capped_resists` clamping, and the
`school_resist` round-trip (`test_damage_resolver.gd`); enemy attack schools are valid, undead and forest
types strike with their school, and `setup_enemy` fills the enemy profile (`test_enemy_school_profiles.gd`).
The balance bands (`tests/balance_bands.gd`) are the absolute check on the profile tuning.

`tests/unit/test_school_sources.gd` (TID-754): attacker power scaling (its school only, stacking with
profile and resist, floor at 0, through `deal`), weapon convert, the four school skill nodes (registered,
row 3 under row 2, summed per school, never card mods), affix wiring into power and resists (with caps,
and no effect when nothing is equipped), affix validation and old-save reads, the roll (tier chance,
convert weapon-only, stat roll unchanged), the label text, save round trip and drop message.
