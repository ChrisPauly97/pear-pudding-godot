# TID-541: Enemy Encounters That Match the World

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** TID-540

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A single world enemy summoning a board of ghouls feels wrong. Implement the encounter model chosen in TID-540 so what you see in the world is what you fight.

## Research Notes

- Likely shape (confirm in TID-540): pack enemies (`ghoul_pack`, `undead_horde`) show 2–4 sprites in the world
  (`SpriteRegistry.make_billboard`) and start the battle with those units already on the board; solo enemies/bosses
  fight with their own abilities (spell-like enemy cards) instead of summoning, except thematic summoners (necromancer).
- EnemyRegistry entries gain e.g. `pack: [...]` (starting board) and `abilities: [...]`; `deck` retained for summoners.
- Touch points: `GameState` setup (initial board), `BasicAI`, `CaptureTracker.gd` (capture target), bestiary
  (`docs/agent/bestiary-codex.md`), co-op scaling `CoopBattleScaling.gd`, scripted battles/puzzles unaffected.

- **TID-540 decided Option A** — read `docs/agent/combat-model.md` (Decisions section) first. Use the
  Mentor / Ally / Minion terminology.

- Real time: pack members start on the board (RealtimeCombat gives pre-placed units a half swing);
  solo enemies' ability cards resolve through the enemy cast telegraph (`enemy_cast_start` / `enemy_cast`).

## Plan

First cut that keeps GameState's win rules (an enemy hero in every fight):
1. Pack enemies: `pack` in EnemyRegistry; the pack starts on the enemy board, tier-scaled, and
   stands beside the leader in the world.
2. Solo enemy (Undead Warlord): ability-spell deck from existing dark spells (no new cards, which
   would leak into every loot/draft pool).
3. Summoners unchanged. Leaderless packs ("clear the board", no hero) left for later.

## Changes Made

- `EnemyRegistry` (`pack` for ghoul_pack / undead_horde, `get_pack`, Warlord ability deck).
- `BattleModifiers._place_enemy_pack`; `BattleScene` (one call after the enemy deck).
- `EnemyNPC._add_pack_followers`; `SpriteRegistry.pack_member_texture`.
- Tests: new `test_enemy_encounters.gd`; `battle_input_flow_smoke` → `_check_pack_on_board`
  (verified to fail with the placement disabled).

## Documentation Updates

- `combat-model.md` → Encounters that match the world; `enemies-and-npcs.md` → Pack Leaders & Solo Enemies.
