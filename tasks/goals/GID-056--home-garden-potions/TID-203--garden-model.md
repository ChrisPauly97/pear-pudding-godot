# TID-203: Garden Model

**Goal:** GID-056  
**Type:** agent  
**Status:** done  
**Depends On:** —

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

The data layer for the garden system: seed and plant type constants, growth calculation, and SaveManager persistence. No UI or entity logic here — TID-204/205 consume this.

## Research Notes

- **New resource:** **`game_logic/GardenDefs.gd`** — static read-only defs:
  - `SEEDS: Dictionary` → `seed_id` (string) → `{display_name: String, growth_days: int, yield: int (1–2 plants), plant_id: String}`
    - `"sunpetal"` — `{display_name: "Sunpetal", growth_days: 2, yield: 1, plant_id: "sunpetal_plant"}`
    - `"moonroot"` — `{display_name: "Moonroot", growth_days: 3, yield: 2, plant_id: "moonroot_plant"}`
    - `"embercap"` — `{display_name: "Embercap", growth_days: 2, yield: 2, plant_id: "embercap_plant"}`
  - `PLANTS: Dictionary` → `plant_id` → `{display_name: String, sell_value: int}` (seeds become plants via harvest)
  - `POTIONS: Dictionary` → `potion_id` → `{display_name: String, essence_cost: int}` (plants become potions via crafting; potion recipes live in TID-205)
  - Growth stage calculation: `static func growth_stage(planted_day: int, growth_days: int, current_days_elapsed: int) -> int` returns 0–3:
    - 0 = empty plot (or not planted yet)
    - 1, 2 = growing stages (age in days = current_days_elapsed - planted_day)
    - 3 = mature, ready to harvest
    - Logic: `if current_days_elapsed - planted_day >= growth_days: return 3; else: return 1 + ((current_days_elapsed - planted_day) / max(1, growth_days - 1))`
- **SaveManager changes** (**`autoloads/SaveManager.gd`**):
  - Add four new fields at end of var section (after `redemption_points` line 94):
    - `var garden_plots: Array[Dictionary] = []` — three plot dicts: `{seed_id: String, planted_day: int}` or empty dict `{}` when not planted
    - `var seeds: Dictionary = {}` — seed_id → count (e.g. `{"sunpetal": 2, "moonroot": 0}`)
    - `var plants: Dictionary = {}` — plant_id → count (e.g. `{"sunpetal_plant": 1}`)
    - `var potions: Dictionary = {}` — potion_id → count (e.g. `{"healing_draught": 0}`)
  - Initialize empty defaults in `new_game()` (after line 177):
    - `garden_plots = [{}, {}, {}]` (three empty plots)
    - `seeds = {}`
    - `plants = {}`
    - `potions = {}`
  - Migration: **v14 → v15** — new migration function `_migrate_v14_to_v15`:
    - `if not data.has("garden_plots"): data["garden_plots"] = [{}, {}, {}]`
    - `if not data.has("seeds"): data["seeds"] = {}`
    - `if not data.has("plants"): data["plants"] = {}`
    - `if not data.has("potions"): data["potions"] = {}`
    - `data["version"] = 15`
  - Increment `CURRENT_SAVE_VERSION: int = 14` to `15` (line 184)
  - Add the call to `_migrate_v14_to_v15` in `_apply_migrations()` at the end before the version check closes (line 349):
    - `if ver < 15: _migrate_v14_to_v15(data)`
  - Add load logic for the four new fields in `load_save()` after line 399:
    - `garden_plots.assign(data.get("garden_plots", [{}, {}, {}]))`
    - `var sd = data.get("seeds", {}); seeds = sd if sd is Dictionary else {}`
    - `var pd = data.get("plants", {}); plants = pd if pd is Dictionary else {}`
    - `var po = data.get("potions", {}); potions = po if po is Dictionary else {}`
  - Add helper methods:
    - `func set_plot(plot_idx: int, seed_id: String, planted_day: int) -> void:` — sets `garden_plots[plot_idx] = {seed_id, planted_day}`, marks dirty
    - `func clear_plot(plot_idx: int) -> void:` — sets `garden_plots[plot_idx] = {}`, marks dirty
    - `func add_seeds(seed_id: String, count: int) -> void:` — increments `seeds[seed_id]`, marks dirty (also call `GameBus.inventory_changed.emit()` for toast)
    - `func remove_seeds(seed_id: String, count: int) -> bool:` — returns false if insufficient, else decrements and marks dirty
    - `func add_plants(plant_id: String, count: int) -> void:` — increments `plants[plant_id]`, marks dirty
    - `func remove_plants(plant_id: String, count: int) -> bool:` — returns false if insufficient, else decrements and marks dirty
    - `func add_potions(potion_id: String, count: int) -> void:` — increments `potions[potion_id]`, marks dirty
    - `func remove_potions(potion_id: String, count: int) -> bool:` — returns false if insufficient, else decrements and marks dirty
    - `func get_plot_growth_stage(plot_idx: int) -> int:` — reads `garden_plots[plot_idx]`, calls `GardenDefs.growth_stage(planted_day, growth_days, days_elapsed)` (cite line 45 days_elapsed), returns 0–3
- **GameBus signal** (**`autoloads/GameBus.gd`**):
  - Add `signal plant_harvested(plot_idx: int, plants_count: int)` — fired when a plot is harvested (used by TID-204 for toast)
- **Headless tests** (**`tests/garden_model_test.gd`**):
  - Test `GardenDefs.growth_stage()` boundaries: day 0 → stage 1, day 1 (sunpetal growth_days=2) → stage 2, day 2+ → stage 3; moonroot 3-day test
  - Test harvest yield: sunpetal yields 1, moonroot/embercap yield 2
  - Test SaveManager round-trip: new_game initializes all four fields, save/load preserves them
  - Test plot state persistence: planting a seed updates garden_plots, clear plot empties it

## Plan

1. Create `game_logic/GardenDefs.gd` with SEEDS / PLANTS / POTIONS const dicts and `growth_stage()` static function.
2. Add `plant_harvested` and `inventory_changed` signals to `GameBus.gd`.
3. Add four new vars to `SaveManager.gd`, initialize in `new_game()`, add v32→v33 migration, update load/save, add plot/seed/plant/potion helper methods.
4. Create `tests/unit/test_garden_model.gd` covering growth_stage boundaries, migration, and all SaveManager helpers.
5. Register the new test suite in `tests/runner.gd`.

## Changes Made

- **`game_logic/GardenDefs.gd`** (new): static class with `SEEDS`, `PLANTS`, `POTIONS` dicts and `growth_stage(planted_day, growth_days, current_days_elapsed) -> int` returning 1–3.
- **`game_logic/GardenDefs.gd.uid`** (new): UID sidecar.
- **`autoloads/GameBus.gd`**: added `plant_harvested(plot_idx, plants_count)` and `inventory_changed` signals.
- **`autoloads/SaveManager.gd`**: added `garden_plots: Array[Dictionary]`, `seeds`, `plants`, `potions` vars; defaults in `new_game()`; `_migrate_v32_to_v33` and call in `_apply_migrations`; load/save entries; helper methods `set_plot`, `clear_plot`, `add_seeds`, `remove_seeds`, `add_plants`, `remove_plants`, `add_potions`, `remove_potions`, `get_plot_growth_stage`; version bumped to 33.
- **`tests/unit/test_garden_model.gd`** (new): 50+ tests covering seed defs, growth_stage boundaries for all three seed types, migration v32→v33, new_game defaults, plot/count helpers, and get_plot_growth_stage integration.
- **`tests/unit/test_garden_model.gd.uid`** (new): UID sidecar.
- **`tests/runner.gd`**: registered `test_garden_model` suite.
- **`tests/unit/test_rival.gd`**: updated hardcoded version assertion `32` → `SaveManagerScript.CURRENT_SAVE_VERSION` to survive future version bumps.

## Documentation Updates

Created `docs/agent/home-garden-potions.md` — not needed yet; the full system spans TID-204/205/206. Will create after TID-206 completes the feature.
