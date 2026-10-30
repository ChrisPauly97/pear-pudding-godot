# TID-798: First-30-minutes walkthrough audit + fixes

**Goal:** GID-188
**Type:** agent
**Status:** done
**Depends On:** TID-795

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Walk the slice from New Game to slice boss (automation/screenshots), log every friction point, fix the cheap ones, backlog the rest.

## Research Notes

- Prior audits: TID-593/594 (GID-141), `docs/agent/game-appeal.md` §6–7.
- `tests/world_scene_smoke.gd`, `tools/profile_world.gd` for driving the scene headless.

## Plan

Render the real first-session screens under Xvfb (driver scene kept out of the repo): main menu → slot select →
biome select → spawn in Madrian → walk to the South Field camp → engage → live fight. Fix what blocks or misleads a
new player; backlog the rest.

## Findings → fixes

| Finding | Fix |
|---|---|
| New Game goes through a 5-world biome picker with a "Head Start (debug)" toggle | Slice skips it: `HeroAppearanceScene` starts grasslands directly (`SliceRules.shows_biome_picker`, `START_BIOME`) |
| Town square advertises cut systems: Crafting / Alchemy stations, Master Artisan, Bounty Master (also Rift Warden, Stablemaster) | Not spawned in the slice (`SliceRules.allows_stations`, `HIDDEN_NPCS` / `allows_npc` in `ChunkRenderer` + `CraftingStations`); test: no slice quest needs a hidden NPC |
| A "Choose a Gambit" picker before the very first fight | Slice auto-skips gambits (`SliceRules.allows_gambits` in `SceneManager` + `SwapDeckPrompt`) |
| Mana tutorial describes turn-based mana (1/turn, max 10) — wrong in real time | `TutorialRegistry` "mana" text rewritten for the real-time pool + regen |
| ⚙ Tune (developer tuning panel) visible in battle; T opens it | Hidden in the slice (`SliceRules.shows_dev_tools`) |
| Level 1: "Heavy Blow incoming — Kick it or Guard!" (Kick is L3, Guard L11) | `BattleRealtime.heavy_blow_tip(learned)` names only learned answers, else "brace yourself!" |

Left for later: BID-110 (double tutorial popup, "(0)" cost on Heavy Blow, toast readability).

## Changes Made

- `SliceRules`: `HIDDEN_NPCS`, `START_BIOME`, `allows_npc`, `allows_stations`, `allows_gambits`, `shows_dev_tools`,
  `shows_biome_picker`.
- `ChunkRenderer`, `CraftingStations`, `HeroAppearanceScene`, `SceneManager`, `SwapDeckPrompt`, `BattleRealtime`,
  `TutorialRegistry` as above. `in_world_battle_smoke` turns the slice off for its gambit-picker check.
- Tests: `test_slice_rules` (+3), `test_combat_tuning` (+1). Suite 3661 pass; 7 smoke tests clean.

## Documentation Updates

- `docs/agent/vertical-slice.md`: new gate rows.
