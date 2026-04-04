# TID-052: Remove Bundling Pipeline

**Goal:** GID-017
**Type:** agent
**Status:** pending
**Depends On:** TID-049, TID-050, TID-051

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Once all loading paths use the new `.tres` / `MapRegistry` system (TID-049, TID-050, TID-051), the old bundling pipeline can be safely deleted. This task does the cleanup: removes `bundle_maps.py`, `BundledMaps.gd`, the `.txt` source maps, and updates `CLAUDE.md` and the CI workflow.

## Research Notes

**Files to delete:**
- `scripts/bundle_maps.py`
- `game_logic/world/BundledMaps.gd`
- `assets/maps/*.txt` (all 6 — `.tres` versions committed in TID-047)

**`CLAUDE.md` — section to replace:**
Remove the entire "Map Bundling: Always Re-bundle After Editing Maps" section (currently says to run `python3 scripts/bundle_maps.py` after any map edit).

Replace with a new section:
```markdown
## Map Storage: Native Godot .tres Resources

Maps are stored as `.tres` resource files in `assets/maps/`. The 6 built-in maps
are preloaded by `autoloads/MapRegistry.gd`, which Godot automatically includes in
exports.

**Whenever you add a new built-in map:**
1. Create `assets/maps/<name>.tres` (use the in-game editor or write a converter script).
2. Add a `const _NAME := preload("res://assets/maps/<name>.tres")` to `MapRegistry.gd`.
3. Add the name to the `_BUNDLED` dictionary in `MapRegistry.gd`.

No bundling step needed. Godot handles export inclusion automatically.
```

**`.github/workflows/android-build.yml`** — check for and remove any step that runs `bundle_maps.py` or references `BundledMaps.gd`. Look for lines like:
```yaml
- name: Bundle maps
  run: python3 scripts/bundle_maps.py
```

**`.gitignore`** — check if `BundledMaps.gd` is excluded; if so, remove that line (the file is deleted).

**`project.godot`** — check if BundledMaps is listed as an autoload; if so, remove it. (It was a regular const file, not an autoload — but verify.)

**After deletion**: run `godot --headless --path . -s tests/runner.gd` to confirm everything still works.

**Key files:**
- `CLAUDE.md` — update map workflow instructions
- `.github/workflows/android-build.yml` — remove bundling step
- `scripts/bundle_maps.py` — delete
- `game_logic/world/BundledMaps.gd` — delete
- `assets/maps/*.txt` — delete
- `project.godot` — verify no BundledMaps reference

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
