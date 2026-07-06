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

`SceneManager.start_story_mode()` loads `madrian` as the first map instead of the infinite-world `main`. Recommended implementation: a separate story save slot so the sandbox world is untouched.

### Objective Tracking

`game_logic/ObjectiveTracker.gd` provides a single static function:

```gdscript
static func current_objective(flags: Dictionary) -> Dictionary:
    # Returns {label: String, map: String, tx: int, tz: int} or {} if done/unknown
```

It checks flags in reverse-progression order (most-advanced first) and returns the *next* objective the player should pursue.

| Flags state (most advanced) | Label | Map | Coords |
|---|---|---|---|
| _(none)_ | Speak to Maiteln | madrian | (45, 36) |
| `story_intro_complete` | Leave Madrian | madrian | (50, 50) |
| `chapter1_left_madrian` | Make camp for the night | main | (−1, −1) wildcard |
| `chapter1_camp_night` | Learn to make fire | main | (−1, −1) wildcard |
| `chapter1_learned_fire` | Find Lord Farsyth | farsyth_mansion | (49, 20) |
| `chapter1_warned_farsyth` | Encounter Isfig | main | (−1, −1) wildcard |
| `chapter1_received_letter` | Reach Blancogov | blancogov | (49, 9) |
| `chapter1_reached_blancogov` | Enter the Temple | blancogov_temple | (42, 15) |
| `chapter1_temple_council` | _(empty — chapter ending)_ | — | — |
| `chapter1_complete` | _(empty)_ | — | — |

**Wildcard objectives** (`tx == -1, tz == -1`) are open-world events with no fixed tile (e.g., the Isfig roadside encounter). The compass ribbon hides them (returns null from get_pos); the map overlay label still shows the objective text.

**CompassRibbon integration** (`WorldScene.gd`): A gold marker (`Color(1.0, 0.8, 0.0)`) is added with id `"objective"`. Its `get_pos` lambda calls `current_objective()` every frame and returns null when: the objective is for a different map, or coordinates are wildcard.

**MapViewOverlay integration**: When the overlay opens, it calls `current_objective()` once and shows `"Objective: <label>"` in gold above the close hint if an objective is active.

### Wilderness Camp (GID-108 / TID-402)

The first-night camp (`docs/human/story.md` Chapter 1 beat 2) is a two-stage interactable
entity, `scenes/world/entities/WildernessCamp.gd` (+ `.tscn`), spawned by
`WorldScene._spawn_wilderness_camp()` right alongside `_spawn_open_world_rival_enc2()` — same
"no fixed position, spawns near the player once per open-world load" pattern, gated on
`chapter1_left_madrian` being set and `chapter1_learned_fire` not yet set. Procedural visuals
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
all spawn/despawn gating via `_maiteln_should_be_present()`: present whenever
`story_intro_complete` is set and `chapter1_complete` is not, AND either the current map is one
of `madrian` / `maykalene` / `farsyth_mansion` / `blancogov` / `blancogov_temple`, or the map is
`main` during the TID-402 camp-beat window (`chapter1_left_madrian` set,
`chapter1_learned_fire` not yet set) — never general open-world sandbox presence.
`_refresh_maiteln_presence()` (spawn-or-free to match the gate) runs once at the tail of
`_ready()` and again from `_on_local_story_flag_set()` (already fires on every local
`story_flag_set`), so he appears/disappears immediately when a relevant flag flips mid-session,
not just on the next map load.

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
- Co-op: this is a **solo-only** follower — each client renders their own local instance
  independently, not synced. TID-408 (per its design rule 4) is the task that will replace this
  with a single authority-owned, network-synced Maiteln (mirroring `RemotePlayer` avatar sync,
  `map_name` carried in the payload).

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
   set → `WorldScene._trigger_chapter1_ending()`.
4. Otherwise (council met, Queen/Scargroth not both spoken to yet) → an interim "council has
   heard the prophecy" line.

Queen (npc_2) and Scargroth (npc_3) use the ordinary `flag_key` mechanism —
`chapter1_spoke_queen` / `chapter1_spoke_scargroth` respectively, set automatically the first
time each is talked to (safe: unlike `chapter1_complete`, these are single-condition flags with
no compound gate). **Known simplification:** their `after_dialogue` is story.md's *post-ending*
epilogue line, shown as soon as they've been spoken to once rather than only after
`chapter1_complete` — the 2-state schema can't express three states, and the intended flow
(Queen → Scargroth → King Eldar, all in one visit) makes the gap narratively negligible.

`_trigger_chapter1_ending()` sets `chapter1_complete` (which fires `_refresh_maiteln_presence()`
for free via the TID-403 `_on_local_story_flag_set` hook — the follower disappears with no new
code) and shows `scenes/ui/ChapterEndingOverlay.gd`, a new `BaseOverlay`-derived paged narration
overlay (`extends "res://scenes/ui/BaseOverlay.gd"`, path-string per the CLAUDE.md class_name
preload rule) with the three approved story.md pages. No scene transition — the player is
already in the world, so "return to the world as a playable epilogue" is simply closing the
overlay; the epilogue reactivity comes entirely from the TID-404 flag-gated dialogue lines that
key off `chapter1_complete` across the other named maps.

**Bug fix carried from TID-401** (found while reviewing `BaseOverlay` for this task):
`BaseOverlay._close()` only emits the `closed` signal — it does not free the node. The caller
must connect `closed` to free the wrapping `CanvasLayer` (`SceneManager._on_tutorial_popup_requested`
already did this correctly). `BattleScene._maybe_show_scripted_tutorial_step` (TID-401) did not,
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

1. **The council's charge** — a 5th state added to `WorldScene._handle_king_eldar_interaction()`
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
   `WorldScene._spawn_scout_ambush()` when `chapter2_found_letter` is set and
   `chapter2_ambush_survived` isn't. Completion flag set via
   `ScriptedBattleData.completion_flag`, same as the rabbit hunt.
4. **Marsax hold besieged** — reuses the GID-054 siege gauntlet wholesale instead of a parallel
   story-siege system. `"marsax_hold"` added to `SiegeDefs.TOWN_GATES`;
   `WorldScene._check_story_siege_trigger()` calls `save_manager.start_siege("marsax_hold")` once
   on map entry (`chapter2_ambush_survived` set, `chapter2_siege_won` not, no siege already
   active), right before the existing `_check_siege_spawn()`. `SceneManager._on_battle_won`'s
   final-stage-victory branch sets `chapter2_siege_won` when the winning siege's town is
   `"marsax_hold"`.
   - **BID-041 fixed opportunistically** (found while wiring this beat, affects the pre-existing
     random single-player siege too, not just this one): `_spawn_siege_raiders()` called
     `node.set("enemy_type", enemy_type)` — `EnemyNPC` has no such property, so every raider
     silently fell back to `"undead_basic"` regardless of stage or town. Replaced with a proper
     `init_from_data(edata)` call (mirrors `_spawn_rival_at`'s exact pattern).
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
   see the code comment on `_inject_warcamp_boss()` for the room-layout reasoning (tile (70, 30),
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

**Co-op:** none of the above has co-op arbitration — every flag site uses the same unwrapped
`SceneManager.save_manager.set_story_flag()` path every Chapter 1 flag already uses. TID-408 is
the task that adds shared-flag arbitration and joint-battle seating across all of Chapters 1 & 2
at once.

---

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
