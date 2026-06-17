# TID-204: Garden Plot Entities

**Goal:** GID-056  
**Type:** agent  
**Status:** done  
**Depends On:** TID-203 (+ GID-046 TID-173)

## Lock

**Session:** none  
**Acquired:** —  
**Expires:** —

## Context

Garden plot entities spawned in the player home interior map (created by GID-046 TID-173). Three interactable plots that grow seeds into harvestable plants. Growth state renders sprite-based visual progression. Coordinate with GID-046 TID-173 for interior map design, entity spawn locations, and door entry point.

## Research Notes

- **Dependency on GID-046 TID-173:** The interior map **`assets/maps/player_home.tres`** will be created by TID-173 of GID-046. That task specifies a ~12×10 tile interior with spawn point at `(6, 5)` and exit door at `(6, 1)`. TID-204 must coordinate: the three garden plots should be placed at fixed tile coordinates in that map (e.g. `(3, 7)`, `(6, 7)`, `(9, 7)` in the eastern side of the house, or another sensible layout — verify with TID-173's room plan before building). If the map's entity spawn system is driven by a WorldScene loader or by explicit entity placement in MapData, coordinate the spawn pattern (cite **`game_logic/world/resources/MapData.gd`** structure). The plots are **NOT** respawning entities — they're persistent interior decorations tied to save state.

- **Entity model:** Base on the closest similar entity. **`scenes/world/entities/Chest.gd`** (line 1) is a good template:
  - `extends Node3D`
  - Stores `plot_data: Dictionary = {}`
  - `init_from_data(data: Dictionary)` populates the dict
  - Interact signal → WorldScene's interact handler
  - Cite **`scenes/world/entities/Chest.gd`** lines 1–30 for the pattern

- **New entity script:** **`scenes/world/entities/GardenPlot.gd`**:
  - `extends Node3D`
  - `var plot_idx: int = 0` — which of the 3 plots (0, 1, 2)
  - `var _sprite: Sprite3D` — the plant visual (shows empty, seed, growing, mature)
  - `var _last_drawn_stage: int = -1` — to avoid re-rendering every frame
  - Signals: `interacted` (emitted on click/touch)
  - `_ready()`: create Sprite3D child with `billboard = BILLBOARD_ENABLED`, pixel_size 0.04 (to match world scale), position at Y offset to clear ground (cite CLAUDE.md Sprite3D depth clipping rule: sprite is 48px tall → 48 × 0.04 = 1.92 world units, half = 0.96, so `position.y = 1.1` to keep bottom edge at y~0.14, above floor at y=0)
  - `_process()`: fetch current plot state from SaveManager.garden_plots[plot_idx], get growth stage via SaveManager.get_plot_growth_stage(plot_idx), redraw sprite if stage changed
  - `_on_interact()` (on left-click / touch): handle two flows:
    1. **Empty plot (stage 0):** show seed picker popup (cite picker pattern — check **`scenes/ui/CharacterScene.gd`** from GID-029/GID-041 for companion/equipment picker UI pattern; reuse or build a simple PickerPanel: VBoxContainer with Labels showing seed counts + Select button per seed)
       - Picker shows owned seeds (from SaveManager.seeds dict) with counts
       - Player selects a seed → calls `SaveManager.set_plot(plot_idx, seed_id, SaveManager.days_elapsed)`, `SaveManager.remove_seeds(seed_id, 1)`, emits `GameBus.plant_harvested(plot_idx, 0)` for toast "Planted sunpetal" (reuse AchievementToast.show_text pattern, cite line 67)
    2. **Mature plot (stage 3):** harvest immediately
       - Look up seed_id in garden_plots[plot_idx]
       - Fetch yield count from GardenDefs.SEEDS[seed_id]["yield"]
       - Get plant_id from GardenDefs.SEEDS[seed_id]["plant_id"]
       - Call `SaveManager.add_plants(plant_id, yield)`, `SaveManager.clear_plot(plot_idx)`, emit `GameBus.plant_harvested(plot_idx, yield)` for toast "Harvested 2× Sunpetal"
       - If yield is 0 or plant_id missing, skip
  - Sprite rendering: call `_render_sprite()` every frame or on state change
    - Stage 0 (empty): render empty soil texture or gray square
    - Stage 1–2 (growing): render a mid-growth plant sprite (different per seed type)
    - Stage 3 (mature): render a fully-grown plant sprite (different per seed type)
    - Sprites generated via **TextureGen pattern** (cite **`game_logic/TextureGen.gd`** — verify that static methods exist for `grass()`, `stone()`, etc. If not, use preload `.png` textures from `assets/textures/garden/` instead; note the decision: **"generated via TextureGen static methods OR preloaded .png textures"**)

- **Interior map entity spawning (GID-046 TID-173 coordination):**
  - When the interior map loads, WorldScene or MapLoader must spawn three GardenPlot entities at their fixed tile coordinates
  - Cite how entities are spawned in named maps: check **`game_logic/world/resources/MapData.gd`** for an `entities: Array[Dictionary]` or similar structure; or check **`scenes/world/WorldScene.gd`** for the entity loading path (search for `_spawn_entities` or `_load_map_entities`)
  - TID-204 provides the entity spawn data format (e.g. `{entity_type: "garden_plot", entity_id: "garden_plot_0", x: 3, z: 7}`) to be included in the MapData for the interior
  - On load, each GardenPlot calls `init_from_data({plot_idx: 0})` to link to the save state

- **Seed picker popup:** Simple UI pattern:
  - CanvasLayer overlay (above world)
  - PanelContainer with title "Choose a seed"
  - VBoxContainer listing each seed with `Label: count` + `Button: Plant`
  - "Cancel" button
  - Cite **`scenes/ui/CharacterScene.gd`** (GID-029/GID-041) for picker scaffolding; reuse the same Control layout if code is available
  - If CharacterScene picker is too specialized, build inline in GardenPlot `_show_seed_picker()` as a local nested scene

- **Headless tests** (**`tests/garden_plot_test.gd`**):
  - Pure logic test: mock SaveManager state, call picker logic, verify plot update and seed deduction
  - Test harvest yield: call harvest on mature plot, verify plants added to inventory
  - Test growth-stage sprite update: call `_render_sprite()` for each stage 0–3, verify sprite texture changes
  - Test insufficient seeds: try to plant when owned count is 0, verify nothing happens

## Plan

1. Create `scenes/world/entities/GardenPlot.gd`:
   - `extends Node3D` with `plot_idx: int`
   - `init_from_data(data: Dictionary)` sets plot_idx
   - `MeshInstance3D` visual swapped per growth stage (0=empty brown box, 1=small green, 2=medium green, 3=tall green+yellow top)
   - `refresh_visual()` reads stage from SaveManager and updates mesh
   - Connects `GameBus.plant_harvested` to refresh visual

2. Create `scenes/world/entities/GardenPlot.gd.uid`.

3. Update `scenes/world/WorldScene.gd`:
   - Preload GardenPlot script as `_GardenPlotScript`
   - Add `_garden_plot_nodes: Array[Node3D] = []` field
   - Add `_spawn_player_home_garden()` placing 3 plots at tiles (52,54), (55,54), (58,54)
   - Call `_spawn_player_home_garden()` in the `if map_name == "player_home"` block (after `_spawn_player_home_trophies()`)
   - Add `_find_nearby_garden_plot(px, pz, r) -> Node3D` 
   - In `_check_interactions()`: include garden plot in "show interact label" check
   - In `_handle_interact()`: call `_show_garden_plot_panel(plot_node)` when near a plot
   - Add `_show_garden_plot_panel(plot_node: Node3D)`:
     - Stage 0: seed picker (VBox with "Plant [Seed] (N owned)" buttons per seed)
     - Stage 1-2: info dialog "Growing — ready in N days"
     - Stage 3: harvest button (adds plants to inventory, clears plot, toasts)

4. Create `tests/unit/test_garden_plot.gd` + UID:
   - Test init_from_data sets plot_idx
   - Test growth stage reading via SaveManager
   - Test harvest: plants inventory increases, plot cleared
   - Test seed plant: seeds decremented, plot_idx set in garden_plots

## Changes Made

- **`scenes/world/entities/GardenPlot.gd`** (new): Node3D entity for a garden plot. `init_from_data({plot_idx})` sets the index. Visual renders a brown soil trough plus a coloured box that grows across 4 stages (0=empty, 1=sprout, 2=growing, 3=mature+flower). `refresh_visual()` reads the stage from `SaveManager.get_plot_growth_stage(plot_idx)` and redraws only when stage changes. `GameBus.plant_harvested` signal connected for auto-refresh after harvest.
- **`scenes/world/entities/GardenPlot.gd.uid`** (new): UID sidecar `uid://wwit6h0rybue`.
- **`scenes/world/WorldScene.gd`**: Added `_GardenPlotScript` and `GardenDefs` preloads; `_garden_plot_nodes: Array[Node3D]` tracking field; `_spawn_player_home_garden()` placing 3 plots at tile coords (52,54), (55,54), (58,54) (south-east area of home interior, mirroring trophy north-side layout); call to `_spawn_player_home_garden()` in the `player_home` map branch (after `_spawn_player_home_trophies()`); `_find_nearby_garden_plot()` proximity helper; garden plot check added to `_check_interactions()` and `_handle_interact()`; `_show_garden_plot_panel()` presenting stage-appropriate UI (seed picker for empty plots, growth info for stages 1–2, harvest button for stage 3), sized viewport-relative per CLAUDE.md.
- **`tests/unit/test_garden_plot.gd`** (new): 21 tests covering `init_from_data` field assignment, `set_plot`/`clear_plot`/`add_seeds`/`remove_seeds`/`add_plants` helpers, harvest yield for all three seeds, `get_plot_growth_stage` boundaries for sunpetal and moonroot, and planted-day offset correctness.
- **`tests/unit/test_garden_plot.gd.uid`** (new): UID sidecar `uid://k5dlmdmxbj53`.
- **`tests/runner.gd`**: registered `test_garden_plot` suite.

## Documentation Updates

Agent docs for the home-garden system will be written after TID-206 completes the full feature (per TID-203 decision).
