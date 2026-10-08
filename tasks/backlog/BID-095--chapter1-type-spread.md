# BID-095: Chapter 1 enemy types spread widely one level up

**Category:** balance
**Discovered During:** GID-176 / TID-718

## Description

With the TID-718 global tuning, every Chapter 1 type is beaten ~100 % at the same level, but one level up the types disagree: `ghoul_pack` wins 23–40 % (its two 4/3 ghouls out-trade a level-3–5 hero), while `undead_basic` / `undead_horde` stay at 100 % (the horde is leaderless, so `gap_hp` never applies). Global knobs move every type together, so this needs per-type content tuning.

## Evidence

`bash tools/balance_matrix.sh` — table in `docs/agent/balance-sim.md` ("After TID-718").

## Suggested Resolution

Soften `ghoul_pack`'s pack (e.g. one ghoul + two zombies) and give leaderless packs a gap lever (scale pack unit health by `gap_hp`). Re-run the matrix; TID-717's CI bands should then cover every type.

## Update (GID-178 / TID-724)

After the pacing change the spread moved: `ghoul_pack` +1 is now 100 %, `martarquas_scout` +1 is ~30 % and `imbued_stag` ~60 %, leaderless `undead_horde` still 100 %.

## Resolution (TID-727, GID-176 follow-up)

- Pack units on the board now scale with the enemy's level and level gap like their hero (`RealtimeCombat._gap_enemy_hp`).
- Per-type real-time HP tuning: `EnemyRegistry` field `rt_hp_mult` (`rt_hp_mult()`), applied by `BattleSetup.scale_enemy_hp` in `configure_realtime` and `BattleRealtime.join_enemy`: `martarquas_scout` 0.85, `imbued_stag` 0.9, `ghoul_pack` 0.95.
- Global `gap_damage` 0.08 → 0.10.
- One level up, mean per type (30 fights / cell): ghoul pack 80 %, scout ~82 %, stag ~68 %, wolves ~91 %, forest shade ~82 %, bog hag ~81 %, undead ~78 %.
- **Left open:** the leaderless `undead_horde` is 100 % one level up at any HP (its units die before they deal real damage); it needs more damage or a different pack, not HP.
