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

## Integrations

- `tests/unit/test_battle_determinism.gd`, `test_player_caster.gd`, `test_battle_setup.gd`, `test_balance_bot.gd`
  and `test_balance_stats.gd` cover the pieces.
- `realtime_battle_smoke` checks `BattleSetup.build` against the live scene.
