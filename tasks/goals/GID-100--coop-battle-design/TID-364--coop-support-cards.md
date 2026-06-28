# TID-364: Co-op support card content — ally-affecting cards

**Goal:** GID-100
**Type:** agent
**Status:** done
**Depends On:** TID-363

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Content to make the cross-board mechanic (TID-363) worth using: a set of new support
cards that affect allies, turning the joint battle into a genuine team effort.

## Research Notes

- **Card pipeline:** cards are `.tres` in `data/cards/`, each needs a `.uid` sidecar
  (CLAUDE.md "Godot Resource .uid Files"), and must be registered in
  `autoloads/CardRegistry.gd` via a `const _X := preload(...)` line iterated in
  `_ensure_loaded()` (CLAUDE.md "Android: Always preload() .tres Files"). Follow an
  existing magic-subtype card (GID-076) as the template for fields (id, name, cost,
  type, rarity, effect/ability text, art).
- **Card set (initial — tune during Plan):**
  - *Aegis* — give an ally's board +shield/Ward for a turn.
  - *Mend* — heal an ally's hero.
  - *Rally* — buff an ally minion (+atk/+hp).
  - *Mana Tithe* — give an ally +1 mana crystal this turn.
  - *Second Wind* — revive a downed ally minion / small board heal.
  - Each uses `target_scope: ally` (TID-363) and the per-player target.
- **Balance & acquisition:** decide rarity + where they drop (boss soulbound pool from
  TID-361? card packs? a co-op vendor?). They should be *useful only in co-op* (single
  ally target) — note that single-player can't meaningfully use them, so gate
  availability or make the effect fall back to self when solo.
- **Art:** reuse the procedural/illustration card-art path (GID-008 / visual-polish) —
  no bespoke art required if the pipeline auto-generates; otherwise placeholder art with
  a note.
- **Docs:** add the cards to the card content doc + `multiplayer-coop.md` co-op battle
  section. **Update the card-count assertion** in `tests/unit/test_card_registry.gd`
  (it pins the registry size — see BID-007 history) so the suite stays green.
- **Tests:** registry loads the new cards; effect resolution unit tests (with TID-363).

## Plan

Create 5 new `.tres` card files + `.uid` sidecars, register them in `CardRegistry.gd`,
add match arms in `SpellEffectResolver.gd`, and update the test count. All 5 cards use
`card_class = "spell"` and `magic_type = "light"` so they fit the dawn/ember support
theme. In solo/2-player the resolver falls back to `caster_pid` (self-target).

## Changes Made

- `data/cards/coop_aegis.tres` + `.uid` — "Aegis Pact" (cost 2): grant Ward to all
  minions on an ally's board. `spell_effect = "ally_grant_ward_board"`.
- `data/cards/coop_mend.tres` + `.uid` — "Mending Light" (cost 2): restore 5 HP to an
  ally's hero. `spell_effect = "ally_heal_hero"`, `spell_power = 5`.
- `data/cards/coop_rally.tres` + `.uid` — "Rally Cry" (cost 3): give all minions on an
  ally's board +1 ATK and +1 HP. `spell_effect = "ally_buff_minion_all"`, `spell_power = 1`.
- `data/cards/coop_mana_tithe.tres` + `.uid` — "Mana Tithe" (cost 1): give an ally +1
  mana this turn. `spell_effect = "ally_grant_mana"`, `spell_power = 1`.
- `data/cards/coop_second_wind.tres` + `.uid` — "Second Wind" (cost 3): revive the last
  minion that died on an ally's board. `spell_effect = "ally_revive"`.
- `autoloads/CardRegistry.gd`: added 5 const preloads (`_C_COOP_*`) + added them to the
  `_ensure_loaded()` array.
- `tests/unit/test_card_registry.gd`: updated count assertion from 100 → 105.

## Documentation Updates

Updated `docs/agent/multiplayer-coop.md` with GID-100 co-op support cards section.
