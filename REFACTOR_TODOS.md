# Refactor Backlog

Items are roughly ordered by priority — foundational / bug-preventing work first.

---

- [ ] **Typed arrays everywhere** — replace all untyped `Array` literals and variables with `Array[T]`; eliminates Variant inference compile errors and the need for `assign()` workarounds documented in CLAUDE.md
- [ ] **`preload` all cross-file dependencies** — audit every file for bare `class_name` references and replace with explicit `preload()` at the top of the file; prevents parse errors on cold project opens
- [x] **Versioned save schema** — add `"save_version": 1` to SaveManager JSON output and write a migration table; prevents silent save corruption when the schema changes
- [x] **Data-driven cards and enemies** — replace `CardRegistry` and `EnemyRegistry` GDScript dictionaries with `CardData.tres` / `EnemyData.tres` Resource subclasses; content additions require no GDScript changes
- [ ] **Unified chunk render path** — collapse named-map (`WorldScene`) and infinite-chunk (`ChunkRenderer`) into one pipeline where named maps are statically-defined chunk sets; removes the dual-path complexity that required TerrainMath as a patch
- [x] **Reduce autoloads** — remove `CardRegistry`, `EnemyRegistry`, `SaveManager` from global autoloads and inject them explicitly into scenes that need them; only `GameBus` and `IsoConst` justify global scope
- [ ] **SceneManager as formal state machine** — replace the map-stack + overlay approach with defined states (`WorldState`, `BattleState`, `MenuState`) and explicit enter/exit transitions
- [ ] **Test world generation** — make `InfiniteWorldGen`, `TerrainMath`, and `ChunkData` have zero `Node` dependencies and add unit test coverage on par with the battle system
- [x] **Single grass shader uniform source** — replace per-instance `set_shader_parameter` calls in `GrassBlades.gd` with Godot global shader parameters so all chunks react to world state without per-chunk updates
