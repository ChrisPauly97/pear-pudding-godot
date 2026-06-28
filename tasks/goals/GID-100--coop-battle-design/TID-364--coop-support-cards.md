# TID-364: Co-op support card content — ally-affecting cards

**Goal:** GID-100
**Type:** agent
**Status:** pending
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
