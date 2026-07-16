# BID-051: Character walk-animation frames on disk but not wired

**Category:** enhancement (deferred optional scope)
**Discovered During:** GID-118 / TID-446

## Description

TID-445 shipped 4-frame walk/idle animations for every enemy archetype and for
Maiteln (`assets/textures/characters/<slot>_walk_{1-4}.png`, 39 files; mimic has 3).
TID-446 deliberately did not wire them: every entity call site uses a static
`Sprite3D`, and animating would need an `AnimatedSprite3D` swap plus
movement-state plumbing (play "walk" while wandering/following, "idle" when
stationary) per entity — non-trivial for EnemyNPC (wander AI) and
MaitelnFollower (follow/network lerp). The `AvatarSprite.build()` SpriteFrames
pattern is the template to follow.

Most valuable first target: **MaitelnFollower** (he visibly walks beside the
player constantly; a static sprite gliding around is the most noticeable).

## Evidence

- `game_logic/SpriteRegistry.gd` — only static textures preloaded/wired.
- `scenes/world/entities/MaitelnFollower.gd` `_process()` — position lerp with
  no animation state.
- `scenes/world/entities/AvatarSprite.gd` — the idle/walk SpriteFrames pattern.
