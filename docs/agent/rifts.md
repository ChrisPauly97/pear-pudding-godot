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
  (`spire_floor_<floor>_<seed>_<rift>_<tier>` — TID-601 appended rift + tier so any peer can generate the floor
  from its name; `SpireFloorGen.map_name_for` / `parse_map_name`; legacy names without them still load; enemy ids
  stay unique per floor — see CLAUDE.md "Spire floor 2+ was an empty locked room").
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

### Rewards that can't be farmed + rift quests (TID-599)

- **Kills in a rift give no XP** (the Spire win path never calls `add_xp`) and don't count toward `kill` quests.
- **Per run:** `COINS_PER_FLOOR` (5) × floors cleared. **Per tier clear:** + `CLEAR_COINS_PER_TIER` (20) × tier and
  one card from the guardian's drop pool (rarity from `clear_drop_tier(tier)`), every time.
- **XP only once per (rift, tier):** `first_clear_xp(tier)` = 300 + 100·tier, recorded in
  `SaveManager.rift_first_clears` (`"<rift>:<tier>"`). Repeats pay coins and a card, never XP.
- A clear emits `GameBus.rift_tier_cleared(rift, tier)` and progresses `rift_tier "<rift>:<tier>"` quest objectives.
- **Rift quests** (`SideQuests`, giver `rift_warden_madrian` by Madrian's spire entrance, local (68,38)):
  Into the Rift (L15: learn Rifts, clear Grasslands T1 — 1500 XP), one "<Rift>: Tier 3" per rift (L16, 2500 XP),
  Grasslands Tier 5 (L20, 4000 XP). These — not repeated runs — are the rift's levelling reward.
- `SaveQuests.accept` now counts a `learn` objective already met (trained before taking the quest).
- The completion toast lists coins, first-clear XP, the card and the newly opened tier.

### Entrances (TID-600)

- **Madrian's Spire door** (`target_map "spire"`) opens the **Grasslands** rift.
- **Biome portals:** `InfiniteWorldGen._gen_entities` places a door with `target_map "rift:<id>"`
  (`RiftDefs.rift_for_biome(biome)`) in ~1 of `PORTAL_RARITY` (40) chunks at Chebyshev chunk distance ≥
  `PORTAL_MIN_CHUNK` (5), never in realm chunks — so every land has rifts to find while exploring. `Door.gd` draws
  them purple and labels them with the rift name.
- **Panel** (`scenes/world/modules/RiftPortals.gd`, `WorldScene.rift_portals`; WorldScene keeps
  `_show_spire_entrance_panel(rift_id)` as a forwarder): rift name, best tier, a −/+ tier picker capped at best + 1,
  enemy level range and the first-clear XP still on offer, Enter / Leave. Locked (`feat_spire`) → the ladder
  message. A run under way anywhere → Resume that run.
- WorldScene line ceiling lowered to 2100 after the panel moved out.

### Co-op rifts & per-rift leaderboard (TID-601)

- `SceneManager.enter_spire_coop(picker_order, rift, tier)` starts a co-op rift run (default: the host's next
  Grasslands tier — peers' bests aren't known on the host, so the host's decides). Floors are named with rift +
  tier, so every peer's `WorldScene` generates the same floor (`SpireFloorGen.parse_map_name`).
- The shared draft is unchanged (starter + shared picks for the joint battle).
- A win on the guardian floor ends the co-op run as a **tier clear**: the authority's
  `recv_coop_spire_run_ended` payload carries `rift, tier, tier_cleared`; every peer then calls
  `SaveSpire.record_tier_clear()` on its own save (best tier, one-time first-clear XP, quest progress) and posts
  the tier to that rift's board.
- **Leaderboards:** `SessionState._PVE_BOARDS` gains `rift_<id>` per rift (value = best tier cleared); sanitize /
  snapshot / defaults now loop over the board list (no session migration needed). Solo clears in a session post
  there too. `LeaderboardOverlay`'s "Spire" tab is now **Rifts**, one section per rift.

## Integrations

- Unlock ladder (`feat_spire`, L15), zone levels, co-op Spire (TID-601), rift quests (TID-599), entrances (TID-600).

## Asset Requirements

None yet (portals reuse the spire door until TID-600).
