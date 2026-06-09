# TID-203: Garden Model

**Goal:** GID-056  
**Type:** agent  
**Status:** pending  
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

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
