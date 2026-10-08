# Story Implementation

Narrative source of truth is in `docs/human/story.md`. This file covers only the technical implementation: how story flags are stored, which scripts gate dialogue, and what code changes are needed to drive each story beat.

---

## Key Features

- Story progression tracked via boolean flags in `SaveManager.story_flags: Dictionary`
- Flags gate NPC dialogue — the same NPC position returns different lines before and after a story event
- Story mode starts by loading `madrian` instead of the sandbox `main` map
- All named maps are text files parsed by `WorldMap`; entity lines encode NPC dialogue directly

---

## How It Works

### Story Flags

Flags live in `SaveManager` under `story_flags: Dictionary = {}`. Set a flag via:

```gdscript
SaveManager.story_flags["chapter1_warned_farsyth"] = true
SaveManager.mark_dirty()
GameBus.emit_signal("story_flag_set", "chapter1_warned_farsyth")
```

Check a flag anywhere:

```gdscript
if SaveManager.story_flags.get("chapter1_warned_farsyth", false):
    label.text = "You've already delivered the news."
```

### Planned Flags

| Flag Key | Type | Set When |
|---|---|---|
| `story_intro_complete` | bool | Player speaks to Maiteln in Madrian |
| `chapter1_left_madrian` | bool | Player exits Madrian map |
| `chapter1_camp_night` | bool | Player wins the rabbit-hunt scripted tutorial battle at the first wilderness camp (GID-108 / TID-402) |
| `chapter1_learned_fire` | bool | Player interacts with the wilderness camp a second time, after `chapter1_camp_night` (GID-108 / TID-402) |
| `chapter1_warned_farsyth` | bool | Player speaks to Lord Farsyth in farsyth_mansion |
| `chapter1_received_letter` | bool | Isfig open-world encounter triggered |
| `chapter1_reached_blancogov` | bool | Player enters blancogov map |
| `chapter1_temple_council` | bool | Player speaks to King Eldar in blancogov_temple |

### Dialogue Gating in TownspersonNPC

`TownspersonNPC.get_dialogue()` currently returns a single static string from the map file. To support flag-gated lines, extend it to accept an optional flag check:

```gdscript
# Current
func get_dialogue() -> String:
    return _dialogue

# Target — reads flag from SaveManager if a flag key is embedded in the map entity line
func get_dialogue() -> String:
    if _flag_key != "" and SaveManager.story_flags.get(_flag_key, false):
        return _after_flag_dialogue
    return _dialogue
```

Map entity syntax for flag-gated NPCs (proposed extension):

```
NPC x z FLAG:flag_key before_text || after_text
```

### Starting Story Mode

New Game enters the overworld (`main`) at Madrian's spawn: the outdoor story towns are
stitched into it (GID-138, see `named-maps-and-dungeons.md` "Stitched Story Realm").

### Objective Tracking

The story's objectives are one ordered table, `game_logic/quests/StoryQuests.gd`
`STEPS` (GID-140). Each step has `id`, `chapter` (title in `CHAPTERS`), `label`,
`giver`, `summary` (a line or two of "why", shown in the Journal), `done_flag`, and a
place (`map`, `tx`, `tz`, optional `site`). The current step is the one after the
most advanced step whose `done_flag` is set (`current_index`), so a save missing an
earlier flag still lands on the right step; `STORY_END_FLAGS` end the table.
**Adding a story beat = one `STEPS` row** in story order.

`ObjectiveTracker.current_objective(flags)` returns the current step (or `{}`), and
its resolvers work for any target dict of the same shape: `to_realm`,
`place_on_map(target, map)`, `target_world_pos(target, map)`.

Coordinates are authored in the objective's own map; `realm_objective()` moves a
stitched town's tile into overworld tiles, and a `site` key names a fixed road tile in
`RealmLayout.STORY_SITES`.

| Flags state (most advanced) | Label | Map | Coords |
|---|---|---|---|
| _(none)_ | Speak to Maiteln | madrian | (45, 36) |
| `story_intro_complete` | Leave Madrian | main | site `madrian_south_road` |
| `chapter1_left_madrian` | Make camp for the night | main | site `wilderness_camp` |
| `chapter1_camp_night` | Learn to make fire | main | site `wilderness_camp` |
| `chapter1_learned_fire` | Find Lord Farsyth | farsyth_mansion | (49, 20) |
| `chapter1_warned_farsyth` | Encounter Isfig | main | site `isfig_road` |
| `chapter1_received_letter` | Reach Blancogov | blancogov | (49, 9) |
| `chapter1_reached_blancogov` | Enter the Temple | blancogov_temple | (42, 15) |
| `chapter1_temple_council` | Speak with the Queen and Scargroth, then the King | blancogov_temple | (42, 15) |
| `chapter1_complete` | Speak to King Eldar | blancogov_temple | (42, 15) |
| `chapter2_charged` | Travel west to Larik | larik | (64, 50) |
| `chapter2_reached_larik` | Search Larik for answers | larik | (59, 58) |
| `chapter2_found_letter` | Continue west toward Marsax Hold | main | site `scout_ambush` |
| `chapter2_ambush_survived` | Defend Marsax Hold | marsax_hold | (50, 77) |
| `chapter2_siege_won` | Search the hold for clues | marsax_hold | (52, 62) |
| `chapter2_traitor_seal` | Infiltrate the war-camp | marsax_hold | (20, 50) |

**In the overworld every objective is pointable** (`test_every_objective_is_pointable_from_the_overworld`):
stitched-town tiles and sites are overworld tiles, and an objective inside an interior
points at the stitched door leading in (`RealmLayout.door_into`). On a named map the
`(−1, −1)` wildcard still means "nothing to mark here". The original bug (GID-138):
"Leave Madrian" pointed at empty grass (50, 50) and the camp/fire/Isfig beats had no tile.

**Pointing at the objective — one pair of helpers, two consumers.** `ObjectiveTracker.objective_for_map(flags, map_name)` returns the objective only when it is a real place on *this* map (empty otherwise: no objective, another map, or a named-map wildcard tile; in the overworld see above), and `objective_world_pos()` turns that into the tile's **centre** in world space (entities sit on tile centres, so corner coordinates would put the marker a tile off-diagonal). Both consumers go through them, so they cannot disagree:

| Consumer | What it draws |
|---|---|
| `WorldHUD._create_compass()` → `CompassRibbon` primary marker | gold chevron on the ribbon + caption `"<label> — <distance>m"` |
| `QuestTracker` → `ObjectiveBeacon` | gold ring / light shaft / down-arrow on the tracked quest's tile |

Since GID-140 both follow the **tracked quest** (below), not only the story step. See `docs/agent/ui-and-scene-management.md` for both.

**MapViewOverlay integration**: When the overlay opens it reads the quest list once, shows `"Objective: <tracked label>"` and draws a diamond pin per quest with a place on the map.

### Quest Log & Tracked Quest (GID-140)

`game_logic/quests/QuestLog.gd` (pure static) turns save data into a list of quest dicts
`{id, kind, title, label, summary, giver, progress, targets}`:

| Quest | id | Source | Targets |
|---|---|---|---|
| Main story | `story` | `StoryQuests.current_step` | the step's place |
| Between chapters | `story` | past the last step | every bounty board (`bounty_board_targets()`) |
| Treasure | `treasure` | `active_treasure` (not completed) | dig site (overworld tile) |
| Bounty | `bounty:<id>` | `active_bounties` (unclaimed) | none while in progress; every bounty board once complete |
| Side quest | `side:<id>` | `SaveManager.quests.log_entries()` | first unfinished objective's `{map,tx,tz}` (or its `talk` NPC); the turn-in NPC once ready |

A quest with several targets points at the **nearest** (`QuestLog.world_pos(quest, map, from)`).
Kind colours: `QuestLog.KIND_COLORS` (story gold, treasure orange, bounty violet, side pale yellow).
Bounty text comes from `BountyGen.describe()` (shared with `BountyBoardScene`).

**Tracked quest.** `SaveManager.tracked_quest` (persisted; `""` = story) is set by the
Journal's Track button via `SaveManager.set_tracked_quest(id)`, which emits
`GameBus.quest_tracking_changed`. `QuestLog.tracked()` falls back to the story quest
when the tracked one is gone (bounty claimed, treasure dug). SaveManager wraps both:
`active_quests()`, `tracked_quest_data()`.

### Side Quests (GID-136 / TID-533)

WoW-style NPC asks, separate from the story chain.

- **Data:** `game_logic/quests/SideQuests.gd` — pure static `QUESTS` table (code, not `.tres`, like
  StoryQuests/EnemyRegistry — nothing to preload for Android). Keys: `id, title, giver, giver_name, turn_in,
  turn_in_name, summary, done_text, objectives[{type, target, count, label[, map, tx, tz]}], prereqs, min_level,
  req_flag, rewards{xp, coins, cards, flag}`. `giver`/`turn_in` are stitched-town NPC ids (`RealmLayout.entities`
  prefixes generic `npc_N` ids with the town, e.g. `madrian:npc_2`). Helpers: `def`, `can_offer`, `offers_for`,
  `upcoming_for`, `objective_matches`, `is_complete`, `progress_text`.
- **Objective types:** `kill` (enemy type, `""` = any), `use_skill` (skill id, or `skeleton_dig`), `learn`, `talk`,
  `flag`, `explore`, `open` (chest id), `rift_tier`.
  A `target` of `""` matches any event of that type.
- **Save:** `quests_active` (`{id: {"progress": [int]}}`) and `quests_completed` (`[id]`) in `PERSISTED_FIELDS`;
  API module `autoloads/save_manager/SaveQuests.gd` (`SaveManager.quests`): `accept`,
  `progress_event(type, target, amount)`, `is_ready`, `turn_in` (pays coins, cards, xp, sets `rewards.flag`),
  `offers_for(npc)`, `turn_ins_for(npc)`, `log_entries()`. A `flag` objective already met counts at accept.
- **Progress hooks:** `kill` from `BattleVictory` next to each bounty `defeat_enemy_type` increment (main + joined
  enemies; Spire kills excluded); `flag` from `SaveManager.set_story_flag`; `learn` from `SaveManager.learn_ability`.
  `talk` from `NpcInteractions.interact`; `use_skill` from `BattleRealtime._on_caster_event` / `BurialMound`; `open` from
  `ChestLoot.open` (GID-141). `explore` and `rift_tier` are wired by the tasks that add their sources (GID-142).
- **Starter chain** (GID-141 / TID-592): see `starter-zone-and-training.md`. Chapter 1 now opens with story step
  `help_townsfolk` (done_flag `town_quests_done`); Maiteln's Madrian NPC waits on it (`MapNpc.show_flag_key`).
- **Signals:** `GameBus.quest_accepted / quest_progressed / quest_ready / quest_turned_in(id)`.
- **Givers (TID-534):** any NPC can give quests — no special `npc_type`. `NpcInteractions.interact()` first counts a
  `talk` event for the NPC id, then `show_quest_panel(npc)`: a ready hand-in (done_text, rewards, **Complete**) wins
  over an offer (summary, objectives, rewards, **Accept** / **Decline**). Accepting tracks the quest
  (`set_tracked_quest("side:<id>")`). NPCs with a service type also get **Other business** →
  `interact_service(npc)` (the old `interact` body). Toasts via `GameBus.hud_message_requested`.
- **Marks:** `SaveQuests.npc_state(npc_id)` → `"turn_in" | "offer" | "upcoming" | ""`, passed to
  `QuestLog.npc_mark(..., side)`: yellow **?** (outranks the story "!"), yellow **!**, grey **!** (`side_upcoming`,
  offered after a level-up). `QuestTracker.on_side_quest_ready` toasts "<title> — done! Return to <npc>".
  WorldScene refreshes the tracker on every `quest_*` signal.
- **Placing NPCs:** `scripts/add_map_npc.py <map> <entity_id> <tx> <tz> <dialogue> [npc_type] [flag_key]
  [--hide flag] [--after text]` appends a `MapNpc` to a map `.tres` (idempotent). First giver: `hilda_baker` at
  Madrian (50,38), quest `rats_in_grain`.
- **Tests:** `tests/unit/test_side_quests.gd` (table integrity, every giver placed in a stitched town, gating,
  accept → progress → turn-in, JSON round trip, QuestLog entry, marks/npc_state).

**World module `QuestTracker`** (`scenes/world/modules/QuestTracker.gd`, `WorldScene.quest_tracker`).
`active_quests()` / `tracked_quest()` / `tracked_quest_pos()` / `quest_pos(q)` read a cache
(`quest_pos` memoises per quest id + map since GID-164 / TID-677) that `refresh(force)` rebuilds at most every `REFRESH_MS` (250 ms, from `WorldScene._process`)
and immediately on `story_flag_set` (`on_story_changed`) / `quest_tracking_changed` / map
load (`on_map_ready`). Each rebuild also moves the beacon (`_place_beacon`), so a claimed
bounty or a nearer board moves the marker with no flag change. It also owns the realm map
toggle (`toggle_realm_map`, called by `WorldScene._open_map_view` in the overworld — the
minimap tap opens it there; its **Fast Travel** button opens the waystone panel — and by an
interior map's **World Map** button, which passes `overworld_anchor()`, the spot the hero went in at).

**Realm map zoom (WoW-style).** Opens at `OPEN_ZOOM` on the hero; wheel / pinch / **+ −** zoom
about the pointer (1 = whole-realm overview, up to `MAX_ZOOM`), drag pans, **World** shows the
overview, **Me** re-centres. The draw layer clips to the panel (`clip_contents`).

**Painted realm map (`game_logic/world/RealmMapArt.gd`).** The map background is the real
overworld: `RealmMapArt.Painter` runs the chunk generator (`InfiniteWorldGen._gen_tile_data`) over
`realm_bounds()` and paints biome ground (borders jittered so chunk seams read as natural edges),
hill shading from the NW, streams / ponds / the sea (`WaterMath`), tree groves (`TreeScatter`) and
stamped roads, `TERRAIN_PX` px per tile; then each stitched town as an illustrated plan
(`town_image`: roofs from `building_plan`, cobbled `street_plan` streets, paths, walls, `TownDecor`
set pieces, lamps). It is charted on the **main thread** in slices — `QuestTracker._process` steps
`RealmMapOverlay.step_art(3 ms)` after an overworld load, the open map steps 12 ms/frame until ready
("Charting the realm…" with vector roads meanwhile). Don't move it to a `WorkerThreadPool` task:
an unjoined task deadlocked `WorldScene` teardown in `world_scene_smoke`. Textures are static
(per world seed) and mipmapped; town names sit on a ribbon above each plan.

**Quest areas (`game_logic/quests/QuestZones.gd`).** A quest dict's `zones` (`QuestLog.zones(q)`)
lists areas: a side-quest `kill` objective at a starter camp (its enemy slots, `R_CAMP`), a story
step with a `site` (`R_SITE`), and an unfinished `defeat_enemy_type` bounty (every camp of that
enemy). `QuestZones.outline()` casts the union of the spots' circles from their centroid with a
seeded wobble (cached); `MapMarkers.draw_quest_zones()` draws it translucent with a rim on the
minimap (clipped to the disc), realm map and interior map.

**Quest givers on the maps.** `QuestTracker.map_mark(node)` / `npc_map_marks()` read the
`QuestMark` Label3D, so all three map views show the same **!** / **?**. A walker with a mark
stays out after hours (`TownLife`) so it can be talked to at night (sieges still send it in).

| Consumer | Shows |
|---|---|
| Compass (`WorldHUD._create_compass`) | gold chevron + caption for the tracked quest; kind-coloured dots for untracked quests with a place |
| `ObjectiveBeacon` (`QuestTracker._place_beacon`) | on the tracked quest's nearest target |
| Minimap (`Minimap._draw_quests`) | quest areas; diamond per quest, tracked larger/outlined, clamped to the rim when off-disc; NPC !/? |
| Realm map (`RealmMapOverlay`) | quest areas; diamond per quest, tracked labelled; NPC !/? |
| Interior map (`MapViewOverlay`) | quest areas; diamond per quest; NPC !/? |
| Journal Quests tab | active quests (★ tracked), detail (giver, summary, progress), Track button, "Story so far" by chapter |

**NPC marks "!" / "?" (TID-586).** Each quest refresh, `QuestTracker._refresh_npc_marks()`
applies `QuestLog.npc_mark()` to every spawned NPC: a gold **!** over the NPC within one
tile of the story step's tile on this map (`ObjectiveTracker.place_on_map`); on a bounty
board a violet **?** when an accepted contract is ready to claim
(`QuestLog.has_bounty_turn_in`), else **!** when the day's offers are up and fewer than
3 are active. The mark is a `QuestMark` Label3D child, placed above the name tag and the
beacon's bobbing arrow, and only rewritten when it changes.

**New-objective tip.** `QuestTracker.announce_story_step()` shows `"New objective: <label>"`
on the HUD tip line (not the dialogue line, so the NPC's last words stay up) when the
story quest's label changes: on `story_flag_set`, and on `WorldScene._on_reattached` for a step
that moved during a battle. The baseline is set on map load, so loading never toasts.

### Wilderness Camp (GID-108 / TID-402)

The first-night camp (`docs/human/story.md` Chapter 1 beat 2) is a two-stage interactable
entity, `scenes/world/entities/WildernessCamp.gd` (+ `.tscn`), spawned by
`StoryCast.spawn_wilderness_camp()` via `StoryCast.spawn_open_world_beats()` (with the Isfig
rival and scout ambush) — placed at `RealmLayout.STORY_SITES["wilderness_camp"]` on the road
south of Madrian, re-checked on every overworld load and every `story_flag_set`, gated on
`chapter1_left_madrian` being set and `chapter1_learned_fire` not yet set.
`chapter1_left_madrian` is set by `RealmRegions` when the player walks out of Madrian after the intro. Procedural visuals
(unshaded log + emissive flame meshes — see `scenes/world/entities/WorldItem.gd`'s note that
all geometry in this game is unshaded, so no `OmniLight3D` is used).

Uses the same generic USE-prompt / tap-to-interact system as scrolls, shrines, and dig spots
(`WorldScene._check_interactions()` / `_handle_interact()`), which gives it mobile parity for
free. `interact()`:

1. **Before `chapter1_camp_night`:** toasts a flavor line via `GameBus.hud_message_requested`,
   then emits `GameBus.scripted_battle_requested("rabbit_hunt")` — the Chapter 1 tutorial
   battle (see `docs/agent/battle-system.md` "Scripted Story Battles"). Victory sets
   `chapter1_camp_night` via the `ScriptedBattleData.completion_flag` mechanism (no bespoke
   code needed here).
2. **After `chapter1_camp_night`, before `chapter1_learned_fire`:** toasts the fire-making
   line, sets `chapter1_learned_fire` directly via `SceneManager.save_manager.set_story_flag()`,
   then `queue_free()`s itself — its narrative purpose is served.
3. **Fallback:** a flavor-only toast if both flags are somehow already set (stale node from an
   earlier session; should be unreachable since stage 2 frees the node).

The rabbit-hunt battle content itself is `data/scripted_battles/rabbit_hunt.tres` — no `EnemyData`
resource exists for the "Wild Rabbit"; the scripted-battle framework builds the enemy deck
directly from `ScriptedBattleData.enemy_deck_order`, so an `EnemyRegistry` entry would be unused.

### Maiteln Journey Presence (GID-108 / TID-403)

`scenes/world/entities/MaitelnFollower.gd` (+ `.tscn`) is a visual/narrative companion avatar,
distinct from the battle-companion system (`data/companions/maiteln.tres`). `WorldScene` owns
all spawn/despawn gating via `StoryCast.maiteln_should_be_present()`: present whenever
`story_intro_complete` is set and `chapter1_complete` is not, AND either the story place is one
of `madrian` / `maykalene` / `farsyth_mansion` / `blancogov` / `blancogov_temple`, or the player
is anywhere in the overworld — since GID-138 the Chapter 1 towns and roads *are* the overworld.
`StoryCast.refresh_maiteln_presence()` (spawn-or-free to match the gate) runs once at the tail of
`_ready()` and again from `WorldScene._on_story_flag_set_for_cast()`, so he appears/disappears
immediately when a relevant flag flips mid-session, not just on the next map load.

That handler is wired in `WorldScene._wire_gamebus_signals()`, **not** in
`CoopSession._setup_coop()` where it used to live: `_setup_coop()` returns immediately when no
session is active, so a single-player run never got the live refresh and only saw the change
after a map reload. `CoopSession._on_local_story_flag_set()` now does nothing but the co-op
sync it is named for.

**He stops standing in Madrian once recruited.** `MapNpc.hide_flag_key` is a generic
"this NPC leaves their post once the flag is set" gate, and Madrian's `npc_1` — the Maiteln who
offers to take you away — carries `hide_flag_key = "story_intro_complete"`, the same flag that
makes the follower appear. `ChunkRenderer` skips spawning any NPC whose hide flag is already
set; `WorldScene.town_life.despawn_flag_hidden()` (same `_on_story_flag_set_for_cast()` handler)
frees one whose flag flips while the map is loaded — which is exactly the case here, since the
player sets it by talking to him. Note Madrian's `npc_2` (the master) shares `story_intro_complete`
as its *dialogue* flag, so talking to him first also completes the intro; Maiteln then joins as a
follower at the player's shoulder rather than being lost.

**No name tag.** Unlike every other world entity, `MaitelnFollower` builds no
`SpriteRegistry.make_name_label()` — he is beside the player for a whole chapter, so a permanent
floating label is clutter rather than identification.

**Movement:** `MaitelnFollower._process()` lerps toward a fixed world-space offset from the
player's position (`AvatarSync.interp()`, reusing the co-op avatar smoothing helper), snapping
instantly instead of lerping when the gap exceeds ~8 tiles (map transition, fast travel, a
door) — the "teleport when too far" simplification instead of pathfinding/walkable-tile
clamping. Y is recomputed from `WorldScene.get_terrain_height()` every frame, never lerped
(mirrors `RemotePlayer`'s Y-recompute pattern).

**Ambient lines:** `interact()` (same generic USE-prompt/tap system as scrolls/shrines/the
wilderness camp — mobile parity for free) looks up
`ObjectiveTracker.current_objective(story_flags)`'s label against a small const dict of
Scottish-register flavor lines (one per Chapter 1 objective state), falling back to a generic
line for an unmapped/empty label.

**Hidden in battles for free:** `SceneManager` fully detaches the `WorldScene` node from the
tree while a battle overlay is active, so every `_entity_root` child (Maiteln included) stops
processing and rendering with zero extra code.

**Known simplifications (not fixed, intentionally deferred):**
- The static madrian Maiteln NPC (fixed recruitment dialogue from the map file) is untouched;
  the follower can briefly coexist with it between recruiting and leaving madrian, since the
  research notes explicitly include madrian in the follower's map list.
- Co-op (fixed by GID-108 / TID-408): the follower now has a `networked` mode — the co-op
  authority's copy still runs the follow-the-player logic above and broadcasts its position;
  every other peer's copy is a passive puppet (`set_net_state`) that lerps toward the received
  `[x, z, map_name]` and is hidden/shown by the map filter, so there is exactly one Maiteln per
  session instead of one independent copy per client. See `docs/agent/multiplayer-coop.md`
  "Story Arc Co-op Compatibility (GID-108 / TID-408)" for the full design.

### Chapter 1 Ending (GID-108 / TID-405)

King Eldar (`blancogov_temple` npc_1) has `npc_type = "chapter1_king_eldar"`, a dedicated marker
in `WorldScene._handle_interact()`'s npc dispatch chain (same pattern as `merchant` /
`blacksmith` / `bounty_board` / `stable` / `duelist` / `rest_site` / `bed` / `trophy_pedestal`)
that bypasses the generic `TownspersonNPC.get_dialogue()` + `MapNpc.flag_key` auto-set path
entirely. His interaction needs four states that don't fit the 2-state `MapNpc` schema:

1. `chapter1_complete` already set → epilogue line.
2. `chapter1_temple_council` not yet set → sets it (first meeting, "the council is assembling"),
   shows his static `dialogue`.
3. `chapter1_temple_council` set AND both `chapter1_spoke_queen` and `chapter1_spoke_scargroth`
   set → `NpcInteractions._trigger_chapter1_ending()`.
4. Otherwise (council met, Queen/Scargroth not both spoken to yet) → an interim "council has
   heard the prophecy" line.

Queen (npc_2) and Scargroth (npc_3) use the ordinary `flag_key` mechanism —
`chapter1_spoke_queen` / `chapter1_spoke_scargroth` respectively, set automatically the first
time each is talked to (safe: unlike `chapter1_complete`, these are single-condition flags with
no compound gate). **Known simplification:** their `after_dialogue` is story.md's *post-ending*
epilogue line, shown as soon as they've been spoken to once rather than only after
`chapter1_complete` — the 2-state schema can't express three states, and the intended flow
(Queen → Scargroth → King Eldar, all in one visit) makes the gap narratively negligible.

`NpcInteractions._trigger_chapter1_ending()` sets `chapter1_complete` (which fires `StoryCast.refresh_maiteln_presence()`
for free via the TID-403 `_on_story_flag_set_for_cast` hook — the follower disappears with no new
code) and shows `scenes/ui/ChapterEndingOverlay.gd`, a new `BaseOverlay`-derived paged narration
overlay (`extends "res://scenes/ui/BaseOverlay.gd"`, path-string per the CLAUDE.md class_name
preload rule) with the three approved story.md pages. No scene transition — the player is
already in the world, so "return to the world as a playable epilogue" is simply closing the
overlay; the epilogue reactivity comes entirely from the TID-404 flag-gated dialogue lines that
key off `chapter1_complete` across the other named maps.

**Bug fix carried from TID-401** (found while reviewing `BaseOverlay` for this task):
`BaseOverlay._close()` only emits the `closed` signal — it does not free the node. The caller
must connect `closed` to free the wrapping `CanvasLayer` (`SceneManager._on_tutorial_popup_requested`
already did this correctly). `BattleScene.tutorials._maybe_show_scripted_tutorial_step` (TID-401) did not,
so the scripted-battle tutorial popup's "Got it" button was dead — fixed alongside this task's
own overlay wiring.

`ObjectiveTracker.current_objective()`'s `chapter1_temple_council` branch now returns
`{"label": "Speak with the Queen and Scargroth, then the King", "map": "blancogov_temple", "tx": 42, "tz": 15}`
instead of `{}` (previously a dead end).

The `chapter1_done` achievement (`game_logic/AchievementRegistry.gd`, `flag_key: "chapter1_complete"`)
fires automatically through the existing `SaveManager.set_story_flag` → `check_flag_achievement`
path — no new code needed.

### Chapter 2: The Road to Larik (GID-108 / TID-406, TID-407)

Flags, in progression order: `chapter2_charged` → `chapter2_reached_larik` →
`chapter2_found_letter` → `chapter2_ambush_survived` → `chapter2_siege_won` →
`chapter2_traitor_seal` → `chapter2_warcamp_cleared` → `chapter2_complete`.
`ObjectiveTracker.current_objective()` checks all of them most-advanced-first, ahead of the
Chapter 1 branches (`chapter1_complete` no longer means "the end" — it now returns "Speak to
King Eldar", the entry point into beat 1).

Every beat reuses an existing mechanism rather than building a parallel one:

1. **The council's charge** — a 5th state added to `WorldScene.NpcInteractions._king_eldar()`
   (see Chapter 1 Ending above): the first time King Eldar is spoken to after `chapter1_complete`,
   sets `chapter2_charged` and shows a one-off line, then falls through to the epilogue line.
2. **Return to Larik** — `chapter2_reached_larik` sets on first entry to `map_name == "larik"`
   (mirrors the `chapter1_reached_blancogov` on-map-enter pattern). The hidden-letter scroll
   (`scroll_larik_letter`, placed by TID-406 in `larik.tres`) sets `chapter2_found_letter` on
   collection — a scroll-id special case in `WorldScene._on_scroll_collected()` (no generic
   flag-on-collect field exists on `MapScroll`; not worth adding for two one-off hooks).
3. **Scouts in the grass** — `data/scripted_battles/scout_ambush.tres` (TID-401 framework),
   introducing 2 low-cost GID-076 spell cards (`ember_cinder`, `dawn_soothing_touch`) among
   minions. `scenes/world/entities/ScoutAmbush.gd` (+ `.tscn`) is the same
   tap-then-trigger-a-scripted-battle shape as `WildernessCamp` (TID-402), spawned by
   `StoryCast.spawn_scout_ambush()` when `chapter2_found_letter` is set and
   `chapter2_ambush_survived` isn't. Completion flag set via
   `ScriptedBattleData.completion_flag`, same as the rabbit hunt.
4. **Marsax hold besieged** — reuses the GID-054 siege gauntlet wholesale instead of a parallel
   story-siege system. `"marsax_hold"` added to `SiegeDefs.TOWN_GATES`;
   `TownSiege._check_story_trigger()` calls `save_manager.town_siege.start_siege("marsax_hold")` once
   on map entry (`chapter2_ambush_survived` set, `chapter2_siege_won` not, no siege already
   active), right before the existing `TownSiege.on_map_entered()`. `SceneManager._on_battle_won`'s
   final-stage-victory branch sets `chapter2_siege_won` when the winning siege's town is
   `"marsax_hold"`.
   - **BID-041 fixed opportunistically** (found while wiring this beat, affects the pre-existing
     random single-player siege too, not just this one): `TownSiege._spawn_raiders()` called
     `node.set("enemy_type", enemy_type)` — `EnemyNPC` has no such property, so every raider
     silently fell back to `"undead_basic"` regardless of stage or town. Replaced with a proper
     `init_from_data(edata)` call (mirrors `StoryCast._spawn_rival_at`'s exact pattern).
5. **The traitor's seal** — collecting `scroll_traitor_seal` (placed by TID-406 in
   `marsax_hold.tres`) sets `chapter2_traitor_seal`, same special case as the letter. Collectible
   immediately rather than gated behind `chapter2_siege_won` — `MapScroll.flag_key` exists on the
   resource but nothing anywhere enforces it (checked); wiring enforcement for one scroll wasn't
   worth it here.
6. **The war-camp** — `data/enemies/martarquas_warleader.tres` (`is_boss = true`, `boss_hp = 45`,
   a `phase2_deck`) is a real `EnemyRegistry` entry (unlike the scripted-battle enemies) because
   the war-camp boss uses the normal `enemy_engaged` pipeline, not the scripted-battle framework.
   `DungeonGen` has **no boss-room concept** (confirmed by grep), so
   `WorldScene._ready()`'s dungeon-load branch special-cases `map_name == "dungeon_731906"`
   (the war-camp door's fixed seed, from TID-406) to append one boss enemy dict directly to the
   freshly-loaded `WorldMap.enemies` — the existing chunk-based enemy-spawn pipeline handles the
   rest. Safe to re-inject on every visit: `ChunkRenderer.is_enemy_defeated()` already skips
   already-defeated enemies by id, and defeat state lives in `SaveManager.defeated_enemies`, never
   the dungeon's saved `.tres`. **Placement is a documented heuristic, not a hard guarantee** —
   see the code comment on `StoryCast.inject_warcamp_boss()` for the room-layout reasoning (tile (70, 30),
   the statistical z-centre of `DungeonGen`'s rightmost/deepest room column). The dungeon door
   itself (`assets/maps/marsax_hold.tres`) is gated behind `chapter2_traitor_seal` via the
   already-enforced `MapDoor.flag_key` mechanism (confirmed in `WorldScene._find_nearby_door`).
   Defeating the boss (`enemy_type == "martarquas_warleader"` in `SceneManager._on_battle_won`)
   sets `chapter2_warcamp_cleared`.
7. **Cliffhanger** — immediately after the war-camp boss win, `SceneManager._show_chapter2_cliffhanger()`
   reuses `scenes/ui/ChapterEndingOverlay.gd` verbatim (preloaded from `SceneManager.gd` this
   time, not `WorldScene.gd` — the class has no scene-specific dependency) with story.md's three
   cliffhanger pages; closing it sets `chapter2_complete`.

**Not implemented (per research notes, explicitly deferred):** an Isfig Chapter 2 cameo — noted
for a future goal.

**Co-op (GID-108 / TID-408):** every flag above rides the shared-flag arbitration for free (all
use the ordinary `set_story_flag()` path GID-098/TID-356 already arbitrates). Three real gaps
were found and fixed: the cliffhanger overlay now broadcasts to the whole party instead of only
the winning client (`GameBus.narration_overlay_requested`), the marsax_hold story siege is now
host-resolved instead of every peer starting a private local siege, and the war-camp boss fight
was confirmed to already share correctly via the generic co-op door-transition + enemy
engage-lock machinery (no joint multi-seat battle — a documented v1 fallback, same shape as the
tutorial-battle fallback used elsewhere in this goal). See `docs/agent/multiplayer-coop.md`
"Story Arc Co-op Compatibility (GID-108 / TID-408)" for the full breakdown.

---

### Pear Pudding Legend (GID-153)

A secret side story kept out of every quest system: tales (`Tales.gd`), riddle spots (`RiddleSpots.gd`) and the
`legend_*` story flags (personal, never co-op synced). See `legends-pear-pudding.md`.

## Integrations with Other Features

| System | Direction | Details |
|---|---|---|
| **SaveManager** | Owner | Stores `story_flags` dict; `mark_dirty()` after each flag set |
| **GameBus** | Signal | `story_flag_set(flag: String)` — emitted after a flag is set; UI or scene logic can react |
| **TownspersonNPC** | Consumer | Reads flags to select the correct dialogue line |
| **WorldMap** | Parser | Parses NPC entity lines from named map `.txt` files; must pass flag data through to `TownspersonNPC` |
| **SceneManager** | Entry point | `start_story_mode()` loads `madrian`; `load_map("madrian")` is the named-map path |
| **Named Maps doc** | Reference | Map file format, DOOR/NPC/SPAWN syntax — see `docs/agent/named-maps-and-dungeons.md` |
| **ScrollRegistry** | Companion | 8 lore scrolls placed in named maps via `SCROLL` directive; `collected_scrolls` in SaveManager (v6) |
| **StoryScroll** | Entity | Interactable entity in the world; triggers narration audio + Journal entry on collection |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Map files | `assets/maps/madrian.txt`, `maykalene.txt`, `farsyth_mansion.txt`, `blancogov.txt`, `blancogov_temple.txt` | Entity positions and dialogue from `docs/human/story.md` |
| `SaveManager.gd` | `autoloads/SaveManager.gd` | Add `story_flags: Dictionary = {}` field; persist in save/load; add to `_migrate()` |
| `GameBus.gd` | `autoloads/GameBus.gd` | Add `signal story_flag_set(flag: String)` |
| `TownspersonNPC.gd` | `scenes/world/entities/TownspersonNPC.gd` | Extend `get_dialogue()` for optional flag gating |
| `SceneManager.gd` | `autoloads/SceneManager.gd` | Add `start_story_mode()` method |
