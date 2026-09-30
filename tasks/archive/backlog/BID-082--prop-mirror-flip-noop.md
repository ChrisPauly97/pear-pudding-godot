# BID-082: Ground-prop mirror flip is a no-op

**Category:** code-smell
**Discovered During:** GID-152 / TID-647

## Description

`ChunkRenderer._add_prop_multimesh` gives half the non-tree props an x scale of −1 for mirror variety (TID-522),
but the billboard with `billboard_keep_scale` rebuilds the scale from `length(MODEL_MATRIX[0].xyz)`, which drops
the sign. No prop has ever rendered mirrored. The sway shader (`prop_sway.gdshaderinc`) copies the same maths to
keep the look identical.

## Evidence

`scenes/world/ChunkRenderer.gd` `_add_prop_multimesh` (flip), Godot BaseMaterial3D billboard keep-scale code.

## Suggested Resolution

Either drop the flip (dead code) or honour it: flip `UV.x` in the shaders from the sign of the instance basis
determinant (props' baked top-left light would then flip too — why trees opt out).

## Resolution

Dropped the dead flip (and `billboard_keep_scale`) in `ChunkRenderer._add_prop_multimesh`: honouring it would
mirror the props' baked top-left light. Rendering is unchanged.
