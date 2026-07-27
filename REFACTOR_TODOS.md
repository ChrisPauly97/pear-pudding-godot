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
- [x] **Interaction priority** — both chains now follow one `WorldScene.INTERACT_PRIORITY` constant, with hostile entities (`enemy`, `scout_ambush`, `blight_heart`) probed last so anything peaceful in reach wins
- [ ] **Cross-module reaches** — a handful of `_world.coop_pvp.X` references remain (spectate button, leaderboard overlay). Where two modules genuinely share state it belongs on WorldScene or in a small shared object
- [ ] **`EnemyRegistry` is still a GDScript literal** — `CardRegistry` is `.tres`-driven and `EnemyRegistry` is not. Migrating means moving the current dictionary's values (drop pools, capture/signature data) into resources; the old `.tres` files were stale, so they were deleted rather than adopted silently
- [x] **`BattleScene.gd` god object** — split to 2.4k lines; the PvP/co-op/spectating/wager surface moved to `scenes/battle/net/BattleNet.gd`, with `BattleNetSync` gaining the same `register_handler`/`_route` dispatch
- [x] **`WorldScene.gd` god object** — split to 3.8k lines; the co-op surface moved to four `scenes/world/coop/*.gd` sibling modules (Session / Activities / PvP / Social). NetSync gained `register_handler`/`_route` so RPC dispatch is module-agnostic

### Second deduplication pass

Done:
- [x] **Draft-pick overlays** — `SpireDraftScene` and `DraftDuelPickScene` were ~85% identical; the panel, card tiles and tier badges moved to `scenes/ui/DraftPickBase.gd`, leaving `_tier_for` / `_pick_disabled` as the only differences
- [x] **Overlay tab strips** — `UiUtil.make_tab_row` owns the buttons, the active-tab tracking and the re-click guard; `LeaderboardOverlay` / `AuctionHouseOverlay` keep only their re-render
- [x] **Networked battle setup** — `BattleNet._build_net_state` replaces the same nine lines in the PvP, co-op-PvE and team-duel entry points
- [x] **Participant intent handling** — `BattleNet._handle_participant_intent` replaces the twin 26-line `_on_coop_intent` / `_on_team_intent` authority routines
- [x] **TerrainMath height** — the two height-field builders now sample the matching point query, so the scan and smoothstep exist once per lookup style instead of four times (measured: no regression on chunk prep)
- [x] **Spell wording** — `game_logic/battle/SpellEffectLabels.gd` replaces the twin tables in `CardViewBuilder` / `CardInspectOverlay`, which had already drifted; writing the guard surfaced seven effects real cards use that had no label at all
- [x] **Card inspect** — `CardInspectOverlay.present()` plus `scenes/ui/CardBrowserOverlay.gd` replace three copies of the open sequence
- [x] **Grass buffers** — deleted `GrassBlades.build_chunk` / `_build_chunk_mmi` / `_build_chunk_clusters`, an uncalled second copy of the blade placement math
- [x] **Entity materials** — `WorldEntityBase.unshaded_material()` replaces the 3-line idiom at 23 sites across 11 world entities
- [x] **Tap markers** — one `WorldScene._make_tap_marker(name, tint)` for the destination ring and the rejected-tap flash

Deliberately left duplicated (extracting would cost more than it saves):
- **`ChunkStreamingManager.get_tile_global` / `get_height_global`** — the shared part is the chunk-cache lookup, and both are passed as `Callable`s into the pathfinder and the 49-sample height scan. Any extraction returning a chunk-plus-local-coords pair allocates per call, in exactly the path GID-121 optimised
- **`TextureGen._gen_prop_*`** — hand-tuned pixel art. The common shape needs ~11 positional arguments, so a shared helper would make the art harder to tune, not easier
- **Seed-cached noise getters** (`TerrainMath._get_ley_noise_a/_b`, `InfiniteWorldGen._get_biome_noise`) — the bulk is the per-cache static guard, which cannot be shared without coupling the two modules for about nine lines
