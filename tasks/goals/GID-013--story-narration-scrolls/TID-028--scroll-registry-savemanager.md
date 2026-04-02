# TID-028: Scroll registry, SaveManager fields, GameBus signal

**Goal:** GID-013
**Type:** agent
**Status:** done
**Depends On:** —

## Lock

**Session:** none
**Acquired:** —
**Expires:** —

## Context

All other tasks in GID-013 depend on: (a) a `ScrollRegistry` autoload holding every scroll's metadata, (b) `SaveManager` tracking which scrolls have been collected, and (c) a `GameBus.story_scroll_collected` signal for decoupled notification. This task establishes that foundation with no UI or world entities.

## Research Notes

**SaveManager.gd** (`autoloads/SaveManager.gd`):
- Currently at `CURRENT_SAVE_VERSION = 4`
- Migration pattern is sequential: `_migrate_v3_to_v4`, etc., called in `_apply_migrations`
- New field: `collected_scrolls: Array[String] = []`
- Migration needed: `_migrate_v4_to_v5` — backfill `collected_scrolls = []`
- Bump `CURRENT_SAVE_VERSION` to `5`
- Add `mark_scroll_collected(scroll_id: String)` — appends if not present, sets `_dirty`
- Add `is_scroll_collected(scroll_id: String) -> bool` — checks membership
- `new_game()` must reset `collected_scrolls = []`
- `save()` must include `"collected_scrolls": collected_scrolls` in the data dict
- `load_save()` must read it with `collected_scrolls.assign(data.get("collected_scrolls", []))`

**GameBus.gd** (`autoloads/GameBus.gd`):
- Add under `# Story signals`:
  ```gdscript
  signal story_scroll_collected(scroll_id: String)
  signal all_scrolls_collected()
  ```
- `story_scroll_collected` is emitted by `StoryScroll` (TID-029) after SaveManager is updated
- `all_scrolls_collected` is emitted in TID-033 once all scrolls are found

**ScrollRegistry.gd** — new autoload at `autoloads/ScrollRegistry.gd`:
- Register in `project.godot` as autoload `ScrollRegistry`
- Stores scroll definitions as `Array[Dictionary]`, each dict:
  ```gdscript
  { "id": String, "title": String, "lore_text": String, "audio_path": String }
  ```
- Public API:
  ```gdscript
  func get_scroll(id: String) -> Dictionary   # returns {} if not found
  func get_all_scrolls() -> Array[Dictionary] # all definitions
  const SCROLL_COUNT: int                     # total number of scrolls
  ```
- Audio paths follow pattern: `"res://assets/audio/narration/<id>.ogg"` — graceful no-op (AudioManager already handles absent files)

**Sample scroll content** (8 scrolls, based on `docs/human/story.md` lore):

| ID | Title | Placement |
|---|---|---|
| `scroll_larik_origins` | The Village of Larik | madrian |
| `scroll_martarquas_first_war` | The First War of Martarquas | maykalene |
| `scroll_maiteln_order` | The Order of Wizards | farsyth_mansion |
| `scroll_prophecy_text` | The Prophecy of Renewal | farsyth_mansion |
| `scroll_farsyth_lineage` | Lords of the Western Reaches | blancogov |
| `scroll_blancogov_founding` | The Founding of Blancogov | blancogov |
| `scroll_king_eldar_coronation` | The Coronation of King Eldar | blancogov_temple |
| `scroll_martarquas_survivors` | The Surviving Tribes | infinite world |

**Lore text content** — write 2–4 sentences per scroll from the story bible tone (Hobbit/Redwall, young protagonist, grounded fantasy):

- `scroll_larik_origins`: "Larik was a village of aspirations rather than achievements. It sat at the edge of the open grasslands, far from any road worth naming. The people there knew each other too well and nothing went unnoticed — least of all the morning Saimtar's parents vanished without a trace."
- `scroll_martarquas_first_war`: "The Martarquas were once the most feared tribe in all the known lands. They burned villages without warning and took no prisoners. It was only when the other tribes united — for the first and only time in memory — that the Martarquas were finally broken. But broken is not destroyed."
- `scroll_maiteln_order`: "Wizards of the old order kept no towers and sought no students. They moved through the world quietly, doing what needed doing and expecting no thanks for it. Maiteln was one of the last. He had watched kings rise and fall and kept his own counsel on most of it."
- `scroll_prophecy_text`: "The prophecy was not written in a grand tome but scratched into a flat river stone found in a shepherd's field. It read simply: when the scattered embers find each other, the flame will rise again. The temple scholars spent thirty years arguing about what it meant. Maiteln said he had known since the moment he read it."
- `scroll_farsyth_lineage`: "The Farsyth family had governed Maykalene for six generations. Each lord had added something — a road, a market, a wall. The current lord had added nothing yet, but he had only been in the seat three years, and some said caution was its own kind of wisdom."
- `scroll_blancogov_founding`: "Blancogov did not grow so much as it was placed. The first king chose the site for its rivers and its sight lines, then set stonemasons to work for a decade. When it was finished it was the finest city in the land and has remained so, though no one can quite agree on what fine means."
- `scroll_king_eldar_coronation`: "Eldar was crowned at twenty-two, younger than any king before him. His first act was to send letters to every lord in the realm. Not orders — letters. He wrote that he wished to know their lands, their troubles, and their names. Most lords had never received a letter from a king that was not a demand. Some wept."
- `scroll_martarquas_survivors`: "After the war, the surviving Martarquas scattered into the deep wilderness. Generations passed. The alliance relaxed. It is the nature of alliances to relax when the threat they were built against has not been seen for a long time. This is not wisdom. It is forgetting dressed up as peace."

**GDScript note:** `SCROLL_COUNT` must be a typed constant or property. Use:
```gdscript
const SCROLL_COUNT: int = 8
```

**project.godot registration** — must add `ScrollRegistry` to the `[autoload]` section:
```
ScrollRegistry="*res://autoloads/ScrollRegistry.gd"
```

## Plan

1. **SaveManager.gd**: add `collected_scrolls: Array[String] = []` field; bump version 5→6; add `_migrate_v5_to_v6`; update `_apply_migrations`, `new_game()`, `save()`, `load_save()`; add `mark_scroll_collected` and `is_scroll_collected` methods.
2. **GameBus.gd**: add `story_scroll_collected(scroll_id)` and `all_scrolls_collected()` signals under `# Story signals`.
3. **ScrollRegistry.gd**: create new autoload with 8 scroll definitions and `get_scroll`, `get_all_scrolls`, `SCROLL_COUNT` API.
4. **project.godot**: register `ScrollRegistry` in `[autoload]` section.

Note: Research notes said SaveManager was at v4; it's actually at v5 (weapon system bumped it in GID-014). Adjusting migration accordingly.

## Changes Made

- `autoloads/SaveManager.gd`: Added `collected_scrolls: Array[String] = []` field; bumped `CURRENT_SAVE_VERSION` 5→6; added `_migrate_v5_to_v6` (backfills `collected_scrolls = []`); updated `_apply_migrations`, `new_game()`, `save()`, `load_save()`; added `mark_scroll_collected(scroll_id)` and `is_scroll_collected(scroll_id) -> bool`.
- `autoloads/GameBus.gd`: Added `story_scroll_collected(scroll_id: String)` and `all_scrolls_collected()` signals under `# Story signals`.
- `autoloads/ScrollRegistry.gd`: Created new autoload with 8 scroll definitions (id, title, lore_text, audio_path) and `get_scroll`, `get_all_scrolls`, `SCROLL_COUNT` API.
- `project.godot`: Registered `ScrollRegistry` in `[autoload]` section.
- **Note**: Research notes assumed SaveManager was at v4; it was already at v5 (weapon system in GID-014 bumped it). Migration was adjusted to v5→v6.

## Documentation Updates

None required — foundation-only task; agent docs will be updated in TID-033 when the full system is complete.
