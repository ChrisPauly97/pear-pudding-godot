# TID-545: Hero Kit — Weapon Auto-Attack, Ally Cap, Faster Start

**Goal:** GID-135
**Type:** agent
**Status:** done (scoped to the off-hand slot only — see Plan)
**Depends On:** TID-540, TID-546

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Option A core (see `docs/agent/combat-model.md`): the hero fights. Weapon auto-attack each turn, Ally cards capped per deck and played into 3 Ally slots (drawn normally, never pre-deployed), 3-mana start + 4-card opening hand.

## Research Notes

- Battle state: `game_logic/battle/GameState.gd` (setup, turn start mana), `PlayerState.gd` (opening draw),
  `HeroState.gd` (hp 30, add `attack`/`attacked_this_turn`), `ZoneState.gd` (5 slots — make slot count per player).
- Weapon: `data/WeaponData.gd` add `hero_attack: int`; `WeaponRegistry`; applied in `BattleModifiers.gd`.
  Hero attack UI: tap hero → target (reuse `BattleTargeting.gd`), and TID-530 one-tap attack.
- Ally cap: deck builder validation (GID-003 min 5/max 30; `docs/agent/inventory-and-deck.md`), `DeckAutoFill.gd`,
  loadouts `SaveLoadouts.gd`; migration in `SaveMigrations.gd` moves excess minion cards back to the collection.
- PvP (`scenes/battle/net/BattleNet.gd`, BattleNetProtocol) must serialise new hero fields (`to_dict/from_dict`);
  mid-battle save (GID-034) too. AI: `ai/BasicAI.gd` must use enemy hero attack when enemy has a weapon (solo shape).
- Budget test from TID-527 (`BattlePacing`) should still hold.

**Auto-attack (user, 2026-09-26):** "when I'm low on mana I just attack with my main/off hand". The prototype
already swings main hand (`RealtimeCombat.main_hand_damage`) and supports `offhand_damage[side]`; this task adds a
**main-hand + off-hand gear slot** (today's slots: weapon/armor/ring/trinket; no weapon actually uses slot
"weapon" — `berserker_axe` is `passive_atk`), weapon damage + swing speed fields on `WeaponData`, and wires them in
`BattleModifiers` → `RealtimeCombat`. Save field for the off-hand slot via PERSISTED_FIELDS.

**Real-time update (2026-09-26):** hero auto-attack is a swing timer (`RealtimeCombat.HERO_SWING_INTERVAL`,
already driven by `hero.attack`) — weapons add `hero_attack` and a swing speed. Max mana is fixed per fight from level + gear
(`RealtimeCombat.max_mana_for`); the turn-based 3-mana/4-card change applies only to turn-based modes.

## Plan

Scoped to the off-hand slot only (2026-09-26 note): main-hand weapon damage, swing speed, Ally
cap and the turn-based 3-mana/4-card start are separate, larger changes covered by their own
follow-up work (main-hand `passive_atk`/`swing_speed` and `RealtimeCombat.weapon_speed` already
exist on this branch from TID-546/551; Ally cap is untouched here). This task adds the **fifth
equipment slot** — off-hand — that `RealtimeCombat.offhand_damage[side]` and the tunable
`offhand_swing` knob were already built to receive.

1. `WeaponData`: document `slot = "offhand"` and two new `battle_effect_type` values,
   `"offhand_atk"` (off-hand swing damage) and `"starting_armor"` (armor status at battle start —
   generic, not offhand-specific, but used by the buckler).
2. Three new off-hand items in `data/weapons/` (+ `.uid` sidecars), registered in `WeaponRegistry`:
   `parrying_dagger` (offhand_atk 4), `buckler` (starting_armor 5), `arcane_focus` (starting_mana 1,
   reuses the existing effect type — "gives max mana" per the task brief).
3. `SaveManager`: `equipped_offhand` / `owned_offhands` fields, `PERSISTED_FIELDS` entry, save
   migration v41→v42, wired into `add_equipment` / `equip_item` / `get_owned_by_slot` /
   `get_equipped_by_slot` / `new_game()` reset, matching the armor/ring/trinket pattern exactly
   (no upgrade-level dict like weapons — off-hand items don't upgrade, same as armor/ring/trinket).
4. `BattleModifiers._apply_equipment_effects`: add `equipped_offhand` to the slot loop; handle
   `starting_armor` (`hero.apply_status("armor", value)`, same mechanism the Maiteln companion
   passive uses) and `offhand_atk` — turn-based only, since turn-based has no off-hand swing timer:
   add `UpgradeDefs.offhand_turnbased_bonus(value)` (half, minimum 1) to `hero.attack`, skipped
   when `battle_mode` starts with `"realtime"` so it never double-counts with the real-time swing.
5. `BattleRealtime.maybe_start()`: set `rt.offhand_damage[PLAYER]` from the equipped offhand item
   via a new pure static helper `offhand_damage_for_item(item_id)` (testable without the autoload),
   right next to the existing `equipped_weapon_speed()` main-hand wiring.
6. `CharacterScene`: add `"offhand"` to `_SLOTS`/`_SLOT_LABELS` — the equip/compare UI is already
   slot-generic, so no other UI code changed.
7. `ShopScene`: add an "Off Hands" section (mirrors Armor/Ring/Trinket) and a price rule for the two
   new effect types. `UiUtil.effect_summary` gets matching cases for the shop's short blurb.
8. `ChestLoot.EQUIPMENT_SLOTS` and `BattleArena._append_player_loadout`'s equipped-slot list: add
   `"offhand"` / `sm.equipped_offhand` so chest drops and the in-battle loadout info panel cover it.
9. Unit tests in `tests/unit/test_offhand_equipment.gd`.

**Turn-based equivalent (documented per the task's "sensible small equivalent or nothing"):** an
off-hand attack item adds `max(1, value / 2)` to `hero.attack` for the whole fight in turn-based
mode, in place of the real-time off-hand swing timer it has no equivalent for. `starting_armor` and
`starting_mana` off-hand items work identically in both modes (they're already mode-agnostic
battle-start effects).

**Known limitation (documented, not fixed — out of scope):** `starting_armor` and the companion's
`hero_armor` passive both write the single `"armor"` status key via `apply_status`, so equipping a
buckler alongside an armor-granting companion has the later call (`_apply_companion_battle_start`
runs after `_apply_equipment_effects`) overwrite rather than stack with the earlier one. This
matches the pre-existing single-key status-effect model (`HeroState.status_effects`); making armor
sources additive is a separate, broader change.

## Changes Made

- `data/WeaponData.gd`: doc comments for `slot = "offhand"` and the two new effect types.
- `data/weapons/parrying_dagger.tres`, `buckler.tres`, `arcane_focus.tres` (+ `.uid` sidecars).
- `autoloads/WeaponRegistry.gd`: preload + register the three new items.
- `game_logic/UpgradeDefs.gd`: `get_display_string` cases for `starting_armor` / `offhand_atk`,
  new `offhand_turnbased_bonus(value)` helper.
- `autoloads/SaveManager.gd`: `equipped_offhand` / `owned_offhands` fields, `PERSISTED_FIELDS`
  entry, `new_game()` reset, `add_equipment` / `equip_item` / `get_owned_by_slot` /
  `get_equipped_by_slot` slot-"offhand" cases.
- `game_logic/save/SaveMigrations.gd`: `CURRENT_VERSION` 41→42, new row backfilling
  `equipped_offhand`/`owned_offhands` on old saves.
- `scenes/battle/modules/BattleModifiers.gd`: offhand added to the equipment slot loop;
  `starting_armor` and mode-gated `offhand_atk` cases.
- `scenes/battle/modules/BattleRealtime.gd`: `offhand_damage_for_item()` static helper, wired into
  `maybe_start()` alongside the existing main-hand `equipped_weapon_speed()`.
- `scenes/ui/CharacterScene.gd`: `"offhand"` slot + label (equip/compare UI already slot-generic).
- `scenes/ui/ShopScene.gd`: "Off Hands" shop section, price rule for the two new effect types.
- `scenes/ui/UiUtil.gd`: `effect_summary` cases for `starting_armor` / `offhand_atk`.
- `scenes/world/modules/ChestLoot.gd`: `EQUIPMENT_SLOTS` includes `"offhand"` (chest/merchant drops).
- `scenes/battle/modules/BattleArena.gd`: in-battle loadout info panel lists the equipped off-hand.
- `tests/unit/test_offhand_equipment.gd`: 18 tests covering SaveManager CRUD, WeaponRegistry data,
  UpgradeDefs display/turn-based bonus, and `BattleRealtime.offhand_damage_for_item`.

Validated: headless import (no parse errors), `scripts/unsafe-hits.sh` (empty), `gdlint` on every
changed file (clean), full `tests/runner.gd` (2656 passed / 0 failed / 0 SCRIPT ERROR), and
`world_scene_smoke` / `menu_hub_smoke` / `spire_draft_smoke` / `realtime_battle_smoke` /
`in_world_battle_smoke` (all exit 0, no SCRIPT ERROR).

## Documentation Updates

- `docs/agent/inventory-and-deck.md`: Equipment System section — off-hand slot, its two new effect
  types, and the built-in off-hand items table.
- `docs/agent/combat-model.md`: Real-Time Combat section — off-hand gear note updated to point at
  the shipped slot instead of "TID-545" as a forward reference; turn-based equivalent documented.
