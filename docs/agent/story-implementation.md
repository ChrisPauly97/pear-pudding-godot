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
