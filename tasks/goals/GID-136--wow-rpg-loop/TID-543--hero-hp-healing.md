# TID-543: Persistent Hero HP & Healing (Food, Early Heals)

**Goal:** GID-136
**Type:** agent
**Status:** done
**Depends On:** TID-540, TID-545

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User decision (TID-540): hero HP carries over between fights with slow out-of-combat regen and a full heal in towns/beds. Healing must be available early: more low-level hero heal spells, food consumables (WoW-style eat-to-regen out of combat) alongside the existing persistent potions.

## Research Notes

- Hero HP today: `HeroState.health/max_health` = 30 per battle (+`passive_hp` skills in `BattleModifiers.gd` ~L75).
  Add save field `hero_hp` (PERSISTED_FIELDS) written on battle end (`autoloads/scene_manager/BattleVictory.gd`,
  `BattleDefeat.gd`) and read at battle setup. Exclude PvP, puzzles, scripted battles, Spire (own HP rules).
- Regen: WorldScene tick (N HP / in-game minute) when not in battle; full heal at `bed` (`PlayerHome.gd`),
  inns/rest sites (`rest_site` npc_type), town entry. World HUD HP bar (WorldHUD, viewport-relative sizing).
- Defeat at 0 HP → existing game-over/bed respawn routing (`docs/agent/player-home.md`).
- Food: new consumable kind next to potions (`SaveManager.potions`, `GardenDefs.gd`, merchant stock) — eat out of
  combat: regen X HP over Y s, cancelled by engage. Hooks into TID-542 quick slot.
- From TID-542: battle quick slots exist (`QuickSlots.gd`, `SaveManager.quick_slots`, Q / E). The **world** quick
  slot was deferred here — add a world-HUD button (`_world_hud.register_action`) + Q key that drinks a healing
  draught / eats food out of combat once `hero_hp` exists.
- Early heals: heal spells today are cost 1 `mend`, `dawn_soothing_touch`… mostly branch-gated; add 1–2 neutral
  low-cost heal cards to the starter deck / merchant (`CardRegistry` const preload + `.uid`).

## Plan

1. `game_logic/HeroVitality.gd` (pure): eligibility, start HP, post-fight fraction,
   regen, food table, world item pick, hurt.
2. Save `hero_hp_frac` (fraction, so gear changes rescale) + `foods`.
3. Battle hooks in `BattleModifiers` (BattleScene only gets one-line calls — it is
   lint debt): start at the fraction, record on game over (loss → 0.5).
4. World module `HeroHealth`: regen, Q / Eat, meals cancelled on engage, full heal in
   towns and at the bed; HUD HP bar.
5. Shop Food section. Early heals: the GID-141 Mend skill already covers level 1.
6. Opportunistic fix: dungeon rest sites/events used a display-only 30-HP counter.

## Changes Made

- New `game_logic/HeroVitality.gd`, `scenes/world/modules/HeroHealth.gd` (+ uids).
- `SaveManager` (`hero_hp_frac`, `foods`), `BattleModifiers` (`_apply_persistent_hp`,
  `record_persistent_hp`), `BattleScene` (2 calls), `WorldHUD` (HP bar, `set_hero_hp`),
  `WorldScene` (module; trimmed lines for the 2100 ceiling), `PlayerHome.use_bed`,
  `RealmRegions._set_town`, `ShopScene` (Food), `DungeonSessionUI` (real HP).
- Tests: new `test_hero_vitality.gd`.

## Documentation Updates

- `home-garden-potions.md` → Persistent Hero HP, Food & World Healing; `combat-model.md`
  decision 3; CLAUDE.md world-module table.
