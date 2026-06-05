# TID-128: Tree Layout with Connector Lines

**Goal:** GID-033
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

The skill tree UI currently uses a `GridContainer` to display skill nodes. While prerequisite enforcement already exists in `_prerequisites_met()`, the flat grid gives no visual indication that skills unlock top-down. This task replaces the grid with an absolute-positioned layout that draws vertical `ColorRect` connector bars between prerequisite-linked nodes, making the tree hierarchy explicit.

## Research Notes

### Current layout (`scenes/ui/SkillTreeScene.gd`)

- `_build_ui()` creates: outer panel → margin → VBox → header + tab bar + `ScrollContainer` → `GridContainer` (`_grid`)
- `_refresh()` populates `_grid` (stored as `_grid: GridContainer`) with skill nodes + spacers for empty cells
- Constants: `_ROWS = 3`, `_COLS = 4`
- Node size computed as: `node_w = (_vw * 0.90 - _vw * 0.015 * 3) / 4.0`, `node_h = _vh * 0.19`

### Skill positions per branch

All branches use only cols 0 and 3 — two independent vertical chains:
- Left chain  (col 0): row 0 → row 1 → row 2
- Right chain (col 3): row 0 → row 1 → row 2

No cross-column prerequisite links exist, so all connectors are straight vertical bars.

### Data model (verified from .tres files)

Every skill's `prerequisites` array contains exactly the skill one row above it in the same column (or is empty for row-0 skills). This is already correct — no .tres changes needed.

### Branch colors (from `_tab_color()` in SkillTreeScene)
| Branch | Color |
|--------|-------|
| ember  | Color(1.0, 0.7, 0.4) |
| dawn   | Color(1.0, 1.0, 0.55) |
| dusk   | Color(0.7, 0.5, 1.0) |
| ash    | Color(0.65, 0.65, 0.65) |

### Cross-magic tab

The cross-magic tab shows skills from the opposing magic type that have `alt_cost > 0`. These have no parent-child relationships in the cross-magic view, so they keep the current flat grid rendering unchanged.

## Plan

### Replace `_grid: GridContainer` with absolute-positioned `Control`

1. **Change the stored container field** from `GridContainer` to `Control`:
   ```gdscript
   var _skill_container: Control  # replaces _grid: GridContainer
   ```

2. **In `_build_ui()`**, replace the `GridContainer` instantiation with a plain `Control`:
   ```gdscript
   var scroll := ScrollContainer.new()
   scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
   root_vbox.add_child(scroll)

   _skill_container = Control.new()
   scroll.add_child(_skill_container)
   ```

3. **In `_refresh()` (home-branch tabs)**, calculate positions and populate:

   ```gdscript
   var node_w: float = (_vw * 0.90 - _vw * 0.04) / 2.0   # 2 visible columns
   var node_h: float = _vh * 0.19
   var col_gap: float = _vw * 0.04    # horizontal gap between left and right chains
   var row_gap: float = _vh * 0.06    # vertical gap between rows (connector space)
   var connector_w: float = _vw * 0.012

   # Map tree_col → x position (col 0 = left, col 3 = right)
   var col_x: Dictionary = {
       0: 0.0,
       3: node_w + col_gap,
   }

   # Clear old children
   for child in _skill_container.get_children():
       child.queue_free()

   # Build skill map keyed by (row, col)
   var skill_map: Dictionary = {}
   for sid in ids:
       var sk: SkillData = SkillRegistry.get_skill(sid)
       if sk != null:
           skill_map["%d,%d" % [sk.tree_row, sk.tree_col]] = sk

   # Place connector bars FIRST (so they render behind skill nodes)
   var branch_color: Color = _tab_color(_active_tab)
   for r in range(_ROWS - 1):   # 0 and 1
       for col in [0, 3]:
           var parent_key: String = "%d,%d" % [r, col]
           var child_key: String = "%d,%d" % [r + 1, col]
           if not (skill_map.has(parent_key) and skill_map.has(child_key)):
               continue
           var parent_sk: SkillData = skill_map[parent_key]
           var child_sk: SkillData = skill_map[child_key]
           # Only draw if child has parent as prerequisite
           if not (parent_sk.id in child_sk.prerequisites):
               continue
           var parent_unlocked: bool = SceneManager.save_manager.has_skill(parent_sk.id)
           var bar := ColorRect.new()
           bar.color = branch_color if parent_unlocked else Color(branch_color.r, branch_color.g, branch_color.b, 0.25)
           var bar_x: float = col_x[col] + (node_w - connector_w) * 0.5
           var bar_y: float = float(r) * (node_h + row_gap) + node_h
           bar.position = Vector2(bar_x, bar_y)
           bar.size = Vector2(connector_w, row_gap)
           _skill_container.add_child(bar)

   # Place skill nodes
   for r in _ROWS:
       for col in [0, 3]:
           var key: String = "%d,%d" % [r, col]
           if not skill_map.has(key):
               continue
           var sk: SkillData = skill_map[key]
           var node := _make_skill_node(sk, node_w, node_h, false)
           node.position = Vector2(col_x[col], float(r) * (node_h + row_gap))
           _skill_container.add_child(node)

   # Set container height so ScrollContainer knows the content size
   var total_h: float = float(_ROWS) * node_h + float(_ROWS - 1) * row_gap
   var total_w: float = node_w * 2.0 + col_gap
   _skill_container.custom_minimum_size = Vector2(total_w, total_h)
   ```

4. **Cross-magic tab** (`_active_tab == 2`) — keep original GridContainer approach but stored in `_skill_container` cast as needed. Simplest: for cross-magic, populate `_skill_container` as a `GridContainer` child, or just add a `GridContainer` as a child of `_skill_container`. 

   Actually cleanest: for cross-magic, clear `_skill_container` children and add a `GridContainer` child to it with the existing cross-magic grid logic. The `_skill_container` Control just acts as a wrapper.

5. **`_refresh()` cross-magic branch** stays functionally identical to current code — create a `GridContainer`, add skill node children, add it to `_skill_container`.

### `_make_skill_node` change

The method signature and logic stay the same. It returns a `PanelContainer`. The caller now sets its `.position` for home-branch tabs.

### Fields to rename/add

```gdscript
# Replace:
var _grid: GridContainer
# With:
var _skill_container: Control
```

All references to `_grid` in `_build_ui()` and `_refresh()` must use `_skill_container`.

### Files to modify

- `scenes/ui/SkillTreeScene.gd` — only file changed

## Changes Made

- `scenes/ui/SkillTreeScene.gd`:
  - Removed `_grid: GridContainer` and `_COLS` constant; replaced with `_skill_container: Control`.
  - `_build_ui()`: replaced `GridContainer` instantiation with a plain `Control` child of `ScrollContainer`.
  - `_refresh()`: home-branch path now builds an absolute-positioned layout — computes `(node_w, node_h, col_gap, row_gap, connector_w)`, maps `tree_col` values 0/3 to left/right x positions, adds `ColorRect` connector bars (branch color at full alpha when parent unlocked, 25% alpha when locked) before placing skill `PanelContainer` nodes at their `(tree_row, tree_col)` coordinates. Sets `_skill_container.custom_minimum_size` so the `ScrollContainer` scrolls correctly.
  - Added `_refresh_cross_magic()`: adds a 2-column `GridContainer` child to `_skill_container` with the existing cross-magic skill nodes. No connectors.

## Documentation Updates

- `docs/agent/skill-trees.md`: updated "SkillTreeScene" section with full description of the tree layout (absolute positioning, connector bar dimensions and colors, cross-magic tab wrapper pattern).
