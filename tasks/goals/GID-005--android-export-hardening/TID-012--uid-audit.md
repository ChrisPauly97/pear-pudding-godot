# TID-012: Audit All Resource Files for Missing `.uid` Sidecars

**Goal:** GID-005
**Type:** agent
**Status:** pending
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Godot generates `.uid` sidecars when it scans files in the editor. Files created by the agent outside the editor skip this scan and have no `.uid`. On Android, `load()` on an untracked resource can silently return `null`, causing crashes. This task finds all missing sidecars and creates them.

## Research Notes

**File types that need `.uid` sidecars:**
- `.gdshader` — terrain shader, grass shader, grass blade shader
- `.tres` — CardData resources, EnemyData resources, any `.material` saved as `.tres`
- `.material` — if any exist separately from `.tres`

**File types that do NOT need sidecars:**
- `.gd` plain scripts — UIDs are inline in the file header
- `.tscn` scenes — UIDs are inline
- `.txt` map files — not Godot resources

**How to audit:**
```bash
# Find all .gdshader files without a matching .uid
find assets/shaders/ -name "*.gdshader" | while read f; do
    if [ ! -f "${f}.uid" ]; then echo "MISSING UID: $f"; fi
done

# Same for .tres
find data/ -name "*.tres" | while read f; do
    if [ ! -f "${f}.uid" ]; then echo "MISSING UID: $f"; fi
done
```

**UID format** (from CLAUDE.md):
```
uid://a1b2c3d4e5f6
```
Exactly 12 lowercase alphanumeric characters after `uid://`.

**Generate a UID:**
```bash
python3 -c "import random,string; print('uid://'+''.join(random.choices(string.ascii_lowercase+string.digits,k=12)))"
```

**Uniqueness:** Each UID must be unique across the whole project. Collect all existing UIDs before generating new ones to avoid collisions. Existing UIDs can be found by grepping all `.uid` files.

**Known shader files** (from codebase scan):
- `assets/shaders/terrain.gdshader` (if exists — check)
- `assets/shaders/grass.gdshader` (if exists)
- `assets/shaders/grass_blade.gdshader` (if exists)

**Known .tres files:**
- `data/cards/*.tres` — CardData resources
- `data/enemies/*.tres` — EnemyData resources

Read the actual directory listing during the task rather than assuming — new files may have been added.

## Plan

_Written during Plan phase._

## Changes Made

_Filled after Build phase._

## Documentation Updates

_What was updated in agent docs._
