# Vertical Slice (GID-188)

A 30–45 minute cut of the full game that proves the core loop is fun:
**explore → real-time card fight → soulbind → the deck changes the next fight and opens the world (Dig)**.
Out-of-slice systems are hidden, never deleted.

## Key Features

- One gate: project setting `pear_pudding/slice_mode` (on in `project.godot`).
- One table: `game_logic/SliceRules.gd` — `LEVEL_CAP`, `LADDER` (learnable UnlockLadder rows), `MENU`
  (main-menu entries), `BATTLE_MODE`.
- Feature freeze: inside the slice, a change lands only if it improves the core loop; other ideas go to the backlog.

## How It Works

| Gate | Where | Effect in the slice |
|---|---|---|
| Ladder | `UnlockLadder.available_at` / `pending` / `for_trainer` / `can_learn` | Only `SliceRules.LADDER` rows (Mend, Kick, Allies, spells, companion, Dig) appear at trainers or can be learned |
| Menu | `MenuScene._ready` | Co-op, Achievements, Map Editor hidden |
| Battle mode | `SaveManager.battle_mode()` → `SliceRules.battle_mode()` | Always real time; the Settings choice is ignored |
| Full Game | Settings toggle → `SliceRules.set_full_game()` (per device, `user://full_game.cfg`) | Turns the slice off on this device, live; the main menu re-applies on Settings close. Shown only when the build ships the slice |
| HUD | (indirect) | Mount / Phase buttons are already gated on `has_learned`, so the ladder gate hides them |

| Level cap | `SaveManager.add_xp` → `SliceRules.capped_xp` | XP stops at level 10 (`LEVEL_CAP`). Real pacing, ~4.5 h (no compression, user decision) |
| Quests | `SideQuests.can_offer` → `SliceRules.allows_quest` | Quests above the cap, with a `learn` target off the slice ladder, or a `rift_tier` objective are never offered |
| Boss | `StarterZone.barrow_king_awake` → `SliceRules.boss_quest` | The Barrow King (L10) wakes after `old_bones` (Dig), not `sealed_crypt` (Phase) |
| Ending | `BattleVictory` (Barrow King win) → `GameBus.narration_overlay_requested` | "Demo Complete" pages; closing sets `slice_complete` |

| New Game | `HeroAppearanceScene` → `SliceRules.shows_biome_picker` | No biome picker / Head Start toggle; starts in the grasslands (`START_BIOME`) |
| Idle trainers / stations | `ChunkRenderer` (`allows_npc`, `HIDDEN_NPCS`), `CraftingStations` (`allows_stations`) | Master Artisan, Bounty Master, Rift Warden, Stablemaster and profession stations not spawned |
| Gambits | `SceneManager._on_enemy_engaged`, `SwapDeckPrompt` → `allows_gambits` | Fights start without the gambit picker |
| Dev tools | `BattleRealtime` → `shows_dev_tools` | ⚙ Tune button and T key hidden |
| Telemetry | `PlaytestMetrics` / `SaveManager.playtest_log`, Diagnostics → Playtest | Time to first fight / win / capture / deck edit, counters, quit point, time to Demo Complete |

No hard region edge: levels 6–10 need the Chapter 1 road camps near Maykalene, so the world stays open and the
slice is bounded by level, ladder and quests. Chunk generation is threaded: if a later change gates world content,
pass the slice flag in as a pure input rather than reading `ProjectSettings` from worker code.

## Tests

- `tests/unit/test_slice_rules.gd`. `tests/runner.gd` sets `SliceRules.override = 0`, so every other suite
  tests the full game; a slice test sets `override = 1` and `after_each` resets it.
- Smoke tests run with the shipped setting (slice on). One that exercises full-game-only paths sets
  `override = 0` in `_initialize` (`battle_input_flow_smoke` — turn-based input).

## Integrations

UnlockLadder (trainers, level-up toasts), SaveManager settings, MenuScene. Follow-up tasks: GID-188 goal file.

## Asset Requirements

None.
