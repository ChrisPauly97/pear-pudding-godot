# BID-004: Orphaned ChestOpenScene.gd.uid sidecar with no matching script

**Category:** code-smell
**Discovered During:** GID-050 / TID-186 research

## Description

`scenes/ui/ChestOpenScene.gd.uid` exists but there is no `ChestOpenScene.gd` (or `.tscn`) beside it. The script it belonged to appears to have been deleted without removing the `.uid` sidecar. Similarly `game_logic/world/BundledMaps.gd.uid` and `game_logic/world/ProceduralGen.gd.uid` exist without their `.gd` files (likely leftovers from the GID-017 native map storage migration).

## Evidence

- `ls scenes/ui/` shows `ChestOpenScene.gd.uid` with no `ChestOpenScene.gd`.
- `ls game_logic/world/` shows `BundledMaps.gd.uid` and `ProceduralGen.gd.uid` with no matching `.gd` files.
- Discovered while researching GID-050 (the pack-opening agent looked for an existing reveal-ceremony scene to model on and found only the sidecar).

## Suggested Resolution

Delete the orphaned `.uid` files. They are harmless to gameplay but mislead research (suggesting scenes/scripts exist when they don't) and the Godot editor will not regenerate or use them. Verify with a project-wide scan for other `.uid` files whose primary file is missing.
