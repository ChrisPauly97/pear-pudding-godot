# Balance Simulator (GID-176)

A headless, seeded harness that plays thousands of **real-time** solo PvE fights with a fixed bot, so balance is
measured instead of hand-played. It runs the game's own rules, never a copy, and costs no tokens: it's a local
Godot script.

## Key Features

- **Deterministic:** fight *i* uses seed `S + i`. The same seed + config gives an identical fight.
- **Same rules as the game:** setup (`BattleSetup`), player casting (`PlayerCaster`), combat clock
  (`RealtimeCombat`), card effects and enemy plays (`SpellEffectResolver`), and fight traits. The scene calls the
  same code.
- **Sweeps** over player level, enemy level, any `CombatTuning` knob or a bot policy knob.
- **Output:** one summary row per case on stdout, plus a per-fight CSV.
- **Speed:** about 30–50 fights/s headless.

## How to run

```bash
godot --headless --path . -s tools/balance_sim.gd -- --fights 200 --level 5 --enemy undead_basic
godot --headless --path . -s tools/balance_sim.gd -- --fights 100 --sweep level=1,2,3,4,5,10 --csv none
godot --headless --path . -s tools/balance_sim.gd -- --enemy all --level 10 --sweep draw_interval=6,7,9
```

| Option | Meaning (default) |
|---|---|
| `--fights N` | fights per case (200) |
| `--seed S` | first seed (1) |
| `--level L` | player level (1) |
| `--learned` | `ladder` = UnlockLadder rows with `level_req <= L` (default), `all`, `none`, or `id,id` |
| `--deck` | `starter` = `BattleSetup.level_deck(learned)` (new-game deck + up to 3 known technique cards), or `id,id` |
| `--weapon` / `--offhand` | equipped item ids (none) |
| `--enemy` | type(s), comma-separated, or `all`; unknown types abort with the known list |
| `--enemy-level N` | zone level (default: the type's tier level-equivalent) |
| `--boss` | fight as a boss (tier 4, boss HP) |
| `--tune k=v,…` | `CombatTuning` overrides (clamped to each knob's range) |
| `--policy k=v,…` | `BalanceBot` knobs: `heal_below` (0.4), `summon` (1), `interrupt` (1) |
| `--sweep key=v1,v2` | one case per value: `level`, `enemy_level`, a tuning knob, or a policy knob |
| `--csv PATH` | per-fight CSV (default `user://balance/<time>.csv`; `none` skips) |
| `--max-seconds S` | per-fight cap, counted as a timeout (300) |

### Reading the table

`win` + Wilson 95 % CI (30/30 still only proves ≥ 88.6 %); `t/o` timeouts; median / p10 / p90 fight seconds;
median hero HP left; `cards` = share of enemy damage from cast cards (the rest is hero + Ally auto-attacks);
`kicks/casts` = interrupts landed / enemy casts; `fullM` = average seconds spent at full mana (nothing to spend
it on).

## How It Works

| Piece | File | Role |
|---|---|---|
| `BattleSetup.build(cfg)` | `game_logic/battle/BattleSetup.gd` | builds `{state, rt, tier}` the way `BattleScene` + `BattleRealtime.maybe_start` do |
| `PlayerCaster` | `game_logic/battle/PlayerCaster.gd` | GCD, cast bar, pushback, fizzle, combo, techniques; `play()` for the bot |
| `BalanceBot` | `game_logic/battle/BalanceBot.gd` | fixed policy: Kick / Daze casts → heal when low → summon → best spell per mana |
| `BalanceFight.run(cfg, policy)` | `game_logic/battle/BalanceFight.gd` | one fight at a 0.05 s tick; returns result + stats |
| `BalanceStats` | `game_logic/battle/BalanceStats.gd` | Wilson CI, percentiles, summary, table and CSV rows |
| CLI | `tools/balance_sim.gd` | args, seed loop, sweeps, output |

Determinism: `BattleSetup.build` calls `seed(n)` (global RNG: shuffles, resolver picks) and sets `rt.rng.seed`.
`SpellEffectResolver.silent` mutes sound during a run.

## Limits

- **A bot, not a human.** Compare settings against each other; absolute win rates are only a proxy for
  "average play".
- **Not simulated:** weather, gambits, ambush, blight, companions, persistent / carried-over HP, potions and the
  hero power, boss phase 2, commanded Ally attacks, focus changes, snow discount.
- **Real time only** (user decision); turn-based fights aren't simulated.

## Balance targets (user, 2026-10-08)

With full HP and mana and average play (the default bot): beat an enemy of the **same level 100 %** of the time,
one **level above about 75 %**. TID-718 tunes toward this; TID-717 turns it into CI bands.

### Design decisions behind the targets (user, 2026-10-08)

- A zone has a level range; each enemy type a sub-range inside it; starter camps take their level from the zone (TID-719).
- Enemies behave the same whatever the player has learned; heavy blows and enemy casts scale with **enemy** level. Weak enemies still cast but hit softly, so Kick lands on something familiar (TID-720).

### "An enemy of level L"

An enemy's level is its tile's story-route level clamped to zone ∩ type sub-range (`ZoneLevels.enemy_level_at`,
TID-719). In the sim, pass `--enemy-level L` with a type whose `EnemyRegistry.level_range` contains L.

### First measurement (TID-716, 30 fights each, `undead_basic`, ladder-learned, no gear)

| Player level | Win | Note |
|---|---|---|
| 1 | 0 % | Strike only; dies in about 24 s |
| 2 | 100 % | + Mend |
| 3 | 47 % | + Kick, which also switches on telegraphed heavy blows (`heavy_enabled`) |
| 4–5 | 93 % | + Allies |
| 10 | 100 % | |

### After TID-720 (100 fights each, `undead_basic`, ladder-learned, no gear)

Enemy behaviour now follows the enemy's level only; heavies from level 1 (user, softened on the spell curve). `--enemy-offset D` sets enemy level = player level + D.

| Player level | 1 | 2 | 3 | 4 | 5 | 6 | 8 | 10 |
|---|---|---|---|---|---|---|---|---|
| Same-level enemy (offset 0) | 0 % | 100 % | 0 % | 78 % | 66 % | 47 % | 36 % | 68 % |
| Enemy one level up (offset 1) | 0 % | 0 % | 11 % | 66 % | 46 % | 38 % | 35 % | 38 % |
| Enemy at its tier level (no offset) | — | — | — | 100 % | 100 % | — | — | 100 % |

Far from the targets (100 % / ~75 %): level-matched enemies outscale the hero, and levels 1 and 3 are walls.
TID-718 tunes this.

### After TID-718 (30 fights per cell, each Chapter 1 type at its level range)

Player level L (ladder-learned, starter deck, no gear) vs the type at L and at L + 1
(`bash tools/balance_matrix.sh [tune] [fights]` runs `--enemy TYPE --sweep level=… --enemy-offset 0|1` per type).

| Enemy (levels) | Same level | One level up |
|---|---|---|
| `undead_basic` (1,2) | 100% / 100% | 100% / 100% |
| `undead_horde` (2,3,4) | 100% / 100% / 100% | 100% / 100% / 100% |
| `ghoul_pack` (3,4,5) | 100% / 100% / 96.7% | 23.3% / 40% / 26.7% |
| `wolf_pack` (4,5,6) | 100% / 100% / 100% | 96.7% / 80% / 73.3% |
| `forest_shade` (5,6,7,8) | 100% / 100% / 100% / 100% | 100% / 100% / 86.7% / 76.7% |
| `bog_hag` (6,7,8) | 100% / 100% / 100% | 100% / 96.7% / 93.3% |
| `imbued_stag` (7,8,9) | 100% / 100% / 100% | 96.7% / 73.3% / 50% |
| `martarquas_scout` (8,9,10) | 100% / 100% / 100% | 86.7% / 63.3% / 86.7% |

What changed:
- **Fatigue bug:** a Strike-only deck took 1+2+3+4 fatigue drawing its opening hand, so every early fight
  started at 20/30 HP. Opening hands and the first turn's draw never fatigue now (`PlayerState`).
- **Bot focus:** `BalanceBot` taps the weakest enemy minion as its auto-attack focus (policy `focus`), what a
  player does against a pack. Without it, packs were 0 %.
- **Chapter 1 types fight at tier 1** (`BattleSetup.base_tier`): their strength comes from level; `ghoul_pack`
  (authored tier 3) was a tier-3 fight at levels 3–5.
- **Level growth, both sides** (CombatTuning): hero `hp_per_level` 5; enemy `enemy_hp_per_level` 0.08,
  `enemy_unarmed` 1, `enemy_low_scale` 0.3, `enemy_full_level` 15, `enemy_two_minions_level` 5.
- **Level gap:** an enemy above you has `gap_hp` 0.3 more HP and deals `gap_damage` 0.15 more damage
  (swings, heavies, spells) per level; below you, less (never under half).

The bot is very consistent, so win rates move in cliffs (0.05 → 0.10 extra enemy HP per level swings +1 fights
from ~95 % to ~40 %). Outliers left for content tuning: `ghoul_pack` +1 is too hard and early undead +1 too easy
(BID-095).

### After GID-178 / TID-724 (pacing)

Techniques start in hand and return on cooldowns (Strike 3 s, 2 dmg), so the player acts ~3–5 times per 10 s
(new `act10` column / `actions_10s` CSV field). Enemies were pushed back up (`enemy_unarmed` 2,
`enemy_hp_per_level` 0.18, gap 0.12 HP / 0.08 damage). Bands: same level 100 % for every cell; one level up
mean 80 % (bog hag 88, forest shade 100, ghoul pack 100, imbued stag 60, martarquas scout 30, undead 68,
horde 100, wolves 98). The scout is the new hard outlier (BID-095).

### After TID-727 (BID-095 outliers)

Pack units scale with level / gap like their leader; per-type `rt_hp_mult` (EnemyRegistry) trims the scout
(0.85), stag (0.9) and ghoul pack (0.95); `gap_damage` 0.10. One level up, mean per type: 68–91 % for every
Chapter 1 type except the leaderless horde (100 %, still open in BID-095). Bands mean 82 %.

### After TID-729 (horde)

The leaderless horde refills to its pack size (4 units) and its units get `rt_attack_bonus` +2. One level up it
averages ~77 % (30 % at L2, 100 % at L3–4). Every Chapter 1 type is now in band on average; BID-095 resolved.

## CI balance bands (TID-717)

`game_logic/battle/BalanceBands.gd` turns the targets into checks. Cells: one per Chapter 1 type at a level
inside its range (`CELLS`), at the same level (20 seeded fights) and one level up (40). `check()` fails when:

- any same-level cell wins < 97 %;
- the mean one-level-up win rate leaves 65–85 % (measured: 82 %);
- a cell drifts from `tests/data/balance_baseline.json` by more than 10 points of win rate or 25 % of median length.

CI runs `godot --headless --path . -s tests/balance_bands.gd` as its own step (~30 s; too slow for the unit
suite). `tests/unit/test_balance_bands.gd` covers the check logic and that the baseline lists every cell.
Changed the numbers on purpose? `godot --headless --path . -s tools/balance_sim.gd -- --write-baseline` rewrites
the JSON (with the commit it was measured at); commit the diff so review sees the balance move.
GID-179 / TID-732: player spells and techniques crit now (scout L9+1 60 → 75 %); `cfg.skills` / `--skills id,…`
build `SkillMods`. Skill points start at level 10, so the L1–9 bands never include skill nodes. Measured at L9 +1
(scout / bog hag / stag, 80 fights): none 79 / 51 / 68 %, four Thorn nodes 86 / 63 / 73 %.

## School bands (TID-757, rebalanced and gated in TID-771)

Decks by damage school (`docs/agent/damage-schools.md`). Both use the whole unlock ladder learned
(`BalanceBands.all_learned()`), so a school's cards are playable, at the same seeds for every deck.

- **Shape-matched decks** (`BattleSetup.school_matched_deck(school, learned)`): the default deck
  (`level_deck`) with its last `MATCHED_SWAP` (2) Allies replaced by the school's own techniques, then
  its spells. Strike, Mend and Kick stay, so the bot keeps its interrupts and heals and the school is the
  only difference. Physical is the default deck itself. Matched decks never take Allies (spells only), so
  the verdant / rift Allies of TID-768..770 do not move them.
- **Sweep keys** in `tools/balance_sim.gd`: `--sweep matched=light,dark,...` (the shape-matched deck, the one
  the bands use) and `--sweep school=...` (`BattleSetup.school_deck`, a **pure mono-school** deck of every card of
  that school, cycled to 12, Allies included). Mono is diagnostic only.
- **Roster cells** (`BalanceBands.BIOME_ROSTERS`): one enemy per biome, chosen from a 60-fight grid so the
  default deck is neither saturated nor dead: grasslands martarquas_scout 9 vs L7, forest bog_hag 8 vs L6,
  desert cactus_worm 5 vs L4, scorched scorched_revenant 6 vs L5, mountains mountain_troll 8 vs L6.
  `SCHOOL_FIGHTS` = 14 seeded fights per deck per biome (was 6 pooled over two cells, which paired a 100 % cell
  with a 0 % one). Win rates move in steps of 1/14 (7 pp).
- **Matchup cell** (`BalanceBands.MATCHUPS`): cactus worm (weak to dark, resists verdant) at level 6 vs player 4,
  20 fights per side.

| Check | Status | Rule |
|---|---|---|
| (b) matchup | **gating** | weak school beats its resisted school by ≥ 20 pp (`check_schools`) |
| (c) best school | **gating** | no school within 2 pp of the top in every biome (`check_schools` / `best_everywhere`) |
| (a) roster | **gating** (GID-184) | each school deck within ±25 pp of the default in a **neutral** matchup (`neutral_school_fails`): a school the biome enemy resists / is weak / immune to is skipped (band (b)'s job), and a biome whose enemy profiles physical (desert cactus worm, mountain troll) is skipped whole since the default deck is not neutral there. `report_schools` still prints every deviation as a NOTE |

### GID-184 / TID-773 measurements (win %, 14 fights per cell, default = physical)

BID-101's cause was deck shape: the light matched fill is the first two light techniques in `TechniqueDefs` order,
`tech_pyroblast` + `tech_blazing_draw`, and Blazing Draw only drew cards. Rift had the same shape (Reweave draw +
Mana Surge). Changes:
- `tech_blazing_draw` → new effect `smite_draw` (single-target damage of the card's school, then draw 1): turn-based
  3, real time 3, recycle 20 → 12 s. First try (real time 6, recycle 8) made light best everywhere (93–100 %).
- `tech_mana_surge` real-time hit 2 → 4.
- `SpellEffectResolver.HERO_TARGETABLE_EFFECTS` replaces four hard-coded `== "deal_damage_single"` checks
  (BattleTargeting ×2, BattleInput, BalanceBot), so a new hero-hitting effect is one list entry.

| Biome (cell) | default | light | dark | verdant | rift | profiled schools |
|---|---|---|---|---|---|---|
| grasslands (scout 9/7) | 79 | 100 | 71 | 100 | 100 | dark, verdant |
| forest (bog hag 8/6) | 50 | 50 | 50 | 43 | 43 | verdant, dark |
| desert (cactus 5/4) | 64 | 100 | 100 | 100 | 93 | physical (cell skipped), verdant, dark |
| scorched (revenant 6/5) | 43 | 71 | 64 | 64 | 43 | dark, light, verdant |
| mountains (troll 8/6) | 50 | 57 | 64 | 57 | 29 | rift, light, physical (cell skipped), dark |

Neutral checks all within ±25 (largest: grasslands light / rift +21). Matchup cactus worm weak 45 vs resisted 0. No
school is best everywhere. Baseline cells unchanged (no `--write-baseline`).

### TID-771 measurements (win %, `tests/balance_bands.gd`, 14 fights per cell, default = physical)

| Biome (cell) | default | light | dark | verdant | rift |
|---|---|---|---|---|---|
| grasslands (scout 9/7) | 79 | 57 | 71 | 100 | 79 |
| forest (bog hag 8/6) | 50 | 14 | 50 | 43 | 21 |
| desert (cactus 5/4) | 64 | 29 | 100 | 100 | 71 |
| scorched (revenant 6/5) | 43 | 14 | 64 | 64 | 29 |
| mountains (troll 8/6) | 50 | 21 | 64 | 57 | 14 |

Matchup: cactus worm weak dark 45 % vs resisted verdant 0 % (+45 pp; gate +20).
Before (TID-757, 6 fights per enemy, pooled over two enemies per biome, win %): default / light / dark / verdant / rift:
grasslands 58 / 50 / 58 / 58 / 58; forest 50 / 25 / 83 / 92 / 50; desert 50 / 50 / 100 / 67 / 50;
scorched 50 / 42 / 50 / 50 / 50; mountains 50 / 17 / 100 / 83 / 33.

What moved (60-fight per-cell checks on the same five cells, default in brackets):

| Cell [default] | light | dark | verdant | rift |
|---|---|---|---|---|
| scout 9/7 [70] | 50 (was 50) | 80 (was 87) | 92 (was 97) | 80 (was 80) |
| bog hag 8/6 [48] | 25 (was 29) | 50 (was 63) | 38 (was 59) | 38 (was 38) |
| cactus 5/4 [62] | 37 (was 37) | 100 (was 100) | 93 (was 98) | 87 (was 87) |
| revenant 6/5 [48] | 22 (was 22) | 55 (was 78) | 63 (was 88) | 37 (was 37) |
| troll 8/6 [43] | 25 (was 26) | 60 (was 81) | 52 (was 77) | 32 (was 33) |

Card changes (all `data/cards` `.tres` text plus the `TechniqueDefs` real-time value):
- `tech_soul_siphon`: drain 3 → 2 (real time 5 → 3). Dark's main outlier; revenant dark 78 → 55, scout 87 → 80.
- `tech_overgrowth`: heal 7 → 4 (real time 8 → 4). Verdant's lead on revenant and troll; bog 59 → 38.
- Tried and reverted: `tech_pyroblast` 2 → 3 (light did not improve); `tech_bountiful_harvest` mana 2 → 1
  (no change to any verdant cell). `tech_mana_drain` untouched: the soul_siphon cut took most of the dark lead.
- Light stays the weakest school (-20 to -35 pp on every cell): its matched fill is pyroblast + blazing_draw, and
  blazing_draw deals no damage. Fixing that is a deck-shape change, not a number, so it is reported, not tuned.

Why (a) is report-only at ±25: the spread is structural. Light trails by 20–35 pp in every biome (draw-only fill);
desert dark and verdant sit at 100 % because cactus worm's profile is weak to dark and resists verdant (the
matchup is by design). Gating (a) would need a profile edit or a light redesign, not a band width.

Why (c) gates now: verdant leads grasslands outright (100 %) but is tied with dark in desert and tied with
the default in forest, so no school is best in every biome. Band (c) is the one the tuning earned.

### Mono-school decks (report only, not in any band)

GID-184 re-check (`--sweep school=`, level 6, enemy +1, 14 fights, physical / light / dark / verdant / rift):
scout 100 / 93 / 64 / 100 / 100; bog hag 100 / 36 / 43 / 36 / 79; revenant 14 / 0 / 0 / 36 / 14.
Better than TID-771 but still uneven (light 36 % on bog hag, a neutral matchup); tracked in BID-102.

TID-771:

`--sweep school=` per roster cell, 60 fights, win %: physical / light / dark / verdant / rift.
scout 9/7: 48 / 0 / 12 / 62 / 38. bog 8/6: 30 / 0 / 0 / 5 / 20. cactus 5/4: 63 / 17 / 32 / 55 / 67.
revenant 6/5: 35 / 2 / 10 / 47 / 22. troll 8/6: 42 / 0 / 5 / 5 / 2.
Not viable: no magic mono deck wins 50 % in more than one cell, so mono decks are not added to the bands.

Cost: the school section runs about 26 s (about 15 fights per second) on top of the ~23 s cell measure.

## Integrations

- `tests/unit/test_battle_determinism.gd`, `test_player_caster.gd`, `test_battle_setup.gd`, `test_balance_bot.gd`
  and `test_balance_stats.gd` cover the pieces.
- `realtime_battle_smoke` checks `BattleSetup.build` against the live scene.

## Well-fed buffs (GID-182 / TID-763)

Cooked-food buffs (`game_logic/professions/WellFed.gd`, +max HP for a few fights) are not in the sim. `BattleSetup.build` never reaches `BattleModifiers`, so the sim and the CI bands always run unbuffed. Keep it that way: a buff should change how a fight feels, not the balance baseline.
