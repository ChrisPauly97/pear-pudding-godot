# TID-802: World focus: dim non-combatants, hide name tags, hits / lunges / target ring on world sprites

**Goal:** GID-189
**Type:** agent
**Status:** done
**Depends On:** TID-801

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

In-place fights (GID-135) should read as a fight in the world, not panels.

## Plan

FramesLayout.focus_world() (deferred after build) finds the held world + fighters through new SceneManager accessors; restores everything on the visuals root's tree_exiting.

## Changes Made

- `SceneManager.held_world()`, `battle_enemy_ids()` (engaged + joined).
- `FramesLayout.focus_world`: dims every other world enemy (SpriteBase3D modulate `DIM`), hides world Label3D tags, slides the frozen camera so the fight's midpoint is centred (frames covered the enemy otherwise; the camera re-follows the player on thaw).
- Hits land on the sprites: `hero_point` (token_center) and `BattleFx.hero_point_fn` (hero damage numbers).
- `lunge`: the **sprite child** steps toward its target — a frozen physics body keeps drawing at its last tick, so moving the body showed nothing.
- Red target ellipse under the targeted enemy sprite.
- Detached (off-world) fights: no world, frames only.

## Documentation Updates

- `docs/agent/battle-system.md`.
