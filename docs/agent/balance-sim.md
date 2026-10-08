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

## Integrations

- `tests/unit/test_battle_determinism.gd`, `test_player_caster.gd`, `test_battle_setup.gd`, `test_balance_bot.gd`
  and `test_balance_stats.gd` cover the pieces.
- `realtime_battle_smoke` checks `BattleSetup.build` against the live scene.
