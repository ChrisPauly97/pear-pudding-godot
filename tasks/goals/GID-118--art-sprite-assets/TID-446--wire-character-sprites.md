# TID-446: Wire Character/Enemy/NPC Sprites Into Entity Builders + Attribution

**Goal:** GID-118
**Type:** agent
**Status:** done
**Depends On:** TID-445

## Lock

- Session: none
- Acquired: —
- Expires: —

## Context

With real PNGs in the repo (TID-445), replace the procedural humanoid silhouettes with per-type sprites at every character call site, keeping `TextureGen` as a graceful fallback so the game still runs if a file is missing (same philosophy as `AudioManager`'s `ResourceLoader.exists()` no-op).

## Research Notes

### Call sites to convert

| File | Line (approx) | Today | Target |
|---|---|---|---|
| `scenes/world/entities/EnemyNPC.gd` | 15 | `TextureGen.enemy(_is_roaming_boss, _is_boss)` | per-archetype sprite mapped from enemy type; bosses keep existing scale treatment, optionally tint |
| `scenes/world/entities/ScoutAmbush.gd` | 12 | `TextureGen.enemy()` | raider/scout archetype sprite |
| `scenes/world/entities/TownspersonNPC.gd` | 14 | `TextureGen.npc_townsperson()` | townsperson sprite (variants if available) |
| `scenes/world/entities/MerchantNPC.gd` | 12 | `TextureGen.npc_merchant(_is_traveling)` | merchant sprite (traveling variant if available) |
| `scenes/world/entities/MaitelnFollower.gd` | 65 | `TextureGen.npc_maiteln()` | Maiteln (old wizard) sprite |

### Design: a SpriteRegistry helper

Create a small preload-registry (e.g. `game_logic/SpriteRegistry.gd`, `RefCounted` with statics, preloaded by callers per the CLAUDE.md class_name rule):

- One `const _X := preload("res://assets/textures/characters/....png")` per manifest file — **Android requires literal preloads**, never dynamic `load("dir" + name)` (CLAUDE.md Android rule).
- `static func enemy_texture(etype: String, is_roaming_boss: bool, is_boss: bool) -> Texture2D` — maps `EnemyRegistry` enemy type ids to archetype textures (mapping table from `docs/agent/art-sprites.md`); returns `null` → caller falls back to `TextureGen.enemy(...)`.
- Equivalent accessors for NPC slots.
- Archetype → enemy-type mapping must cover every `.tres` in `data/enemies/` (undead basic/elite, ghoul_pack, martarquas_raider_1-3, martarquas_warleader, duelist_novice/adept/champion, rival_isfig_1-3, mimic, roaming_terror) plus infinite-world spawns — check how `EnemyNPC.configure()` receives its type (`data.get(...)`, `EnemyRegistry.get_is_boss(etype)` at line ~40).

### Constraints & gotchas

- Sprite sizing: keep the feet-at-y=0 formula — `sprite.position.y = tex.get_height() * pixel_size * 0.5 (+ margin)` (CLAUDE.md Sprite3D depth-clipping rule). Don't assume 16×32; read the texture height.
- Keep `TEXTURE_FILTER_NEAREST`, billboard, alpha-cut settings identical to current builders.
- If the pack includes walk frames for NPCs/enemies, wiring animation is OPTIONAL scope — only do it if trivial via the `AvatarSprite.build()` pattern; otherwise log a backlog item.
- If TID-444/445 delivered a player-wizard replacement (optional slot), update `AvatarSprite.gd`'s four preloads; RemotePlayer inherits automatically.
- Run the headless parse/import check after every `.gd` edit (CLAUDE.md). Run `godot --headless --path . -s tests/runner.gd` — `test_mount_dismount_visuals.gd` touches `TextureGen.mount_horse()` (TID-447's slot) and must stay green regardless.

### Attribution

Create or extend the repo CREDITS file (GID-116/TID-437 establishes it at `assets/audio/music/CREDITS.md` or repo root — reuse whatever location it chose; if TID-437 hasn't run yet, create `CREDITS.md` at repo root and note it for TID-437 to merge into). Every sprite: author, license, source URL, verbatim CC-BY attribution where required (captured by the human in TID-445).

### Docs to update

- `docs/agent/enemies-and-npcs.md` — enemy/NPC visuals section.
- `docs/agent/art-sprites.md` — flip shortlist entries to "integrated", document the SpriteRegistry pattern and fallback behavior.
- `docs/agent/visual-polish.md` — references to TextureGen character silhouettes.

## Plan

1. **Gap fix**: add `assets/textures/characters/enemy_spectre.png` (Kenney Tiny Dungeon
   `tile_0121` white ghost, CC0) — night hunts spawn `spectre_wisp/haunt/dread` enemy
   types that TID-444's manifest missed; WorldScene applies a spectral node modulate,
   so one white-ghost base sprite covers all three tiers.
2. **`game_logic/SpriteRegistry.gd`** (RefCounted, statics, literal preloads only):
   - `CHAR_PIXEL_SIZE := 0.05` (0x72 sprites are 16–36 px vs the old fixed 32 px
     silhouettes; 0.05 keeps mid-size humanoids ≈ the old world height and preserves
     the pack's intentional size hierarchy).
   - `enemy_texture(etype, is_roaming_boss, is_boss) -> Texture2D` — maps every
     `EnemyRegistry` id (incl. `undead_horde`, spectres); returns `null` for
     unknown/empty type → caller falls back to `TextureGen`.
   - `townsperson_texture(seed)` (3 stable variants), `merchant_texture(is_traveling)`,
     `maiteln_texture()`, `raider_texture()` (ScoutAmbush).
   - `setup_sprite(sprite, tex, pixel_size)` — sets texture/pixel_size and the
     feet-at-y=0 position from `tex.get_height()` (CLAUDE.md Sprite3D rule).
3. Convert the 5 call sites (EnemyNPC, ScoutAmbush, TownspersonNPC, MerchantNPC,
   MaitelnFollower); each keeps its billboard/alpha-cut/nearest settings and falls
   back to the existing `TextureGen` call when the registry returns `null`.
4. Player-wizard swap: skipped (deferred at TID-445; user decision).
5. Walk-frame animation for enemies/NPCs: NOT wired (would need AnimatedSprite3D +
   movement-state plumbing per entity) — log backlog item.
6. Create root `CREDITS.md` from TID-445's captured attributions (note for TID-437
   to merge audio credits in).
7. Update docs: enemies-and-npcs.md, art-sprites.md, visual-polish.md.
8. Headless parse/import check + full test runner.

## Changes Made

- **`game_logic/SpriteRegistry.gd` (new)** — static preload registry: 16 character
  textures; `enemy_texture()` covering all 19 `EnemyRegistry` ids (incl.
  `undead_horde` and the 3 spectre tiers); `townsperson_texture(seed)` /
  `merchant_texture(is_traveling)` / `maiteln_texture()` / `raider_texture()`;
  `setup_sprite()` helper (texture + `CHAR_PIXEL_SIZE` 0.05 + feet-at-y=0 from real
  texture height). Returns `null` for unknown enemy types → callers fall back to
  `TextureGen`.
- **`assets/textures/characters/enemy_spectre.png` (new)** — Kenney Tiny Dungeon
  `tile_0121` white ghost (CC0). Gap fix: night hunts spawn `spectre_wisp/haunt/dread`
  types the TID-444 manifest missed; WorldScene's spectral modulate differentiates tiers.
- **Call sites converted** (each keeps billboard/alpha-cut/nearest and falls back to
  its original `TextureGen` call + old fixed sizing when the registry returns null):
  - `scenes/world/entities/EnemyNPC.gd` — per-type sprite from `enemy_data["enemy_type"]`;
    boss node-scale treatment unchanged.
  - `scenes/world/entities/ScoutAmbush.gd` — raider texture at 0.04 px size (keeps the
    old smaller-than-enemy ratio) + green lurk tint.
  - `scenes/world/entities/TownspersonNPC.gd` — stable variant via `hash(id + name)`.
  - `scenes/world/entities/MerchantNPC.gd` — merchant / traveling variant.
  - `scenes/world/entities/MaitelnFollower.gd` — wizard sprite.
- **`CREDITS.md` (new, repo root)** — full art attribution from TID-445's capture
  (0x72, Kenney ×2, Clint Bellanger, Danaida CC0; game-icons.net CC-BY 3.0 with the
  required verbatim line). Notes that TID-437 should merge music credits here.
- **`.import` sidecars committed** for all TID-445/446 PNGs (generated by headless
  editor import; matches repo convention), plus editor-generated `.gd.uid` files.
- Player-wizard swap NOT done (deferred at TID-445 as a user decision).
- Walk frames NOT wired (static Sprite3D call sites) — logged **BID-051**.

### Verification

- Headless editor parse/import check: clean (no Parse/Compile errors).
- Full test runner: 2195 passed / 4 tests failed / 1 pending — the 7 failing
  assertions (auction/mailbox) fail identically on a clean stash of HEAD, so they
  are pre-existing, not from this change. Caveat: sandbox ran **Godot 4.7.1**
  (4.6 binaries proxy-blocked from GitHub releases; 4.7.1 from the official
  itch.io mirror) — logged **BID-052** to re-check under pinned 4.6.

## Documentation Updates

- `docs/agent/art-sprites.md` — "Integration Status (TID-446)" section: registry
  API, spectre gap fix, fallback semantics, what TID-447 still owns.
- `docs/agent/enemies-and-npcs.md` — new "Sprite Selection (GID-118)" section;
  Asset Requirements rows updated to the real texture paths.
- `docs/agent/visual-polish.md` — Asset Requirements rewritten (no longer
  all-procedural; TextureGen now fallback + props/mount/cards until TID-447).
- Backlog: BID-051 (walk frames), BID-052 (pre-existing test failures) + index rows.
