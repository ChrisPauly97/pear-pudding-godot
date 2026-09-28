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

- **Skill rows** (`kind: "skill"`) read `level_req` / `learn_cost` from `SkillBar.ABILITIES` — never duplicated.
  `SkillBar.ALWAYS_KNOWN` is now just `["strike"]`; `LEARNABLE_ORDER` includes Mend and Kick.
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
- `new_game()` resets `learned_abilities` and `skill_bar`; **Head Start (debug)** learns the whole ladder.
- Migration v44 (`SaveMigrations._m44_unlock_ladder`): existing saves get every ladder *feature* plus Mend/Kick;
  riding only if they own a mount; unbought trainer skills stay unlearned.
- `SkillBar.resolved_bar()` pads unknown slots with `""` (shown as "—") instead of offering unlearned skills;
  `SkillBar._init` falls back to the known part of `DEFAULT_BAR`.

### XP pacing

Curve unchanged: level L is reached at a total of `xp_for_level(L) = 50·L²` XP (L2 200, L3 450, L4 800, L5 1 250,
L6 1 800, L10 5 000, L15 11 250, L40 80 000). Early levels come from starter quests (TID-592) plus camp kills
(20 XP at level 1); zone levels (TID-536) scale kill XP up by 10 %/level, so the same curve stretches toward the
long-term level-40 riding goal. `test_side_quests.test_starter_chain_paces_levels_and_gold` walks the chain on
the real numbers.

### Combat gates (TID-588)

Documented in `docs/agent/combat-model.md` → "New-player onboarding": bar = learned skills, hand from
`feat_minions`, spell cards from `feat_spells`, companion from `feat_companion`, real-time forced until the hand
exists (`SaveManager.battle_mode()`), Maiteln barks up to level 12.

### World & menu gates (TID-589)

Every gate calls `save_manager.has_learned(UnlockLadder.FEAT_X)`; a blocked action toasts
`UnlockLadder.locked_message(id)` ("<title> isn't learned yet — the <trainer> teaches it at level N.").

| Feature | Gate |
|---|---|
| Ghost Phase / Skeleton Dig | HUD buttons hidden until learned (`WorldHUD.refresh_action_cluster`, re-run on `feature_learned`); `Cantrips.activate_*` and `BurialMound.interact` refuse; the deck-family rule still applies after |
| Riding | `Mounts.LEVEL_REQ` = 40; stable purchase needs `feat_mount`; Mount button / T hidden or refused without it |
| Skills tab | `MenuHubScene.visible_tabs()` hides it until `feat_skills`; `skill_tree_requested` refuses |
| Skill Bar tab | hidden until the player knows more than Strike |
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
| South Field | (−7, 21) | undead_basic | 4 | 2 | no |
| The Old Orchard | (47, 19) | undead_horde | 4 | 3 | yes |
| North Barrow | (33, −21) | undead_horde | 4 | 4 | yes |
| Hedge Ruins | (53, −27) | ghoul_pack | 3 | 5 | yes |
| East Copse | (76, −2) | ghoul_pack | 4 | 6 | yes |
| West Crossing | (−55, 4) | undead_horde | 5 | 7 | yes |
| North Tor | (10, −62) | ghoul_pack | 4 | 8 | yes |
| South Road Wreck | (40, 45) | ghoul_pack | 5 | 9 | yes |

- Members stand in a ring of radius 3 around the camp tile (`slot_tile`), carry a preset `enemy_level` (so the
  authored level wins over the distance-based zone level, TID-536), and ids `camp_<camp>_<slot>`.
- **Refill:** every 1.5 s the module tops up camps within `ACTIVE_RANGE` (90 units) of the player; a fallen member
  refills after `CAMP_RESPAWN_S` (45 s); camps out of range despawn. `SaveManager.mark_enemy_defeated` ignores
  `camp_` ids, so they never enter the permanent defeated list. Solo only (inert in a network session).
- **Graveyard** (Madrian local (8..18, 47..56), fenced, gate on the north side): the Gravedigger
  (`gravedigger_madrian`, local (14,50)) and three fixed burial mounds (`GRAVEYARD_MOUNDS`, ids
  `mound_graveyard_N`, appended by `InfiniteWorldGen._gen_entities` via `mounds_in_chunk`) — the first Skeleton Dig
  targets.
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
- **New progress hooks:** `use_skill` from `BattleSkillBar` on every successful skill (Kick only succeeds when it
  interrupts), `use_skill "skeleton_dig"` from `BurialMound`, `open <chest id>` from `ChestLoot.open`.
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

- Combat gates (TID-588), world/menu gates (TID-589), trainer flow (TID-590), starter zone (TID-591), quest chain
  (TID-592) — see their sections as they land.
- Rifts (GID-142) are `feat_spire`.

## Asset Requirements

None beyond existing NPC sprites.
