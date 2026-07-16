# TID-447: Wire Prop, Mount & Card Illustration Sprites + Attribution

**Goal:** GID-118
**Type:** agent
**Status:** done
**Depends On:** TID-445

## Lock

- Session: none
- Acquired: —
- Expires: —

## Context

Companion to TID-446, covering the non-humanoid `TextureGen` slots: biome props, the rideable mount, and card illustrations. Same fallback philosophy: real sprite when the file exists, `TextureGen` procedural art otherwise. If TID-446 has already landed its SpriteRegistry helper, extend it rather than creating a second registry.

## Research Notes

### Call sites to convert

| File | Line (approx) | Today | Target |
|---|---|---|---|
| `scenes/world/ChunkRenderer.gd` | 343 | `TextureGen.prop(str(pt_key))` in `_build_props()` | per-key prop texture; keys are the 10 strings from `BiomeDef.PROP_SETS` (rock, flower, mushroom, fern, cactus, thorn, ash, ember, boulder, lichen) |
| `scenes/world/entities/Player.gd` | 122 | `TextureGen.mount_horse()` | horse sprite |
| `autoloads/CardRegistry.gd` | 178 | `TextureGen.card_illustration(illus_key, magic_branch)` | per-archetype card art (ghost, skeleton, zombie, ghoul) + per-branch spell rune |

### Constraints & gotchas

- **Props are GPU-instanced** by ChunkRenderer (see `docs/agent/visual-polish.md`, GID-089/TID-316) — the texture swap happens where the material/texture is assigned per prop key; keep instancing intact and verify chunk build perf doesn't regress (props rebuild on every chunk load).
- **Card illustrations** flow through `CardRegistry` resource setup (`res.set("illustration", ...)`) — cards are rendered in 2D UI, so nearest-filter import settings matter for crispness; check how the illustration is displayed (battle card UI + inventory) for expected aspect.
- **Mount**: `test_mount_dismount_visuals.gd` asserts against `TextureGen.mount_horse()` (calls it at lines ~173–178, including a caching identity check) — update the test to the new source or keep it exercising the fallback path explicitly; do not leave it asserting stale behavior.
- Android rule: literal `const` preloads only, one per PNG; no dynamic path composition. A dictionary `{"rock": _PropRock, ...}` keyed by prop string is fine (keys literal, values preloaded).
- Run headless parse/import check after every `.gd` edit; full test runner at the end.

### Attribution & docs

- Extend the CREDITS file with prop/mount/card art entries (author, license, URL, verbatim CC-BY text from TID-445).
- Update `docs/agent/art-sprites.md` (entries → "integrated"), `docs/agent/visual-polish.md` (prop scatter + card art sections), `docs/agent/rideable-mounts.md` (sprite + dust visuals section), `docs/agent/inventory-and-deck.md` if card art display details change.

## Plan

1. **Extend `game_logic/SpriteRegistry.gd`** (from TID-446) rather than making a
   second registry — add:
   - `prop_texture(key) -> Texture2D`: 10 literal preloads keyed by the exact
     `BiomeDef.PROP_SETS` strings (`ash_pile`, not `ash` — TID-445 already caught
     this drift). Returns `null` for unknown key → caller falls back.
   - `mount_texture() -> Texture2D`: `mount_horse.png`.
   - `card_illustration_texture(illus_key, magic_branch) -> Texture2D`: ghost/
     skeleton/zombie/ghoul → their PNG; anything else (spells use `illus_key =
     "spell"`) → rune PNG by `magic_branch` (dawn/dusk/ember/ash, the only 4
     branches in `data/cards/`). Returns `null` on an unrecognized branch.
2. **`ChunkRenderer._build_props()`** — swap `TextureGen.prop(key)` for the
   registry lookup with fallback; keep the MultiMesh instancing path identical
   (texture is just the `albedo_texture` on the shared material, so instancing
   is untouched either way).
3. **`Player.gd` mount sprite** — swap `TextureGen.mount_horse()` similarly.
   No test touches the Player mount texture identity (only
   `_mount_sprite.visible`), and `test_mount_dismount_visuals.gd`'s two
   `TextureGen.mount_horse()` assertions test the fallback function directly,
   not Player — no test changes needed, verified by reading the test file.
4. **`CardRegistry.gd`** — swap `TextureGen.card_illustration(illus_key,
   magic_branch)` for the registry lookup with fallback. `illus_key` values
   are `"ghost"/"skeleton"/"zombie"/"ghoul"` (minions) or `"spell"` (spells,
   routed by `magic_branch`) — confirmed by reading `_gen_card_illustration`'s
   match arms.
5. Extend `CREDITS.md` — already has every source from TID-446 since TID-445
   captured all sources up front; add prop/mount/card rows explicitly (they
   were previously only listed generically under "Used for" on the character
   entries — split out so every slot is traceable).
6. Update docs: `art-sprites.md` (flip to fully integrated), `visual-polish.md`
   (props/card art sections), `rideable-mounts.md` (sprite section),
   `inventory-and-deck.md` if illustration display specifics changed (likely
   no code changes there — just confirm aspect/filter behavior is unaffected).
7. Headless parse/import check + full test runner; compare failures against
   the TID-446 baseline (7 pre-existing auction/mailbox asserts, BID-052).

## Changes Made

- **`game_logic/SpriteRegistry.gd` extended** (not a second registry, per the task's
  own instruction) with three new statics:
  - `prop_texture(key)` — 10 literal preloads keyed by the exact `BiomeDef.PROP_SETS`
    strings (correctly `ash_pile`, not the original manifest's `ash`).
  - `mount_texture()` — `mount_horse.png`.
  - `card_illustration_texture(illus_key, magic_branch)` — creature keys
    (ghost/skeleton/zombie/ghoul) map directly; anything else (spells pass
    `illus_key = "spell"`) routes by `magic_branch` (dawn/dusk/ember/ash) to a rune.
  - All three return `null` on an unrecognized key so callers fall back to `TextureGen`.
- **`scenes/world/ChunkRenderer.gd`** `_build_props()` — tries `SpriteRegistry.prop_texture()`
  first, falls back to `TextureGen.prop()`. The MultiMesh instancing path (shared
  material's `albedo_texture`) is unchanged either way — no instancing regression.
- **`scenes/world/entities/Player.gd`** — mount sprite texture from
  `SpriteRegistry.mount_texture()`, falling back to `TextureGen.mount_horse()`.
  **Fixed a latent sizing bug while wiring this**: the old code hardcoded
  `position.y = 0.6`, which only happened to be correct for `TextureGen`'s 24px
  fallback texture. Replaced with the CLAUDE.md feet-at-y=0 formula computed from
  the actual texture height, so it's correct for both the real 32px sprite and the
  24px fallback (0.6 unchanged in the fallback case — verified by the math).
- **`autoloads/CardRegistry.gd`** `_ensure_loaded()` — illustration assignment tries
  `SpriteRegistry.card_illustration_texture()` first, falls back to
  `TextureGen.card_illustration()`.
- **`test_mount_dismount_visuals.gd`**: confirmed by reading the file that **no
  changes were needed** — its two `mount_horse()` assertions test `TextureGen`
  directly (the fallback function, still intact), and its visibility assertions
  don't touch texture identity at all.
- **`CREDITS.md`** — added a "Per-Slot Index" table mapping every one of the 34
  manifest files to its pack source, so every sprite is traceable without cross-
  referencing `art-sprites.md`.

### Verification

- Headless editor parse/import check: clean.
- Full test runner: 2195 passed / 4 failed / 1 pending — **identical** failure set
  to the TID-446 baseline (7 assertions in `test_auction_transfer`/`test_mailbox`,
  tracked as BID-052, pre-existing and unrelated to this change). No regressions.

## Documentation Updates

- `docs/agent/art-sprites.md` — "Integration Status (TID-447)" section: registry
  additions, ChunkRenderer/Player/CardRegistry wiring, the mount sizing fix, and
  confirmation the mount-visuals test needed no changes. Asset Requirements rows
  updated from "wired by TID-447" (forward-looking) to what actually shipped.
- `docs/agent/visual-polish.md` — prop scatter and Card Illustrations sections
  rewritten to describe the SpriteRegistry-first/TextureGen-fallback flow.
- `docs/agent/rideable-mounts.md` — Mounted Visuals section describes the real
  sprite + the dynamic feet-at-y=0 fix (replacing the stale hardcoded `y=0.6`
  description); Integrations table swaps `TextureGen` row for `SpriteRegistry`;
  Asset Requirements now lists the real PNG instead of "no PNG assets required".
- `docs/agent/inventory-and-deck.md` — checked; existing "Card textures (optional)"
  row was already accurate/generic, no change needed.
