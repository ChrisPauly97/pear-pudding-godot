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

## Resolution

Wired **MaitelnFollower only**, per the "most valuable first target" note above.
Investigated the other candidates first: `EnemyNPC`/`ScoutAmbush`/
`TownspersonNPC`/`MerchantNPC` are all fully static in the world (no `_process()`
movement anywhere in those scripts, confirmed by reading them and grepping for
"wander" — the only hits were dialogue strings and an unrelated
`is_roaming_boss` spawn/despawn timer, not visual movement) — animating a walk
cycle on an entity that never moves would show a pointless idle-twitch, so
their walk frames stay unwired and on disk for potential future use (e.g. if
enemy wander AI is ever added).

Maiteln implementation: `SpriteRegistry.maiteln_walk_frames()` (4 literal
preloads) + `MaitelnFollower._build_animated_sprite()` (mirrors
`AvatarSprite.build()`'s idle/walk `SpriteFrames` pattern) replace the static
`Sprite3D`, gated behind a fallback to the old static path if the registry or
walk frames are ever missing. `_process()` now computes movement from the
squared distance to this frame's follow/network target (a `_MOVE_EPS_SQ`
threshold treats "arrived" as idle rather than perpetually re-triggering
"walk" while settling) and flips `flip_h` from the screen-space movement
direction, mirroring `Player.gd`'s existing steering-intent pattern.

## Evidence

- `game_logic/SpriteRegistry.gd` — only static textures preloaded/wired.
- `scenes/world/entities/MaitelnFollower.gd` `_process()` — position lerp with
  no animation state.
- `scenes/world/entities/AvatarSprite.gd` — the idle/walk SpriteFrames pattern.
