# TID-145: Endless Spire Run State & Card-Draft Logic

**Goal:** GID-037
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The Endless Spire is a roguelike mode: enter a tower, fight an enemy per floor, draft one of three cards between floors, and climb until death. This task implements the data model and draft logic. TID-146 wires it into the world.

## Research Notes

- **Run state resource:** A new `SpireRun` GDScript class (not a Resource) or a dict saved under `SaveManager.spire_run`. Fields: `active: bool`, `floor: int`, `draft_deck: Array[String]` (card IDs), `hp: int`, `seed: int`.
- `autoloads/SaveManager.gd` — add `spire_run` field with migration. A null/empty dict = no active run.
- **Card draft:** On completing each floor, show 3 random cards from a weighted pool (common/uncommon/rare weighted by floor depth). Player picks one; it's added to `draft_deck` for the current run only — not their permanent collection.
- **Draft UI:** A new modal scene (or reuse existing card-pick pattern from `InventoryScene`) displaying 3 `CardData` panels with a "Choose" button. Emits `card_drafted(card_id)`.
- **Deck isolation:** During a Spire battle, `PlayerState` uses `draft_deck` instead of `SaveManager.deck`. After the run ends (death or quit), `draft_deck` is discarded.
- `game_logic/battle/PlayerState.gd` — check how deck is initialised; add a `spire_mode: bool` flag or a `override_deck: Array[String]` parameter.
- `scenes/ui/RunSummaryScene.gd` — already exists for meta-progression; extend it to show Spire run stats (floors cleared, cards drafted, enemies defeated).
- `docs/agent/meta-progression.md` — run summary patterns.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
