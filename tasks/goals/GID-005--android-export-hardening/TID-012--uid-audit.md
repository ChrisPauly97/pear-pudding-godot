# TID-012: Audit All Resource Files for Missing `.uid` Sidecars

**Goal:** GID-005
**Type:** agent
**Status:** done
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

Audit all `.gdshader`, `.tres`, and `.material` files in the repository. For each, verify:
1. A `.uid` sidecar exists alongside it
2. The sidecar contains a valid `uid://[a-z0-9]{12}` string
3. No two sidecars share the same UID

No `.material` files exist. All `.gdshader` and `.tres` files already have sidecars — no new files needed.

## Changes Made

Audit only — no file changes required. Results:

**`.gdshader` files (4):** All have valid `.uid` sidecars.
- `assets/shaders/grass.gdshader` → `uid://1yf6xpsq1cf6`
- `assets/shaders/grass_blade.gdshader` → `uid://0ay5och8tpn7`
- `assets/shaders/grass_cluster.gdshader` → `uid://8hjqisx56pm2`
- `assets/shaders/terrain.gdshader` → `uid://304bl6hs4h90`

**`.tres` files (8):** All have valid `.uid` sidecars.
- `data/cards/ghost.tres` → `uid://yr6onn7kz1jw`
- `data/cards/ghoul.tres` → `uid://uzwfq9t6z4oq`
- `data/cards/skeleton.tres` → `uid://gj2baw77ck8e`
- `data/cards/zombie.tres` → `uid://fj711l3ly44c`
- `data/enemies/ghoul_pack.tres` → `uid://xz5udp37ourr`
- `data/enemies/undead_basic.tres` → `uid://iugru6ekzfxi`
- `data/enemies/undead_elite.tres` → `uid://4dd3zeq76nhv`
- `data/enemies/undead_horde.tres` → `uid://rl5ms4ofets9`

**`.material` files:** None exist in the project.

**Duplicates:** None found.

**Note:** Many `.gd.uid` sidecar files exist in the repo (created by the Godot editor). Per CLAUDE.md, plain `.gd` scripts embed UIDs inline and do not need sidecars. These files are harmless but unnecessary.

## Documentation Updates

None required — CLAUDE.md already documents the `.uid` sidecar requirement and the correct format.
