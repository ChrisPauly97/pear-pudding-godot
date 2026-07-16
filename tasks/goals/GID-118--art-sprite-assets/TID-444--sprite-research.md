# TID-444: Research & Curate CC0/CC-BY Sprite Shortlist Per Art Slot

**Goal:** GID-118
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

Every non-player character/world sprite is a procedural `TextureGen` silhouette. This task is pure research: define the sprite manifest (which files the game needs, at which paths, at which sizes) and produce a curated, license-verified shortlist a human can act on in TID-445 without re-searching. No code or asset files are touched — output is a single new doc plus a CLAUDE.md index row.

## Research Notes

### Slots to fill (pipeline → size → style constraints)

| Slot group | Current source | Size | Notes |
|---|---|---|---|
| Enemy archetypes | `TextureGen.enemy()` | 16×32 | Define ~5–7 visual archetypes covering all `data/enemies/*.tres`: e.g. undead/skeleton (undead_basic/elite), ghoul (ghoul_pack), tribal raider (martarquas_raider_1-3, warleader), duelist/mage (duelist_novice/adept/champion, rival_isfig_1-3), horror/boss (roaming_terror, mimic ambush form). Boss/roaming-boss variants may reuse an archetype with scale/tint (EnemyNPC already scales bosses). |
| NPCs | `npc_townsperson()`, `npc_merchant(is_traveling)`, `npc_maiteln()` | 16×32 | Maiteln = old wizard, pale head, indigo robe (see `_gen_humanoid` comment in TextureGen.gd:427). Townsperson ideally 2–3 palette variants. |
| Player (conditional) | Real art: `wizard_walk_{1-4}_pixel.png` | 16×32, 4 frames | Keep unless the curated set clashes stylistically — if the shortlist's pack includes a better-matching robed/wizard character with walk frames, propose it as an optional swap and flag for user decision. |
| Props | `TextureGen.prop(key)` | 16×16 | 10 keys (see `_gen_prop_*` in TextureGen.gd): rock, flower, mushroom, fern, cactus, thorn, ash, ember, boulder, lichen. Keys come from `BiomeDef.PROP_SETS` per biome. |
| Mount | `TextureGen.mount_horse()` | 48×24 | Side-view horse silhouette today; a standard pixel horse sprite works. |
| Card illustrations | `TextureGen.card_illustration(card_id, magic_branch)` | 32×32 | Archetypes: ghost, skeleton, zombie, ghoul + spell rune per magic branch (see `_gen_card_*`). Icon-style art acceptable (rendered inside card UI frames). |

Exact sizes are *targets*, not hard limits — `Sprite3D.pixel_size` (0.05) and the feet-at-y=0 formula (`sprite.position.y = tex_height * pixel_size * 0.5`) adapt to any height, and CLAUDE.md's Sprite3D depth-clipping rule must hold. But wildly different proportions across slots will look incoherent; prefer one pack family.

### Rendering constraints (from AvatarSprite.gd / entity builders)

- Billboard sprites, `TEXTURE_FILTER_NEAREST`, alpha-cut opaque prepass — sprites need clean transparent backgrounds (PNG with alpha), no anti-aliased halos.
- Single static frame is the minimum (that's all `EnemyNPC` renders today); walk-cycle frames are a bonus — if a pack provides them, note it, since `AvatarSprite.build()` shows the AnimatedSprite3D pattern to extend.
- One coherent style/palette across ALL picks — strongly prefer sourcing most slots from one artist/pack family rather than mixing ten styles.

### License constraints (same policy as GID-116 / docs/agent/audio-soundtrack.md)

- CC0 / public domain preferred; CC-BY acceptable with verbatim attribution captured for the CREDITS file.
- **LPC (Liberated Pixel Cup) assets are typically dual CC-BY-SA 3.0 / GPL 3.0** — share-alike for embedded art is workable but adds obligations; treat as last resort and flag for user decision if picked.
- No CC-BY-NC, no paid packs, no "royalty-free but not redistributable" stock art.

### Good source starting points (verify current licensing per pack at download time)

- **Kenney.nl** — everything CC0; has pixel RPG character/roguelike packs (e.g. "Tiny Dungeon", "Roguelike Characters") with consistent style across characters, props, items.
- **itch.io** — CC0 pixel asset packs (search "CC0 16x32 character sprites", "CC0 fantasy rpg pack"); 0x72's dungeon tileset packs are CC0 and include 16×32-ish characters/monsters.
- **OpenGameArt.org** — DawnLike (16×16, CC-BY 4.0), various CC0 monster/NPC packs; filter per-asset license carefully (CC-BY-SA/GPL content is mixed in).
- **game-icons.net** — CC-BY 3.0 icon art, a fit for the card-illustration slot specifically.

### Sandbox constraint (confirmed twice: GID-116 goal research and TID-435 execution)

The outbound proxy 403-blocks every asset site tried (opengameart.org, itch.io, incompetech.com, freemusicarchive.org, commons.wikimedia.org) for BOTH raw curl and WebFetch. Research must go through WebSearch snippets; licenses get flagged "verified via snippet" vs "unconfirmed — check page", and TID-445 instructs the human to confirm the license tag on each page at download time. Follow the exact documentation pattern in `docs/agent/audio-soundtrack.md`.

### Output format

Create `docs/agent/art-sprites.md` mirroring `docs/agent/audio-soundtrack.md`:

1. **Key Features** — the slot groups and the code that consumes them (call sites above).
2. **Sprite Manifest** — table: slot → target repo path (propose `assets/textures/characters/`, `assets/textures/props/`, `assets/textures/cards/`) → size → consuming code.
3. **Shortlist Per Slot Group** — primary + backup pack/track per group, each with source URL, license (verified/unconfirmed), attribution text verbatim, and any crop/rename work needed.
4. **Acquisition Instructions (for TID-445)** — download, crop/split sheets if needed (note tooling, e.g. ImageMagick `convert -crop`), save-as paths, license-text capture.
5. **Asset Requirements** — integration notes for TID-446/447 (fallback pattern, .import sidecars are editor-generated, PNGs need no .uid sidecars).

Add a `docs/agent/art-sprites.md` row to the docs index table in `CLAUDE.md`.

## Plan

1. WebSearch research per slot group, prioritising single-artist/pack families for style
   coherence: Kenney (CC0) for a baseline, itch.io CC0 packs (0x72 etc.), OpenGameArt
   per-asset checks, game-icons.net for card art. Direct page fetches are proxy-blocked,
   so licenses are verified via search snippets and flagged verified/unconfirmed.
2. Fix the sprite manifest: enemy archetype set covering all data/enemies/*.tres +
   infinite-world spawns, NPC slots, optional player swap, 10 prop keys, mount,
   4 card archetypes + spell runes; assign target repo paths.
3. Write `docs/agent/art-sprites.md` (Key Features, Sprite Manifest, Shortlist Per Slot
   Group with primary+backup, Acquisition Instructions for TID-445, Asset Requirements
   with TID-446/447 integration notes) mirroring audio-soundtrack.md.
4. Add the docs-index row to `CLAUDE.md`.
5. Update statuses (task file, goal.md, tasks/index.md), release lock, commit
   `TID-444: ...` on the working branch.

Research-only: no code or binary assets touched.

## Changes Made

- Created `docs/agent/art-sprites.md`: sprite manifest (17 slot groups → target repo
  paths), two coherent CC0 style families with a recommendation (Family A: 0x72
  DungeonTileset II for humanoids; Kenney Tiny Town/Dungeon for props; clintbellanger
  Tiny Creatures for the mount; game-icons.net CC-BY 3.0 for spell runes), primary +
  backup per slot group, acquisition/cropping instructions for TID-445, and
  integration notes for TID-446/447.
- Added the new doc's row to the docs index table in `CLAUDE.md`.
- No code or binary assets touched (research-only task, as scoped).

Key research findings:
- Same sandbox constraint as TID-435: all asset sites 403 through the proxy; licenses
  verified via search snippets and flagged verified vs unconfirmed in the doc.
- License-verified CC0: 0x72 DungeonTileset II, Kenney Tiny Dungeon/Tiny Town,
  clintbellanger Tiny Creatures. License-verified CC-BY 3.0: game-icons.net (with the
  site's stated attribution form). Danaida Free Pixel Plants is commercial-use-OK per
  page but exact license text unconfirmed — backup only.
- Card creature art needs no third-party source: cropping/nearest-upscaling monster
  sprites from the chosen humanoid family keeps style coherent at zero license cost.
- Two decisions deferred to the human at TID-445: which style family (A recommended),
  and whether the player wizard swaps to the pack's wizard frames.

## Documentation Updates

- New: `docs/agent/art-sprites.md` (manifest, shortlist, acquisition, attribution).
- `CLAUDE.md`: added docs-index row for the new file.
- `docs/agent/enemies-and-npcs.md` / `visual-polish.md` deliberately untouched —
  updating them is TID-446/447 scope, after sprites actually land.
