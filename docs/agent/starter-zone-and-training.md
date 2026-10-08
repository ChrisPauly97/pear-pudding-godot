# Starter Zone & Trainer-Taught Unlocks (GID-141)

A new player learns the game one system at a time. Each level makes **one** new thing *available*; the player has to
visit that thing's trainer, read what it does and pay gold to learn it. Nothing on the ladder works until learned.

## Key Features

- One source of truth for what unlocks when: `game_logic/progression/UnlockLadder.gd`.
- Level-up only announces training (`GameBus.training_available`); learning happens at a trainer for gold.
- A fresh save knows only Strike and auto-attack.
- Existing saves are migrated whole (they keep every system they already had).

## How It Works

### The ladder (TID-587)

`UnlockLadder.LADDER` rows `{id, kind, trainer, title, how_to[, level_req, cost]}`:

| Lvl | id | Trainer | Gold |
|---|---|---|---|
| 1 | Strike + auto-attack | — (known) | — |
| 2 | `mend` | combat | 15 |
| 3 | `kick` | combat | 25 |
| 4 | `feat_minions` (hand / minion cards in battle) | combat | 40 |
| 5 | `feat_spells` (spell cards) | combat | 60 |
| 6 | `feat_companion` (Maiteln as battle companion) | maiteln | 80 |
| 7 | `feat_skills` (Skills tab + magic type) | maiteln | 100 |
| 8 | `feat_bounties` | bounty | 120 |
| 9 | `feat_night_hunts` | bounty | 140 |
| 10 | `feat_dig` (Skeleton Dig) | gravedigger | 175 |
| 11 | `guard` | combat | 60 |
| 12 | `feat_phase` (Ghost Phase) | gravedigger | 220 |
| 13 | `ember_lance` | combat | 90 |
| 14 | `mana_tap` | combat | 90 |
| 15 | `feat_spire` (Rifts, GID-142), `feat_packs` | combat, merchant | 300, 200 |
| 16 | `sweep` | combat | 120 |
| 18 | `daze` | combat | 150 |
| 40 | `feat_mount` (riding) | stable | 1000 |

- **Skill rows** (`kind: "skill"`) are technique cards (GID-175): `level_req` / `learn_cost` come from
  `TechniqueDefs.DEFS["tech_<id>"]` — never duplicated. Strike is always known (a starter-deck card).
- `how_to` is the text the trainer shows (the "read it before you buy it" moment) — keep it concrete: what the
  button is, where it appears, when to use it. Soulbinding is introduced in the minion/spell rows.
- API: `def`, `has`, `level_req`, `cost`, `trainer_for`, `trainer_name`, `is_learned` (non-ladder ids are always
  on), `can_learn`, `available_at(level)`, `pending(level, learned)`, `for_trainer`, `ids_up_to`, `all_ids`.

### Save

- Learned entries live in `SaveManager.learned_abilities` (already persisted). `SaveManager.has_learned(id)` is the
  gate every system checks. `learn_ability(id, cost)` deducts coins (now emits `coins_changed`), slots a learned
  skill into a free slot of a customised bar, progresses `learn` quest objectives and emits
  `GameBus.feature_learned(id)`.
- `add_xp` emits `GameBus.training_available(ids)` with every entry unlocked by the level(s) just gained.
- `new_game()` resets `learned_abilities` and deals Strike into the starter deck; **Head Start (debug)** learns the whole ladder.
- Migration v44 (`SaveMigrations._m44_unlock_ladder`): existing saves get every ladder *feature* plus Mend/Kick;
  riding only if they own a mount; unbought trainer skills stay unlearned.
- (Skill-bar slot padding is gone: techniques are cards, GID-175.)

### XP pacing

**Slow curve (GID-177 / TID-721):** `game_logic/progression/XpCurve.gd` is derived from the pacing targets: level 1
takes about **10 min**, each later level 5 min more (L9 ≈ 50 min, about 4.5 h to level 10), at a modelled
`XP_PER_MIN_L1` 30 XP/min growing 10 %/level like kill XP. `step(L)` = minutes × XP/min (rounded to 10), and
`xp_to_reach(L)` sums them: L2 300, L3 800, L4 1 520, L5 2 500, L6 3 760, L10 12 260, L15 32 900, L40 430 450. (The old curve was 50·L²: L10 5 000.)
`SaveManager.xp_for_level` / `_compute_level` forward to it. From level 3 a level is meant to be 3–4 quests + kills;
GID-177 TID-722 / TID-723 bring the quest supply and quest / kill XP in line with the curve.
`test_side_quests.test_starter_chain_paces_levels_and_gold` walks the chain (grinding camps between quests as
needed, bounded); tests: `tests/unit/test_xp_curve.gd`.

## Combat gates (TID-588)

Documented in `docs/agent/combat-model.md` → "New-player onboarding": bar = learned skills, hand from
`feat_minions` (Ally slots shown locked until then; enemies field 1 minion before it, 2 after — BID-085), spell cards from `feat_spells`, companion from `feat_companion`, real-time forced until the hand
exists (`SaveManager.battle_mode()`), Maiteln barks up to level 12.

### World & menu gates (TID-589)

Every gate calls `save_manager.has_learned(UnlockLadder.FEAT_X)`; a blocked action toasts
`UnlockLadder.locked_message(id)` ("<title> isn't learned yet — the <trainer> teaches it at level N.").

| Feature | Gate |
|---|---|
| Ghost Phase / Skeleton Dig | HUD buttons hidden until learned (`WorldHUD.refresh_action_cluster`, re-run on `feature_learned`); `Cantrips.activate_*` and `BurialMound.interact` refuse; the deck-family rule still applies after |
| Riding | `Mounts.LEVEL_REQ` = 40; stable purchase needs `feat_mount`; Mount button / T hidden or refused without it |
| Skills tab | `MenuHubScene.visible_tabs()` hides it until `feat_skills`; `skill_tree_requested` refuses |
| Technique cards | Strike in the starter deck; each trainer-taught technique adds its card (GID-175) |
| Companion | Character page companion slot hidden until `feat_companion` (battle side in TID-588) |
| Bounty board | `SceneManager._on_bounty_board_requested` refuses until `feat_bounties` |
| Night hunts | `NocturnalSpawner.tick` spawns nothing until `feat_night_hunts` |
| Spire / Rifts | `SceneManager.enter_spire` refuses until `feat_spire` |
| Card packs | `ShopScene` packs section hidden until `feat_packs` |

Co-op / PvP stay reachable from the main menu (not on the ladder). Night hunts are a local spawner, so each peer's
own ladder decides what it sees.

### Trainer flow (TID-590)

- **Trainers** (`UnlockLadder.TRAINER_NPCS`, `trainer_at(npc_id)`): combat → `trainer_madrian`, bounty →
  `bounty_master_madrian` (by the board), gravedigger → `gravedigger_madrian`, merchant → `merchant_8`,
  stable → `stable_master`; **Maiteln** teaches through his follower node (`MaitelnFollower.interact`).
- **Panel** `NpcInteractions.show_trainer_panel(trainer, service_npc = {})`: every row the trainer teaches —
  learned ✓, locked (grey "Come back at level N"), or available: full `how_to` + **Learn — N gold** (disabled with
  "Need N more gold" when short). Learning rebuilds the panel. A service NPC (merchant, stable…) gets
  **Other business** → `interact_service(npc)`.
- **Talking to a trainer** (`NpcInteractions.interact`): quests first, then — when `trainer_has_pending(trainer)` —
  the teach panel; otherwise the NPC's normal interaction. The combat trainer (`npc_type "trainer"`) always opens it.
- **Level-up** → `GameBus.training_available(ids)` → `QuestTracker.on_training_available`: toast "New training:
  Mend — see Combat Trainer", tracks the **Training Available** quest (`QuestLog.training_quest`, kind
  `training`, light blue), which points compass/beacon/minimap at the trainer(s).
- **Marks:** a trainer with pending training wears a blue **!** (`QuestLog.npc_mark(..., training)`; the story
  "!" and a side-quest "?" outrank it); so does Maiteln's follower.
- **Learned** → `GameBus.feature_learned(id)` → `QuestTracker.on_feature_learned`: "Learned: X" toast, the matching
  `TutorialRegistry` guide once (`_LEARNED_GUIDES`), and a gold pulse on the new HUD button (`WorldHUD.pulse_action`,
  `_LEARNED_BUTTONS`). Once nothing is pending the training quest disappears and tracking falls back to the story.

### Starter zone — Madrian's outskirts (TID-591)

`game_logic/world/StarterZone.gd` (pure data) + the `StarterCamps` world module
(`scenes/world/modules/StarterCamps.gd`, `WorldScene.starter_camps`, ticked in the overworld branch next to
`nocturnal`).

| Camp | Overworld tile | Enemy | × | Lvl | Chases? |
|---|---|---|---|---|---|
| Grain-Store Field | (21, 17) | undead_basic | 3 | 1 | no |
| South Field | (−7, 21) | undead_basic | 4 | 1 | no |
| The Old Orchard | (47, 19) | undead_horde | 4 | 2 | yes |
| North Barrow | (33, −21) | undead_horde | 4 | 2 | yes |
| Hedge Ruins | (53, −27) | ghoul_pack | 3 | 4 | yes |
| East Copse | (76, −2) | ghoul_pack | 4 | 5 | yes |
| West Crossing | (−55, 4) | undead_horde | 5 | 3 | yes |
| North Tor | (10, −62) | ghoul_pack | 4 | 4 | yes |
| South Road Wreck | (40, 45) | ghoul_pack | 5 | 4 | yes |

- **Levels are derived, not authored (GID-176 / TID-719):** `StarterZone.camp_level(camp)` = its tile's zone level
  clamped to the enemy type's sub-range (`ZoneLevels.enemy_level_at`). Madrian Outskirts is levels 1–5, so the camps
  span 1–5 (table above). Level 5+ continues on the road zones (GID-177 / TID-722). `camp_for_level` picks the nearest
  camp. The Barrow King is a unique boss at a fixed level 10 (top of Chapter 1).
- Members stand in a ring of radius 3 around the camp tile (`slot_tile`), carry that level as a preset
  `enemy_level`, and ids `camp_<camp>_<slot>`.
- **Refill:** every 1.5 s the module tops up camps within `ACTIVE_RANGE` (90 units) of the player; a fallen member
  refills after `CAMP_RESPAWN_S` (45 s); camps out of range despawn. `SaveManager.mark_enemy_defeated` ignores
  `camp_` ids, so they never enter the permanent defeated list. Solo only (inert in a network session).
- **Camp set dressing (GID-166 / TID-687):** every camp looks like its name — `CampDressing.LAYOUTS` (camp id →
  `[prop key, tile offset, world height]`; the Old Orchard is a generated 4×4 grid of apple trees + baskets).
  Grain-Store Field: granary, hay, sacks, scarecrow; South Field: scarecrow, wheat sheaves, hay; North Barrow:
  barrow mound ringed by standing stones; Hedge Ruins: broken pillars, rubble, hedges; East Copse: oaks + ferns;
  West Crossing: signpost, fences, barrel/crate; North Tor: stacked tor rock + boulders; South Road Wreck:
  overturned cart, crates, barrels. Offsets stay off the member ring (`test_camp_dressing`). Sprites are
  `camp_*.png` from `tools/generate_camp_props.py` (looked up by `CampDressing.texture()`, which also maps
  stock props as `"tree_oak_1"`, `"boulder_0"`…); billboards without collision, spawned by
  `StarterCamps._build_camp_dressing()`. Each camp is a **clearing**: `StarterZone.CAMP_CLEAR_RADIUS` (6 tiles)
  feeds `RealmLayout.reserved_distance` / `stamp_context` / `chunk_touches_realm` like a legend glade (flat, no
  random trees, water or spawns; the distance floors at `CAMP_SITE_PAD` so it is never paved).
- **Graveyard** (Madrian local (8..18, 47..56), fenced, gate on the north side): the Gravedigger
  (`gravedigger_madrian`, local (14,50)) and three fixed burial mounds (`GRAVEYARD_MOUNDS`, ids
  `mound_graveyard_N`, appended by `InfiniteWorldGen._gen_entities` via `mounds_in_chunk`) — the first Skeleton Dig
  targets.
- **Dressing (GID-143 / TID-605):** the graveyard edge is a low **iron fence** — one flat, double-sided panel per
  edge tile, laid along the tile edge (`axis` "x"/"z" in `graveyard_props()`, billboarding off) so it follows the
  isometric lines; camera-facing billboards all turned front-on and broke the enclosure. Props (the old wall
  tiles are now open ground), with headstones in rows and a **crypt door** facade in front of the sealed crypt —
  `StarterZone.graveyard_props()` (Madrian-local tiles) spawned once by `StarterCamps._build_scenery()`, textures
  from `SpriteRegistry.graveyard_prop()` (generated by `tools/generate_sprites.py`).
- **Sealed crypt** (local (22..26, 48..52), fully walled, no door): chest `sealed_crypt_chest` (shrouded_wraith,
  dusk_seer) — reachable only with Ghost Phase; a visible tease from the south field long before level 12.
- Fixed on the way: `WorldMap` dropped a `MapChest`'s `card_ids` (a `PackedStringArray` is not an `Array`).

### Starter quest chain (TID-592)

Quests live in `SideQuests.QUESTS` (see `story-implementation.md` → Side Quests). Townsfolk givers are Madrian NPCs
(`hilda_baker`, `wenna_herbalist`, `brother_aldo`, `old_tam`, `ivy_chandler`; trainers give the later ones).

| # | Quest | Giver | Lvl | Teaches / asks | Camp | XP · gold |
|---|---|---|---|---|---|---|
| 1 | Rats in the Grain Store | Hilda | 1 | 3 kills (auto-attack + Strike) | Grain-Store Field | 150 · 20 |
| 2 | Bruised and Battered | Wenna | 2 | learn Mend, Mend in a fight, 4 kills | South Field | 180 · 30 |
| 3 | The Chanting in the Orchard | Brother Aldo | 3 | learn Kick, 2 interrupts, 3 kills | Old Orchard | 240 · 45 |
| 4 | Raise the Fallen | Old Tam | 4 | learn minions, 4 kills | North Barrow | 270 · 60 |
| 5 | First Spark | Ivy | 5 | learn spells, 3 kills → **`town_quests_done`** | Hedge Ruins | 350 · 80 |
| — | *Maiteln arrives* (story `speak_maiteln`) — teaches companion (L6) and magic/skills (L7) | | | | | |
| 6 | Trouble in the East Copse | Old Tam | 6 | 4 kills | East Copse | 400 · 80 |
| 7 | Hold the West Crossing | Brother Aldo | 7 | 5 kills | West Crossing | 450 · 100 |
| 8 | The Board by the Well | Bounty Master | 8 | learn Bounties, 4 kills | North Tor | 520 · 120 |
| 9 | After Dark | Bounty Master | 9 | learn Night Hunts, 2 wisps | (night) | 560 · 140 |
| 10 | The South Road Wreck | Hilda | 9 | 5 kills | South Road Wreck | 600 · 150 |
| 11 | Old Bones | Gravedigger | 10 | learn Dig, dig a graveyard mound | Graveyard | 800 · 200 |
| 12 | The Sealed Crypt | Gravedigger | 12 | learn Phase, open the crypt chest | Sealed crypt | 1000 · 250 |

- **Story gate:** new first step `StoryQuests` `help_townsfolk` ("Help the townsfolk of Madrian", Hilda's tile,
  done_flag `town_quests_done`). Madrian's Maiteln NPC (`npc_1`) carries `MapNpc.show_flag_key =
  "town_quests_done"`: `ChunkRenderer` skips it until then and `StoryCast.spawn_flag_shown_npcs()` spawns it the
  moment the flag flips. Migration v44 sets `town_quests_done` on existing saves.
- **New progress hooks:** `use_skill` from `BattleRealtime._on_caster_event` ("technique") when a technique card resolves in
  real time (ability id, e.g. `mend`), `use_skill "skeleton_dig"` from `BurialMound`, `open <chest id>` from `ChestLoot.open`.
- Pacing is asserted by `test_side_quests.test_starter_chain_paces_levels_and_gold`: quest kills only, real kill
  XP/coins, every training affordable when its quest asks for it, level 6 + companion gold at the end.

### Visual finish pass (TID-593 / TID-594)

xvfb audit of the first 30 minutes (findings table in TID-593). Fixed: XP bar showed the previous level's span
("0 / 50" at L1 — `WorldHUD._level_start_xp`), trainers and quest givers wear their names
(`TownspersonNPC._extract_name` → `UnlockLadder.trainer_name` / `SideQuests.giver_name_for`), Combat Trainer +
dummy and the merchant moved off wall tiles (`test_starter_zone.test_named_npcs_stand_on_open_ground` guards every
Madrian NPC), quest panel height hugs its text, Ley-Attuned chip moved below the compass label. Art-sized items are
BID-065 (placeholder undead + townsfolk sprites), BID-066 (graveyard dressing), BID-067 (menu key art).

## Integrations

- Quests: `SideQuests` / `SaveQuests` / `QuestLog` (`story-implementation.md`); story gate `help_townsfolk`.
- Levels: `ZoneLevels` story-route zones (`enemies-and-npcs.md`); camps derive their level from their zone + type.
- Combat: `CombatOnboarding` / `BattleOnboarding` (`combat-model.md`).
- World modules: `StarterCamps`, `QuestTracker` (training marks + notices), `StoryCast` (flag-shown NPCs).
- Rifts (GID-142) are `feat_spire`.
- Co-op: the ladder is per save; joiners' session characters carry their own `learned_abilities`. Starter camps are
  solo-only; night-hunt spawns are local per peer.

## Asset Requirements

None beyond existing NPC sprites.
