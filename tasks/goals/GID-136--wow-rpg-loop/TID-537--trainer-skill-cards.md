# TID-537: Class Trainers & Skill Cards

**Goal:** GID-136
**Type:** agent
**Status:** done
**Depends On:** TID-536, TID-540

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

User: skill cards are the things you use in battle. Trainer NPCs in towns teach skill cards for coins at level thresholds; ranks upgrade them. Final shape follows the TID-540 combat model.

## Research Notes

- Current skills: `data/SkillData.gd` (skill_type passive/active, effect_type, magic_branch, prerequisites);
  `autoloads/SkillRegistry.gd`; tree UI `scenes/ui/SkillTreeScene.gd`; active skill → hero power in
  `BattleConsumables.gd`. Magic types/branches from `game_logic/MagicTypes.gd` (never re-list branches).
- Plan direction: active skills become spell cards (CardData, branch-owned — `test_magic_types` checks card
  magic_type vs branch) learned at a `trainer` npc_type; passives stay in the tree. Deck always includes learned
  skill cards (or a skill bar — per TID-540). Save: `learned_skill_cards` {id: rank}; migration of existing
  `unlocked_skills` actives in `SaveMigrations.gd`.

- **TID-540 decided Option A** — read `docs/agent/combat-model.md` (Decisions section) first. Use the
  Mentor / Ally / Minion terminology.

## Plan

**Superseded research note:** the "spell card" direction above predates
TID-550, which shipped the concrete real-time skill bar
(`game_logic/battle/SkillBar.gd`, `SLOTS = 3`, `strike`/`mend`/`kick` always
known). That is the actual shape "skill cards" took — a small, weak, reliable
ability bar, not deck cards. This task adapts to it:

1. Add 5 new abilities to `SkillBar.ABILITIES` beyond the always-known three,
   each with a `level_req` and `learn_cost` (0 for the always-known trio, so
   they're never offered by a trainer): `guard` (shield/armor), `ember_lance`
   (a slower, heavier hit), `mana_tap` (light hit + mana restore), `sweep`
   (hits every enemy minion) and `daze` (a weak stun/interrupt). New `apply()`
   effect branches: `shield`, `manatap`, `sweep`, `stun`. Every learnable
   ability's `value` stays ≤ 9 — weaker than deck spells, per the user's
   design that the bar should never compete with the deck.
2. Gate learning on level + coins (`SkillBar.can_learn`), persist in a new
   `SaveManager.learned_abilities: Array[String]` field
   (`SaveManager.learn_ability(id, cost)` performs the purchase).
   `SkillBar.new(bar, learned)` now filters a saved bar id through both
   "known to `ABILITIES`" and "in `learned` (or always-known)" — a
   trainer-taught ability must actually be learned to surface in a fight.
3. Trainer NPC: `npc_type = "trainer"` on a plain `MapNpc` (no new resource
   fields needed — the trainer always offers the full learnable set).
   `NpcInteractions.show_trainer_panel()` lists every ability with its
   level/cost/description and a Learn button (disabled when `can_learn()` is
   false, replaced with "Known" once learned). Placed in Madrian next to the
   stable (`trainer_madrian`, tile 78,44).
4. Update every `SkillBar.new(...)` call site (`BattleRealtime.maybe_start`,
   `BattleSkillBar._init`) to pass `SaveManager.learned_abilities` so a
   learned ability actually reaches the in-battle bar.

## Changes Made

- `game_logic/battle/SkillBar.gd`: `ALWAYS_KNOWN`, `LEARNABLE_ORDER`,
  `learnable_ids()`, `is_always_known()`, `can_learn()`; 5 new `ABILITIES`
  entries (`guard`, `ember_lance`, `mana_tap`, `sweep`, `daze`) with
  `level_req`/`learn_cost`; new `apply()` branches `shield`/`manatap`/
  `sweep`/`stun` plus a `_sweep()` helper; `_init(bar, learned)` now takes a
  second `learned` array and filters against it (always-known ids bypass it).
- `autoloads/SaveManager.gd`: `learned_abilities: Array[String]` field +
  `PERSISTED_FIELDS` entry; `learn_ability(id, cost)` and `set_skill_bar(bar)`
  (the latter is TID-556's write path, added here since it belongs next to
  `skill_bar`).
- `scenes/world/modules/NpcInteractions.gd`: `"trainer"` dispatch →
  `show_trainer_panel()` (+ `_trainer_row()` helper); `"training_dummy"`
  dispatch → `_offer_training_dummy_fight()` (TID-557, see that task).
- `scenes/world/WorldScene.gd`: `_NPC_PROMPT_LABELS` gains `"trainer": "TRAIN"`
  and `"training_dummy": "PRACTICE"`.
- `assets/maps/madrian.tres`: two new NPCs, `trainer_madrian` (78,44) and
  `training_dummy_madrian` (81,44), next to the stable.
- `scenes/battle/modules/BattleRealtime.gd` / `BattleSkillBar.gd`: both
  `SkillBar.new(...)` call sites now pass `SaveManager.learned_abilities`.
- Tests: `tests/unit/test_skill_bar.gd` — `learnable_ids()` excludes the
  always-known trio, every learnable ability's value stays ≤ 9, `can_learn()`
  level/coin/already-learned gating, an unlearned id is dropped from a saved
  bar while a learned one populates it, and one apply() test per new effect
  (`guard` armor absorbs damage, `mana_tap` damages + restores mana, `sweep`
  hits every enemy minion, `daze` stuns and interrupts a cast, with and
  without an active cast). `tests/unit/test_named_map_npcs.gd`'s Madrian NPC
  count bumped 12 → 14.

## Documentation Updates

- `docs/agent/combat-model.md`: new "Skill bar" subsection under Real-Time
  Combat — the always-known trio, the 5 trainer-taught abilities and their
  effects, `apply()`'s signature, `learn_ability`/`learned_abilities`, and a
  pointer to TID-556 (loadout) and TID-557 (training dummy).
- `docs/agent/enemies-and-npcs.md`: new "Skill Trainer & Training Dummy"
  section documenting both `npc_type`s, their `NpcInteractions` entry points,
  and the training dummy's `EnemyRegistry` entry (see TID-557).
