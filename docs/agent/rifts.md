# Rifts (the Spire, reworked — GID-142)

D3-style rifts: one per biome, each with its own tier ladder. Floors, no timer. Pick a tier (up to your best + 1),
fight floor to floor, beat the guardian, and the next tier opens. Unlocked at level 15 (`UnlockLadder.FEAT_SPIRE`).

## Key Features

- Five rifts (`game_logic/spire/RiftDefs.gd`), one per biome, drawing on that biome's enemies; each tracks its own
  best tier (`SaveManager.rift_best_tiers`).
- `FLOORS_PER_TIER` (5) floors per run; the last holds the rift's guardian. Clearing it clears the tier.
- Enemy level = `BASE_LEVEL` (14) + 2 per tier + ½ per floor (+1 guardian), fed through the zone-level scaling
  (`ZoneLevels`: hero HP, card tier, XP con).

## How It Works

### Rift model (TID-597)

| Rift | Biome | Pool | Guardian |
|---|---|---|---|
| Grasslands Rift | 0 | undead_basic, undead_horde, wraith | undead_elite |
| Forest Rift | 1 | forest_shade, ghoul_pack, undead_basic | undead_elite |
| Desert Rift | 2 | sand_stalker, undead_horde | roaming_terror |
| Scorched Rift | 3 | scorched_revenant, undead_elite | roaming_terror |
| Mountain Rift | 4 | mountain_troll | stone_golem |

- **Run state** (`SaveManager.spire_run`) gains `rift` and `tier`. `SaveSpire.start_spire_run(seed, rift, tier)`
  (tier 0 = highest unlocked; clamped to best + 1), `best_tier(rift)`, `tier_complete()`.
  `end_spire_run()` adds `rift, tier, tier_cleared, is_new_tier_record, best_tier` to its stats and raises
  `rift_best_tiers[rift]` on a clear. Map names / cleared flags / enemy ids are unchanged
  (`spire_floor_<floor>_<seed>`, unique per floor — see CLAUDE.md "Spire floor 2+ was an empty locked room").
- **Floors:** `SpireFloorGen.generate(floor, seed, run)` picks `RiftDefs.enemy_type(rift, floor)` and stamps
  `enemy_level`; WorldScene passes the live run. Without a run the legacy ladder applies.
- **Guardian:** `BattleVictory._spire_battle_won` skips the draft on the guardian floor; the arena's exit door
  (unlocked by the cleared flag) calls `SceneManager._advance_spire_floor()`, which sees `tier_complete()` and runs
  `_complete_rift_tier()`: end the run, `spire_run_ended`, walk out (`exit_map` pops back to the entry), toast.
- **Entry:** `SceneManager.enter_spire(rift_id, tier)`.
- **Migration v45:** old `spire_best_floor` → Grasslands best tier (`floor / 5`); an active legacy run continues as
  Grasslands tier 1. `spire_best_floor` and the floor-5/10 achievement flags still update from floors cleared.

### Own deck + boons (TID-598)

- A rift run (`SaveSpire.uses_own_deck()` — the run has a `rift`) fights with the player's **own deck**:
  `BattleModifiers._build_rift_deck()` builds collection instances (rolled stats, veteran ranks) and appends the
  run's drafted cards; legacy / co-op runs still get `run_deck()` (starter + picks).
- **Between floors** the draft offers two temporary cards and one **buff boon** (`RiftDefs.BOONS`: Vigor +6 max HP
  and heal 6, Bulwark 4 armor each fight, Keen Edge minions +1 attack). No draft after the guardian.
- Picks live only in `spire_run` (`draft_deck`, `boons`) — never `owned_cards` — and vanish when the run ends.
  `SaveSpire.drafted_cards()`, `boons()`, `add_boon()`; `RiftDefs.boon_total(boons, effect)`.
- Ladder gates still apply inside a rift (spell cards need `feat_spells`, TID-588).

## Integrations

- Unlock ladder (`feat_spire`, L15), zone levels, co-op Spire (TID-601), rift quests (TID-599), entrances (TID-600).

## Asset Requirements

None yet (portals reuse the spire door until TID-600).
