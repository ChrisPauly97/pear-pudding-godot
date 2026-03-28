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

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| Map files | `assets/maps/madrian.txt`, `maykalene.txt`, `farsyth_mansion.txt`, `blancogov.txt`, `blancogov_temple.txt` | Entity positions and dialogue from `docs/human/story.md` |
| `SaveManager.gd` | `autoloads/SaveManager.gd` | Add `story_flags: Dictionary = {}` field; persist in save/load; add to `_migrate()` |
| `GameBus.gd` | `autoloads/GameBus.gd` | Add `signal story_flag_set(flag: String)` |
| `TownspersonNPC.gd` | `scenes/world/entities/TownspersonNPC.gd` | Extend `get_dialogue()` for optional flag gating |
| `SceneManager.gd` | `autoloads/SceneManager.gd` | Add `start_story_mode()` method |
