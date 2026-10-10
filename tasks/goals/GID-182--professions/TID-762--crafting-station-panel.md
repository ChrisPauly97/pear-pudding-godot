# TID-762: Crafting station panel + stations

**Goal:** GID-182
**Type:** agent
**Status:** done
**Depends On:** TID-759

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

One UI for every profession, opened from a station in the world.

## Research Notes

- `scenes/ui/ProfessionPanel.gd` extends `BaseOverlay`: profession header + level/XP bar, recipe list (greyed if skill too low or inputs missing; colour by difficulty: orange/yellow/green/grey), input list with owned counts, Craft ×1 / ×All. Build widgets with `UiUtil` factories; sizes relative to the viewport; drag scroll is global.
- Stations as entities: cooking fire (reuse `CampfireVisual`), alchemy table and workbench. Place them in the stitched towns (Madrian at least) via `game_logic/world/TownDecor.gd` / `StarterCamps` patterns, and in the player home interior (`PlayerHome` module). Wilderness camps' campfires also act as cooking fires.
- Interaction entry in `INTERACT_PRIORITY` (`crafting_station`) + both chains.
- Existing potion crafting in `scenes/ui/inventory/CraftPanel.gd` (`_potion_row`, `_do_craft_potion`) stays until TID-764 moves it.
- Keyboard + touch parity: station interact via the HUD button; the panel closes on Esc and on its close button.

## Plan

- `game_logic/professions/StationSites.gd` (pure): station sites for Madrian (cooking fire, alchemy table, workbench on open square tiles) and the player home. Station kind → profession via `ProfessionDefs.PROFESSIONS`.
- `scenes/world/entities/CraftingStation.gd`: CampfireVisual fire or a plank table in the profession colour, with a name tag.
- `scenes/world/modules/CraftingStations.gd` (`crafting_stations`): spawns the nodes on the overworld (`main`) and in the home; `show_panel(station)`.
- `scenes/ui/ProfessionPanel.gd` (BaseOverlay): level/XP header, recipe rows by band colour, inputs owned/needed, Craft x1 / Craft x All via `craft_recipe()`.
- WorldScene: `crafting_station` in INTERACT_PRIORITY (after garden_plot, before hostiles), `_find_nearby_crafting_station`, a CRAFT prompt and a handle branch.

## Changes Made

- Added the files above (plus `.uid` sidecars), `tests/unit/test_crafting_stations.gd` (11 tests: placement data, kind → profession, panel lists recipes and disables craft without inputs, Craft x All / x1 / refusal through the save).
- WorldScene.gd: +19 lines for the feature (module preload/var/ensure, nodes var, spawn calls, finder, prompt branch, handle branch, priority entry).
- Validation: import/parse clean, `scripts/unsafe-hits.sh` clean, gdlint clean, `tests/world_scene_smoke.gd` exit 0 with no SCRIPT ERROR, runner 3241 passed with 0 SCRIPT ERROR.
- BLOCKED: `test_worldscene_line_ceiling_guardrail` fails (WorldScene.gd 1906 lines, ceiling 1890; main is at 1887, so only 3 lines of headroom). The guardrail says to extract a coherent cluster rather than raise the ceiling. Needs an owner decision on what to extract. The feature needs roughly 10 WorldScene lines even in its leanest form.
- Not done (by scope): station gating (TID-766), the potion panel move (TID-764), wilderness camp fires as cooking fires.

- Merge (orchestrator): the WorldScene line ceiling (1890) was cleared by moving `_on_scroll_collected` / `_show_narration_overlay` into `NamedMapProps` (`on_scroll_collected`, `show_narration_overlay`); crafting stations now interact through `_try_simple_interaction` (`CraftingStation.interact()` → `on_interact`), and `crafting_station` sits right after `gather_node` in INTERACT_PRIORITY. WorldScene is 1872 lines. Full suite 3265 passed, world smoke clean.

## Documentation Updates

- `docs/agent/professions.md`: appended "Stations & panel (GID-182 / TID-762)".
- `CLAUDE.md`: module table row for `CraftingStations.gd`.
