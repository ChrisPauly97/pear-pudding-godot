# TID-363: Cross-board card targeting — affect allied boards & heroes

**Goal:** GID-100
**Type:** agent
**Status:** pending
**Depends On:** TID-359

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The mechanic that makes co-op battles *cooperative*: cards that target an **ally's**
board or hero — shield their minions, heal their hero, buff a minion, lend mana, revive.
Today no card can reach another friendly board; targets live on the strict two-player
axis only.

## Research Notes

- **Targeting today:** spells encode `target` as `{}` / `{hero:true}` / `{side, slot}` /
  `{slot}` (`BattleNetProtocol.encode_play_spell`; resolved in the battle effect
  application). `side` is binary (mine/enemy). Card effect definitions live in card
  `.tres` (`data/cards/`) + the effect resolver in `game_logic/battle/` (effect/ability
  text system from GID-035). Grep the effect-application code for how `{side, slot}` is
  resolved to a `PlayerState`/`board.slots[i]`.
- **What to add:**
  - A **player/ally dimension** to targets: extend the target dict with an explicit
    `player`/`pidx` (the protocol room for this is added in TID-360 — coordinate). A
    cross-board effect resolves against `state.players[pidx]` (an ally), not just
    self/enemy.
  - A card-effect **scope flag** (e.g. `target_scope: ally | enemy | any | self`) on
    card data so the resolver and the targeting UI know what's selectable.
  - Targeting **UI**: when playing a cross-board card, highlight valid ally boards/heroes
    (reuse `_slot_highlight_panels` / the slot-targeting flow already in `BattleScene`
    for spells: `_slot_targeting_spell`, `_add_slot_highlights`). Must work on mobile
    (tap-to-target) and desktop.
  - **Networking:** the chosen ally + slot flows through the host-authoritative intent
    (TID-360) so the authority applies the effect to the correct ally and mirrors it.
- **Backward compat:** existing cards have no `player`/scope field → default to the
  current self/enemy behavior so 2-player PvP/NPC/puzzle/Spire are unchanged. Add the
  field with a safe default in card `.tres` loading.
- **Tests:** unit-test effect resolution against an ally `PlayerState` in the N-player
  state (`test_coop_battle_state.gd` or a sibling); protocol round-trip for the new
  target field (extend `test_pvp_protocol.gd`).

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
