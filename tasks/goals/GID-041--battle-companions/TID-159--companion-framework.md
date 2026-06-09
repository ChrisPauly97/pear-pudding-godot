# TID-159: Companion Framework (CompanionData, Registry, PlayerState Passive, CharacterScene Slot)

**Goal:** GID-041
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

A minimal companion system: one equipped companion, one passive battle effect, visible in the battle HUD and managed from the character screen. Deliberately small — the value is the story tie-in (TID-160), not a new subsystem.

## Research Notes

- **CompanionData resource:** New `game_logic/battle/CompanionData.gd` (extends Resource; preload where used per CLAUDE.md). Fields:
  - `companion_id: String`, `display_name: String`, `description: String`
  - `passive_type: String` — one of `"extra_mana"` (start battles with +1 mana), `"draw_card"` (draw 1 extra at each turn start), `"hero_armor"` (hero starts with +N armor/HP buffer)
  - `passive_value: int`
  - `unlock_story_flag: String` (empty = always available)
  - `portrait: Texture2D` (optional; fall back to a TextureGen placeholder)
- **CompanionRegistry autoload:** `autoloads/CompanionRegistry.gd`, modelled on `SkillRegistry.gd` (preload consts + `_ensure_loaded()`); register in `project.godot`. Include `is_unlocked(id) -> bool` checking the story flag against SaveManager's flag store (see `docs/agent/story-implementation.md` for the flag API).
- **PlayerState integration:** `game_logic/battle/PlayerState.gd` — at battle setup, if `SaveManager.active_companion` is set and this PlayerState is the human player, apply the passive:
  - `extra_mana` → bump starting mana (check where mana initialises; the 1/turn cap-10 growth must be respected — only the start value changes)
  - `draw_card` → +1 draw at turn start (find the turn-start draw routine in GameState)
  - `hero_armor` → add to `HeroState` starting HP or a separate armor field — check `HeroState.gd`; prefer the simplest representation that the HP bar UI can show
  - **Exclusions:** No companion passive in puzzle battles (GID-040 `puzzle_mode`) or friendly duels vs the AI's PlayerState. Spire battles (GID-038): allowed — it's the player's power.
- `autoloads/SaveManager.gd` — `active_companion: String` (default "") with migration.
- **CharacterScene slot:** `scenes/ui/CharacterScene.gd` (GID-029 multi-slot equipment) — add a companion slot alongside equipment slots, following the existing slot widget pattern. Tapping opens a picker listing all registered companions; locked ones greyed with their unlock requirement text. Mobile-first sizing per CLAUDE.md / GID-036 conventions.
- **Battle HUD:** `scenes/battle/BattleScene.gd` — small portrait + passive tooltip near the player hero portrait. Check the GID-036 battle layout for where it fits; a TextureRect + long-press/hover tooltip (LongPressDetector.gd exists for mobile tooltips).
- **Tests:** Headless: each passive type applies correctly at battle start; no passive in puzzle mode; locked companion can't be activated.
- `docs/agent/battle-system.md` + `docs/agent/inventory-and-deck.md` — document the slot and passives.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
