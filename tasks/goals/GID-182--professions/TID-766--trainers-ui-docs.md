# TID-766: Profession trainers, unlocks, Character tab, docs

**Goal:** GID-182
**Type:** agent
**Status:** done
**Depends On:** TID-763, TID-764, TID-765

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Ties professions into onboarding and makes progress visible.

## Research Notes

- `game_logic/progression/UnlockLadder.gd`: add `FEAT_ALCHEMY`, `FEAT_COOKING`, `FEAT_CRAFTING` feature rows (level_req, gold cost, trainer, how_to). Gate stations/panels with `save_manager.has_learned(...)` — no separate level checks. New trainers in `TRAINERS` + `TRAINER_NPCS` (Madrian NPCs; authored names → `TownSigns.NAMES`); dispatch in `NpcInteractions.gd`.
- Character screen (`scenes/ui/CharacterScene.gd`): a Professions tab — level, XP bar, known recipe count per profession.
- Optional quest: a starter side quest per profession (`game_logic/quests/SideQuests.gd`).
- Docs: new `docs/agent/professions.md` (Key Features / How It Works / Integrations / Asset Requirements) + a row in the CLAUDE.md docs table; update `starter-zone-and-training.md`, `inventory-and-deck.md`, `save-system.md`.
- Full runner + `scripts/unsafe-hits.sh` + gdlint + world smoke before closing the goal.

## Plan

- One "Master Artisan" trainer (`crafter`) teaches all three professions, rather than one trainer each.
- Three feature rows on the UnlockLadder: Cooking L11 (90g), Alchemy L14 (120g), Crafting L17 (150g). Levels past 10 keep the one-new-thing-per-early-level rule.
- Station gate as a pure function on UnlockLadder (`station_block`); `CraftingStations.show_panel` uses it and toasts the trainer and level when refused. Gathering stays ungated.
- v51 migration grants the three features to every older save.
- Character screen: a Professions block (level, XP bar, known recipes), built in a new small file to keep CharacterScene under gdlint's line limit. It is a section, not a tab, because the screen has no tab bar.
- Optional starter side quest per profession: skipped (large).
- Docs: rewrite `docs/agent/professions.md` as one doc; update starter-zone, inventory-and-deck, save-system; CLAUDE.md docs row.

## Changes Made

- `game_logic/progression/UnlockLadder.gd`: `crafter` trainer, `FEAT_COOKING` / `FEAT_ALCHEMY` / `FEAT_CRAFTING` rows, `PROFESSION_FEATURES`, `profession_feature()`, `station_block()`.
- `game_logic/save/SaveMigrations.gd`: `CURRENT_VERSION` 51, `_m51_profession_trainers` row.
- `assets/maps/madrian.tres`: `crafter_madrian` trainer NPC at town tile (38, 30).
- `game_logic/SpriteRegistry.gd`: `crafter_madrian` uses the townsperson sprite (no artisan art yet).
- `scenes/world/modules/CraftingStations.gd`: the panel is gated on `station_block`; a refusal shows a HUD message.
- `scenes/ui/CharacterProfessions.gd` (new): the Professions block, called from `CharacterScene._build_ui` (one call).
- `tests/unit/test_profession_unlocks.gd` (new, 11 tests): ladder rows, trainer wiring, the gate, gate vs `has_learned`, gathering ungated, v51 migration, a fresh save, the Character block text, and the trainer on open ground.
- `tests/unit/test_cooking.gd`: the migration test now pins the v50 step (`apply(data, 50)`) and expects `CURRENT_VERSION` 51.

Validation: parse check clean; `scripts/unsafe-hits.sh` clean; gdlint clean; full runner 3306 passed, 0 failed, 0 SCRIPT ERROR; `world_scene_smoke` exit 0. WorldScene is untouched.

## Documentation Updates

- `docs/agent/professions.md`: rewritten as one doc (Key Features / How It Works / Integrations / Asset Requirements / Tests / Known gaps). The per-task appendix sections are folded in.
- `docs/agent/starter-zone-and-training.md`: ladder rows 11, 14 and 17; the crafter trainer; v51; station and Character gates.
- `docs/agent/inventory-and-deck.md`: the Craft tab is cards only (potions moved to the alchemy table); the Items tab lists potions and herbs; materials are not in the bag.
- `docs/agent/save-system.md`: v50 and v51 rows in the migration table; a v51 note.
- `CLAUDE.md`: the professions row in the docs table now covers the whole feature.

Not done: co-op harvest broadcast (so the co-op acceptance criterion stays unticked), the optional side quests, and a dedicated Master Artisan sprite.
