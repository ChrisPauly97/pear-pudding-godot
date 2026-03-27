# Pear Pudding TCG — Documentation Plan

This directory contains one Markdown file per major game feature. Each file follows the same four-section structure:

1. **Key Features** — what the system does, from a player/developer perspective
2. **How It Works** — implementation detail: data flow, algorithms, scene hierarchy, GDScript patterns
3. **Integrations with Other Features** — dependencies and signals to/from other systems
4. **Asset Requirements** — textures, shaders, `.tres` data files, `.tscn` scenes, map files

---

## Document Index

| File | Feature |
|---|---|
| [battle-system.md](battle-system.md) | Turn-based TCG card battle: game state, mana, boards, AI |
| [world-generation.md](world-generation.md) | Infinite procedural world: chunks, biomes, ruins, entity spawning |
| [named-maps-and-dungeons.md](named-maps-and-dungeons.md) | Hand-crafted / procedural named maps, dungeon generation, map stack navigation |
| [terrain-rendering.md](terrain-rendering.md) | TerrainMath mesh building, height fields, shaders, biome tints, grass |
| [camera-and-player.md](camera-and-player.md) | Isometric camera, player movement, chunk streaming, mobile controls |
| [inventory-and-deck.md](inventory-and-deck.md) | Card collection, deck builder UI, starter deck, chest drops |
| [save-system.md](save-system.md) | JSON persistence, saved state fields, dirty flagging, migration |
| [enemies-and-npcs.md](enemies-and-npcs.md) | Enemy types, wander/track AI, engagement trigger, NPC dialogue |
| [ui-and-scene-management.md](ui-and-scene-management.md) | Scene stack, battle overlay, menus, HUD, day/night, map editor |
| [signals-and-constants.md](signals-and-constants.md) | GameBus signal hub, IsoConst values, decoupling architecture |

---

## Architecture at a Glance

```
Autoloads (singletons)
  IsoConst   — tile sizes, camera angles, gameplay ranges
  GameBus    — signal hub decoupling all systems
  SceneManager — scene routing and map stack
  SaveManager  — JSON persistence
  CardRegistry — card template database
  EnemyRegistry — enemy deck database

Game Logic (pure GDScript, no rendering)
  battle/     — GameState, PlayerState, CardInstance, HeroState, ZoneState
  world/      — InfiniteWorldGen, BiomeDef, ChunkData, WorldMap, DungeonGen
  TerrainMath — shared height + mesh building

Scenes (rendering + interaction)
  world/      — WorldScene, ChunkRenderer, Player, EnemyNPC, TownspersonNPC, Chest, Door
  battle/     — BattleScene
  ui/         — MenuScene, InventoryScene, BiomeSelectionScene, GameOverScene, MapEditorScene

Assets
  assets/shaders/     — terrain.gdshader, grass.gdshader, grass_blade.gdshader
  assets/textures/    — pixel art sprites (player, terrain tiles)
  assets/maps/        — bundled named map text files
  data/cards/         — CardData .tres resources
  data/enemies/       — EnemyData .tres resources
```
