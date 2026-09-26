# TID-540: Combat Model Redesign — Hero Spells, Companion Minions, Enemy Packs

**Goal:** GID-135
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User direction (2026-09-26): skill cards are what you use in battle; consumables are used from the inventory;
regular (creature) cards in the deck may become *companions*; "maybe the way you battle is mostly with spells".
Also: a world enemy is one creature but in battle it summons ghouls etc. — reconsider so encounters make sense.
This is a design task: produce `docs/agent/combat-model.md` with 2–3 options and a recommendation, **present to
the user and get approval before TID-537/TID-541 build**.

## Research Notes

- Current model (Hearthstone-like): `game_logic/battle/GameState.gd`, `PlayerState.gd`, `HeroState.gd`, `ZoneState.gd`
  (5 board slots), mana 1/turn cap 10, hero HP 30. Cards: `data/CardData.gd`, `autoloads/CardRegistry.gd`
  (~105 cards incl. spells per magic branch, see `docs/agent/magic-system.md`). Keywords `Keywords.gd`.
- Enemies: decks in `autoloads/EnemyRegistry.gd` `_ensure_loaded()` (e.g. ghoul_pack deck of ghouls/zombies;
  `phase2_deck` for bosses). No `.tres` enemies.
- Skills: `data/SkillData.gd`; 96 skill `.tres` (32 passive, 16 active: active_draw/heal/damage_all/mana) in
  `SkillRegistry`; active skill = one hero-power button in `scenes/battle/modules/BattleConsumables.gd` (~L160/202).
- Consumables: potions (`SaveManager.potions`, garden crafting, `docs/agent/home-garden-potions.md`) usable once per
  battle via picker in BattleConsumables.
- Gear can inject cards (`data/WeaponData.gd` `injected_card_id`).
- Questions to settle: deck composition (spell-heavy hero deck + small companion roster?), does the player summon at
  all, mana/resource model, what enemy board represents (its pack members pre-placed vs summoning), how captures /
  soulbinding (positioning pillar in spec) survive, AI (`ai/BasicAI.gd`) impact, PvP/co-op impact, migration of
  existing decks/saves (`SaveMigrations.gd`).
- Control scheme: user wants easy consumables "like D3" — define the battle input layout (hand, skill cards,
  quick consumable slot(s) with cooldown, end turn) and whether potions use a cooldown instead of once-per-battle.
  Implementation lands in TID-542 / TID-530.
- Spec says 4 card types in v1 and Hearthstone as TCG reference — a big pivot likely needs a spec amendment
  (fold into TID-539).

## Plan

Design-only: compare 2–3 combat models against the user's direction, recommend one, define encounter shapes,
control layout and rollout order; present to the user before TID-537/541/542 build.

## Changes Made

- New `docs/agent/combat-model.md`: facts table, options A (Hero & Allies — recommended), B (encounters only),
  C (full action bar), phased rollout, control layout, 3 open questions.
- User approved **Option A** (2026-09-26): Allies are drawn deck cards (not pre-deployed); hero HP carries over with
  more healing (food, early heal spells); terminology Mentor / Ally / Minion. Recorded under "Decisions" in the doc.
- Follow-up tasks created: TID-544 (terminology), TID-545 (hero kit), TID-543 (persistent HP & healing).

## Documentation Updates

`docs/agent/combat-model.md` (new); linked from CLAUDE.md docs table.
