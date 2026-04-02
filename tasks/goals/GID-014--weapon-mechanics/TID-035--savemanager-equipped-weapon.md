# TID-035: SaveManager: equipped_weapon field

**Goal:** GID-014
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Persists which weapon Saimtar currently has equipped. A single string field (weapon id) is all that's needed — WeaponRegistry resolves the full resource at battle start. Must follow SaveManager's migration pattern so existing saves upgrade cleanly.

## Research Notes

**File:** `autoloads/SaveManager.gd`

**Current version:** `CURRENT_SAVE_VERSION = 4`

**Migration pattern (copy exactly):**
```gdscript
# 1. Add field at class level
var equipped_weapon: String = ""

# 2. Initialize in new_game()
equipped_weapon = ""

# 3. Add to save() dict
"equipped_weapon": equipped_weapon,

# 4. Load in load_save()
equipped_weapon = str(data.get("equipped_weapon", ""))

# 5. Migration function
static func _migrate_v4_to_v5(data: Dictionary) -> void:
    if not data.has("equipped_weapon"):
        data["equipped_weapon"] = ""
    data["version"] = 5

# 6. Call in _apply_migrations()
if ver < 5:
    _migrate_v4_to_v5(data)

# 7. Bump constant
const CURRENT_SAVE_VERSION: int = 5
```

**No weapon equipped = ""** (empty string). BattleScene checks `if SaveManager.equipped_weapon != ""` before looking up the weapon.

**Existing migration functions to reference:** look at `_migrate_v3_to_v4` for style — they're simple `if not data.has(...)` guards followed by `data["version"] = N`.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
