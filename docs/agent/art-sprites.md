# Art Sprite Assets

## Key Features

- Replaces every procedural `TextureGen` placeholder with real, license-clean pixel art:
  - Enemies: `TextureGen.enemy(is_roaming_boss, is_boss)` — `scenes/world/entities/EnemyNPC.gd:15`, `ScoutAmbush.gd:12`
  - NPCs: `npc_townsperson()` (`TownspersonNPC.gd:14`), `npc_merchant(is_traveling)` (`MerchantNPC.gd:12`), `npc_maiteln()` (`MaitelnFollower.gd:65`)
  - Props: `prop(key)` — `scenes/world/ChunkRenderer.gd:343`, keys from `BiomeDef.PROP_SETS`
  - Mount: `mount_horse()` — `Player.gd:122`
  - Card illustrations: `card_illustration(card_id, magic_branch)` — `autoloads/CardRegistry.gd:178`
- Player wizard already has real art (`assets/textures/pixel_art/wizard_walk_{1-4}_pixel.png` via `AvatarSprite.gd`); an optional swap is shortlisted for style coherence.
- CC0-first policy; CC-BY fallback with verbatim attribution; `TextureGen` stays as graceful fallback for missing files (TID-446/447).

## Research Constraints (how this list was built)

Researched 2026-07-16 in a sandboxed session. As with the soundtrack research (see
`docs/agent/audio-soundtrack.md`), **the outbound proxy 403-blocks direct fetches of
asset sites** — licenses were verified via web-search snippets that explicitly state
the license. Every pick below says *license verified* (snippet stated it) or
*unconfirmed* (must check on-page). **The human performing TID-445 must confirm the
license shown on each page at download time.** Sprite-sheet contents (exact frame
names/counts) also could not be inspected remotely — rosters below are from pack
familiarity and search snippets; final slot assignment is confirmed when the sheets
are on disk.

## Style Strategy

Two coherent CC0 families are shortlisted. **Pick ONE as the base for all humanoids**
— do not mix them within a slot group:

- **Family A (primary): 0x72 — 16x16 DungeonTileset II** — https://0x72.itch.io/dungeontileset-ii — **CC0** (license verified). Animated heroes (~16×28: 4 idle + 4 run frames each) and a large monster roster (small/large zombies, skeletons, orcs, shamans, necromancers, imps, demons, goblins, ogre/big_demon boss-scale sprites, animated chest ≈ mimic). Moodier dungeon-crawl look.
- **Family B (backup/alt): Kenney *Tiny Dungeon* + *Tiny Town* + clintbellanger *Tiny Creatures*** — https://kenney.nl/assets/tiny-dungeon , https://kenney.nl/assets/tiny-town , https://opengameart.org/content/tiny-creatures — all **CC0** (license verified). 16×16 thick-outline style, 130+130+180 assets; Tiny Creatures adds 100+ classic monsters and 50+ animals. Friendlier storybook look — arguably closer to the Hobbit/Redwall tone, but sprites are 16×16 (squatter than the current 16×32 wizard).

The existing player wizard frames are 16×32 hand-made and match neither family
exactly. Recommendation: adopt Family A and swap the player to 0x72's `wizzard_m`
hero (idle+run frames drop straight into `AvatarSprite.build()`'s two animations) —
flagged as a **user decision** in TID-445.

## Sprite Manifest (target paths)

| Slot | Path | Size target | Consumed by |
|---|---|---|---|
| Enemy: undead | `assets/textures/characters/enemy_undead.png` | 16×28–32 | EnemyNPC via SpriteRegistry (TID-446) |
| Enemy: undead elite | `assets/textures/characters/enemy_undead_elite.png` | 16×28–32 | undead_elite.tres |
| Enemy: ghoul | `assets/textures/characters/enemy_ghoul.png` | 16×28–32 | ghoul_pack.tres |
| Enemy: raider | `assets/textures/characters/enemy_raider.png` | 16×28–32 | martarquas_raider_1-3.tres, ScoutAmbush |
| Enemy: warleader | `assets/textures/characters/enemy_warleader.png` | 32×32+ | martarquas_warleader.tres (boss-scaled) |
| Enemy: duelist | `assets/textures/characters/enemy_duelist.png` | 16×28–32 | duelist_novice/adept/champion.tres |
| Enemy: rival | `assets/textures/characters/enemy_rival.png` | 16×28–32 | rival_isfig_1-3.tres |
| Enemy: terror | `assets/textures/characters/enemy_terror.png` | 32×32+ | roaming_terror.tres (roaming boss) |
| Enemy: mimic | `assets/textures/characters/enemy_mimic.png` | 16×16 | mimic.tres |
| NPC: townsperson | `assets/textures/characters/npc_townsperson.png` (+`_2`,`_3` variants if available) | 16×28–32 | TownspersonNPC |
| NPC: merchant | `assets/textures/characters/npc_merchant.png` (+`_traveling`) | 16×28–32 | MerchantNPC |
| NPC: Maiteln | `assets/textures/characters/npc_maiteln.png` | 16×28–32 | MaitelnFollower |
| Player (optional swap) | `assets/textures/pixel_art/wizard_walk_{1-4}_pixel.png` (overwrite) | 16×28–32 ×4 frames | AvatarSprite.build() |
| Props ×10 | `assets/textures/props/prop_{rock,flower,mushroom,fern,cactus,thorn,ash,ember,boulder,lichen}.png` | 16×16 | ChunkRenderer._build_props |
| Mount | `assets/textures/characters/mount_horse.png` | ~48×24–32 | Player mount sprite |
| Card art ×4 | `assets/textures/cards/card_{ghost,skeleton,zombie,ghoul}.png` | 32×32 | CardRegistry illustrations |
| Spell runes | `assets/textures/cards/rune_{branch}.png` (one per magic branch) | 32×32 | CardRegistry spell illustrations |

## Shortlist Per Slot Group

### Enemy archetypes + NPCs + optional player swap
- **Primary:** 0x72 — 16x16 DungeonTileset II — **CC0** (license verified) — https://0x72.itch.io/dungeontileset-ii
  - Suggested mapping (confirm frame names in the downloaded sheet; `tiles_list_v1.4` in the pack names every sprite): undead → `skelet`, undead elite → recolor or `masked_orc`-class undead variant, ghoul → `zombie`/`ice_zombie`, raider → `masked_orc`/`orc_warrior`, warleader → `ogre` or `orc_shaman`, duelist → `necromancer`, rival → hero `elf_m` or recolored `wizzard_f`, terror → `big_demon`, mimic → animated `chest` frames; townsperson → hero `knight_f`/`elf_f` recolors, merchant → `doc` or robed variant, Maiteln → `wizzard_m` (if player doesn't take it) or recolor.
  - Attribution: none required (CC0); courtesy credit "0x72 — dungeontileset-ii" in CREDITS.
  - Work needed: crop frames from the single sheet (`0x0072_DungeonTilesetII_v1.4.png`) using the pack's coordinates list; simple palette recolors for variants are license-fine.
- **Backup:** Kenney Tiny Dungeon + clintbellanger Tiny Creatures — **CC0** (license verified) — https://kenney.nl/assets/tiny-dungeon , https://opengameart.org/content/tiny-creatures
  - 16×16 sprites; same mapping approach; Tiny Creatures covers ghost/zombie/skeleton classics directly.

### Props (10 keys)
- **Primary:** Kenney Tiny Town + Tiny Dungeon objects/foliage — **CC0** (license verified) — https://kenney.nl/assets/tiny-town
  - Covers rock/boulder/flower/mushroom/tree-ish foliage; cactus/thorn/ash/ember/fern/lichen may need recolors of nearby pieces (CC0 permits freely). Keep 16×16.
- **Backup:** Danaida — Free Pixel Plants 16x16 (70 tiles) — commercial use allowed per page; **exact license text unconfirmed — check page** — https://danaida.itch.io/free-pixel-plants-16x16
  - Strong plant coverage (fern/flower/mushroom); combine with primary for mineral/ember keys.

### Mount
- **Primary:** clintbellanger — Tiny Creatures (50+ animals) — **CC0** (license verified) — https://opengameart.org/content/tiny-creatures
  - Confirm a horse sprite is present when the sheet is on disk (50+ animals; 16×16 — will render smaller than the current 48×24 silhouette; acceptable, or nearest-upscale ×2).
- **Backup:** search OpenGameArt for "horse sprite CC0" at download time (several exist; none could be license-confirmed via snippets this session). **Avoid LPC horses** (CC-BY-SA 3.0/GPL — share-alike burden, last resort only).

### Card illustrations (ghost, skeleton, zombie, ghoul) + spell runes
- **Primary (creatures):** reuse monster sprites from the chosen humanoid family (0x72 zombie/skeleton; Tiny Creatures ghost), cropped to a single frame and nearest-upscaled to 32×32 — zero additional license burden, guaranteed style match with the world.
- **Primary (spell runes):** game-icons.net rune/spell icons — **CC-BY 3.0** (license verified) — https://game-icons.net
  - Attribution text (site's stated form): `Icons made by {author}. Available on https://game-icons.net` — record each icon's author from its page.
  - Work needed: icons are SVG/monochrome — export at 32×32 PNG, optionally tint per magic branch.
- **Backup:** game-icons.net for the creature slots too (it has ghost/skeleton/zombie icons; same CC-BY 3.0 attribution).

## Acquisition Instructions (for TID-445)

Sandbox sessions cannot download from these sites (proxy 403) — a human must do this
on their own machine.

1. **Decide the style family** (A: 0x72, B: Kenney Tiny) — and whether the player
   wizard swaps to the pack's wizard (recommendation: yes with Family A).
2. Download the chosen packs; confirm the license shown on each page matches this doc.
3. Crop sheets into per-slot PNGs at the manifest paths above. 0x72 ships a sprite
   coordinates list in the zip; ImageMagick example:
   `magick sheet.png -crop 16x28+368+16 +repage enemy_undead.png`
4. Keep transparent backgrounds; never resample/smooth-scale (nearest-integer upscale
   only, e.g. `magick in.png -filter point -resize 200% out.png`).
5. For CC-BY items (game-icons.net) copy the icon author names and the exact
   attribution wording from the page — TID-446/447 need them verbatim for CREDITS.
6. If a pack includes walk/idle animation frames for enemies/NPCs, ALSO save them as
   `<slot>_walk_{1-N}.png` alongside the static frame — TID-446 treats animation as
   optional bonus scope.
7. Commit the PNGs. `.import` sidecars are generated by editor/headless import;
   PNGs need no `.uid` sidecars.

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Character/NPC/enemy sprites | `assets/textures/characters/*.png` | Wired by TID-446 (SpriteRegistry + fallback to TextureGen) |
| Prop sprites ×10 | `assets/textures/props/prop_<key>.png` | Wired by TID-447 into ChunkRenderer instancing |
| Mount sprite | `assets/textures/characters/mount_horse.png` | Wired by TID-447; `test_mount_dismount_visuals.gd` must be updated |
| Card art + runes | `assets/textures/cards/*.png` | Wired by TID-447 via CardRegistry |
| CREDITS entries | repo CREDITS file (location established by GID-116/TID-437) | Author, license, URL per sprite; verbatim CC-BY text for game-icons.net |

Integration notes for TID-446/447:
- Literal `const` preloads only (Android rule) — one per PNG; dictionaries with literal
  string keys and preloaded values are fine.
- Keep `TEXTURE_FILTER_NEAREST`, billboard, alpha-cut settings; feet-at-y=0 formula
  reads texture height — do not hard-code 32.
- Run headless parse/import check after every `.gd` edit; full test runner at the end.
