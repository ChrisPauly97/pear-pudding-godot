# Refactor Backlog

Items are roughly ordered by priority — foundational / bug-preventing work first.

---

- [x] **Typed arrays everywhere** — replace all untyped `Array` literals and variables with `Array[T]`; eliminates Variant inference compile errors and the need for `assign()` workarounds documented in CLAUDE.md
- [x] **`preload` all cross-file dependencies** — audit every file for bare `class_name` references and replace with explicit `preload()` at the top of the file; prevents parse errors on cold project opens
- [x] **Versioned save schema** — add `"save_version": 1` to SaveManager JSON output and write a migration table; prevents silent save corruption when the schema changes
- [x] **Data-driven cards and enemies** — replace `CardRegistry` and `EnemyRegistry` GDScript dictionaries with `CardData.tres` / `EnemyData.tres` Resource subclasses; content additions require no GDScript changes
- [x] **Unified chunk render path** — collapse named-map (`WorldScene`) and infinite-chunk (`ChunkRenderer`) into one pipeline where named maps are statically-defined chunk sets; removes the dual-path complexity that required TerrainMath as a patch
- [x] **Reduce autoloads** — remove `CardRegistry`, `EnemyRegistry`, `SaveManager` from global autoloads and inject them explicitly into scenes that need them; only `GameBus` and `IsoConst` justify global scope
- [ ] **SceneManager as formal state machine** — replace the map-stack + overlay approach with defined states (`WorldState`, `BattleState`, `MenuState`) and explicit enter/exit transitions
- [x] **Test world generation** — make `InfiniteWorldGen`, `TerrainMath`, and `ChunkData` have zero `Node` dependencies and add unit test coverage on par with the battle system
- [x] **Single grass shader uniform source** — replace per-instance `set_shader_parameter` calls in `GrassBlades.gd` with Godot global shader parameters so all chunks react to world state without per-chunk updates

---

## Deduplication pass (claude/simplify-deduplicate-code-70c8k5)

Done:
- [x] **UI widget factories** — `UiUtil.make_button/make_label/make_hbox/make_vbox/make_margin/make_centered_panel/make_style` replace ~600 hand-written construction blocks
- [x] **Modal scaffolds** — `WorldScene._build_modal` / `_build_prompt`, `BattleResultUI._build_result_overlay`, `BaseOverlay._build_scroll` / `_rebuild_ui`
- [x] **Save/load symmetry** — `SaveManager.PERSISTED_FIELDS` drives both directions; covered by round-trip tests
- [x] **Net smoke-test harness** — `tests/net_harness.gd` holds the shared ENet loopback bootstrap
- [x] **Proximity scans** — `WorldScene._node_in_range` / `_first_node_in_range` / `_first_data_in_range`; `_check_interactions` short-circuits instead of running all 17 probes
- [x] **Battle teardown / launch** — `SceneManager._finish_battle`, `_dismiss_battle_overlay`, `_swap_world_for_pvp_battle`
- [x] **Dead data** — removed `data/enemies/*.tres` + `data/EnemyData.gd` (never read; had drifted from `EnemyRegistry`)

Still open:
- [ ] **SceneManager as formal state machine** — see the item above
- [x] **Oversized functions** — `_on_battle_won` 225→143, `WorldScene._ready` 290→152, `_handle_interact` 250→113, `_process` 118→94, `BattleScene._ready` 222→125, `_check_game_over` 123→50
- [ ] **`WorldScene.gd` is still ~3.8k lines** — the remaining bulk is nocturnal spawns, cantrips, dialogue, home/garden and tap-to-move; each is a candidate for the same module treatment
- [ ] **`_interact_prompt_label` and `_handle_interact` probe in different orders** — with an enemy and a door both in range the HUD reads "ATTACK" but the button enters the door. Both orders are pinned by `test_interact_priority`; picking which wins is a gameplay call
- [ ] **Cross-module reaches** — a handful of `_world.coop_pvp.X` references remain (spectate button, leaderboard overlay). Where two modules genuinely share state it belongs on WorldScene or in a small shared object
- [ ] **`EnemyRegistry` is still a GDScript literal** — `CardRegistry` is `.tres`-driven and `EnemyRegistry` is not. Migrating means moving the current dictionary's values (drop pools, capture/signature data) into resources; the old `.tres` files were stale, so they were deleted rather than adopted silently
- [x] **`BattleScene.gd` god object** — split to 2.4k lines; the PvP/co-op/spectating/wager surface moved to `scenes/battle/net/BattleNet.gd`, with `BattleNetSync` gaining the same `register_handler`/`_route` dispatch
- [x] **`WorldScene.gd` god object** — split to 3.8k lines; the co-op surface moved to four `scenes/world/coop/*.gd` sibling modules (Session / Activities / PvP / Social). NetSync gained `register_handler`/`_route` so RPC dispatch is module-agnostic
