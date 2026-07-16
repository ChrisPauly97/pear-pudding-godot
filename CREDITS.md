# Credits & Attribution

Third-party assets used by Pear Pudding TCG, with author, license, and source.
(Music credits will be added by the soundtrack integration task — GID-116/TID-437.)

## Art / Sprites

### 0x72 — 16x16 DungeonTileset II (v1.7)

- **Source:** https://0x72.itch.io/dungeontileset-ii
- **License:** CC0-1.0 (Creative Commons Zero v1.0 Universal) — no attribution required; credited with thanks.
- **Used for:** enemy sprites (skeleton/undead, undead elite recolor, swampy ghoul, masked-orc raider, ogre warleader, necromancer duelist, elf rival, big-demon roaming terror, mimic chest), NPC sprites (townsperson variants, merchant, Maiteln), card illustrations (skeleton, zombie, ghoul), plus their walk frames under `assets/textures/characters/` and `assets/textures/cards/`.

### Kenney — Tiny Town (1.1) & Tiny Dungeon (1.0)

- **Source:** https://kenney.nl/assets/tiny-town , https://kenney.nl/assets/tiny-dungeon
- **License:** CC0 (Creative Commons Zero) — no attribution required; credited with thanks.
- **Used for:** mushroom prop (Tiny Town), ghost card illustration and spectre enemy sprite (Tiny Dungeon).

### Clint Bellanger — Tiny Creatures (1.0)

- **Source:** https://opengameart.org/content/tiny-creatures
- **License:** CC0 (Creative Commons Zero). Attribution not mandatory; the author asks for a credit — thank you, **Clint Bellanger** (clintbellanger.net).
- **Used for:** mount horse sprite; rock, boulder (recolor), ash pile, and ember props.

### Danaida — Free Pixel Plants 16x16

- **Source:** https://danaida.itch.io/free-pixel-plants-16x16
- **License:** CC0, per the author's statement on the asset page.
- **Used for:** flower, fern, cactus, thorn, and lichen props.

### game-icons.net (spell rune icons)

- **Source:** https://game-icons.net
- **License:** **CC BY 3.0** — https://creativecommons.org/licenses/by/3.0/
- **Required attribution:** Icons made by **Delapouite** and **Lorc**. Available on https://game-icons.net
- **Used for:** spell rune card illustrations (`rune_dawn` "Sunrise" and `rune_dusk` "Sunset" by Delapouite; `rune_ember` "Burning embers" and `rune_ash` "Dust cloud" by Lorc), rendered at 32×32 and tinted per magic branch.

## Per-Slot Index

All sprites listed above are integrated in-engine as of GID-118 (TID-446 wired
characters/enemies/NPCs; TID-447 wired props/mount/card art). `TextureGen`
remains as a runtime fallback wherever a slot's texture is missing.

| Slot | File | Source |
|---|---|---|
| Enemy: undead / undead (horde) | `characters/enemy_undead.png` | 0x72 |
| Enemy: undead elite | `characters/enemy_undead_elite.png` | 0x72 (recolor) |
| Enemy: ghoul | `characters/enemy_ghoul.png` | 0x72 |
| Enemy: raider (+ScoutAmbush) | `characters/enemy_raider.png` | 0x72 |
| Enemy: warleader | `characters/enemy_warleader.png` | 0x72 |
| Enemy: duelist | `characters/enemy_duelist.png` | 0x72 |
| Enemy: rival | `characters/enemy_rival.png` | 0x72 |
| Enemy: terror (+roaming boss) | `characters/enemy_terror.png` | 0x72 |
| Enemy: mimic | `characters/enemy_mimic.png` | 0x72 |
| Enemy: spectre (wisp/haunt/dread) | `characters/enemy_spectre.png` | Kenney Tiny Dungeon |
| NPC: townsperson ×3 | `characters/npc_townsperson{,_2,_3}.png` | 0x72 |
| NPC: merchant (+traveling) | `characters/npc_merchant{,_traveling}.png` | 0x72 |
| NPC: Maiteln | `characters/npc_maiteln.png` | 0x72 |
| Mount | `characters/mount_horse.png` | Clint Bellanger — Tiny Creatures |
| Prop: rock | `props/prop_rock.png` | Clint Bellanger — Tiny Creatures |
| Prop: boulder | `props/prop_boulder.png` | Clint Bellanger — Tiny Creatures (recolor) |
| Prop: ash_pile | `props/prop_ash_pile.png` | Clint Bellanger — Tiny Creatures |
| Prop: ember | `props/prop_ember.png` | Clint Bellanger — Tiny Creatures |
| Prop: mushroom | `props/prop_mushroom.png` | Kenney Tiny Town |
| Prop: flower / fern / cactus / thorn / lichen | `props/prop_{flower,fern,cactus,thorn,lichen}.png` | Danaida |
| Card: ghost | `cards/card_ghost.png` | Kenney Tiny Dungeon |
| Card: skeleton / zombie / ghoul | `cards/card_{skeleton,zombie,ghoul}.png` | 0x72 |
| Rune: dawn / dusk / ember / ash | `cards/rune_{dawn,dusk,ember,ash}.png` | game-icons.net (CC BY 3.0) |
