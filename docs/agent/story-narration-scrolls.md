# Story Narration Scrolls

## Key Features

- 8 lore scrolls scattered across named maps and the infinite world
- Collecting a scroll triggers non-blocking background narration audio (player keeps moving)
- NPC dialogue automatically suppresses narration to prevent overlap; resumes from the Journal
- All collected scrolls accessible via the Journal overlay (J key / Journal HUD button)
- Journal shows lore text and a "Replay Narration" button per scroll
- `SaveManager.collected_scrolls` persists which scrolls have been found across sessions
- Already-collected scrolls never re-spawn in the world
- Collecting all 8 scrolls emits `GameBus.all_scrolls_collected` as an achievement hook
- Audio files are optional — all features degrade gracefully when `.ogg` files are absent

---

## How It Works

### ScrollRegistry (`autoloads/ScrollRegistry.gd`)

Global autoload holding all 8 scroll definitions as `Array[Dictionary]`:

```gdscript
{ "id": String, "title": String, "lore_text": String, "audio_path": String }
```

Public API:
```gdscript
ScrollRegistry.get_scroll(id: String) -> Dictionary   # {} if not found
ScrollRegistry.get_all_scrolls() -> Array[Dictionary]
ScrollRegistry.SCROLL_COUNT: int  # 8
```

Audio paths follow the pattern `"res://assets/audio/narration/<id>.ogg"`. Place `.ogg` files there; the AudioManager's graceful no-op handles missing files.

### SaveManager Fields

`collected_scrolls: Array[String]` — added in save version 6. Migration `_migrate_v5_to_v6` backfills an empty array for old saves. Methods:

```gdscript
SaveManager.mark_scroll_collected(scroll_id: String) -> void
SaveManager.is_scroll_collected(scroll_id: String) -> bool
```

### StoryScroll Entity (`scenes/world/entities/StoryScroll.gd/.tscn`)

A `Node3D` that:
1. Builds a gold cylinder mesh + soft OmniLight3D glow in `_ready()`
2. `setup(scroll_id, player)` — auto-frees if already collected
3. `_process()` — tracks proximity (`_near_player` flag) for E-key prompt
4. `interact()` — marks collected, emits `GameBus.story_scroll_collected`, plays `scroll_pickup` SFX, calls `AudioManager.play_narration(scroll_id)`, then `queue_free()`

#### Named map placement

7 named-map scrolls are declared with `SCROLL x z scroll_id` directives in `.txt` map files:

| Scroll ID | Map | Position |
|---|---|---|
| `scroll_larik_origins` | madrian | (8, 13) |
| `scroll_martarquas_first_war` | maykalene | (52, 55) |
| `scroll_maiteln_order` | farsyth_mansion | (35, 40) |
| `scroll_prophecy_text` | farsyth_mansion | (63, 40) |
| `scroll_farsyth_lineage` | blancogov | (42, 50) |
| `scroll_blancogov_founding` | blancogov | (58, 50) |
| `scroll_king_eldar_coronation` | blancogov_temple | (45, 50) |

`WorldMap.load_from_string()` parses `SCROLL` directives into `world_map.scrolls: Array[Dictionary]`. `WorldScene._spawn_named_map_scrolls()` iterates this array and instantiates `StoryScroll` nodes after the named-map chunks are built.

#### Infinite world placement

`InfiniteWorldGen.get_chunk_scroll_id(cx, cz, world_seed)` returns `"scroll_martarquas_survivors"` for approximately 1 in 200 chunks (controlled by `SCROLL_CHUNK_RARITY = 200`), using the same `_chunk_seed` hash as enemy/chest generation. `ChunkRenderer._spawn_entities()` handles instantiation, tile GRASS check, and `is_scroll_collected` guard.

### Narration Audio Channel (`autoloads/AudioManager.gd`)

A dedicated `_narration_player: AudioStreamPlayer` (separate from the 8-slot SFX pool) plays long-form narration audio:

```gdscript
AudioManager.play_narration(scroll_id: String) -> void  # no-op if file absent
AudioManager.stop_narration() -> void
AudioManager.is_narration_playing() -> bool
AudioManager.set_narration_suppressed(suppressed: bool) -> void
```

`AudioManager` connects to `GameBus.dialogue_state_changed` in `_ready()`. When `WorldScene._show_dialogue()` fires (NPC talking), narration is suppressed and stopped. When the dialogue timer expires, suppression is lifted.

### Journal UI (`scenes/ui/JournalScene.gd/.tscn`)

A full-screen `Control` overlay opened by J key or the "Journal" HUD button:

- Left panel: scrollable list of collected scroll titles; "No lore scrolls found yet." when empty
- Right panel: title label + `RichTextLabel` lore text + "Replay Narration" button
- Header: "Journal — N / 8 Scrolls"
- Closes on ESC or X button, emits `closed` signal (SceneManager lifecycle)

`SceneManager` manages the JOURNAL state — same pattern as INVENTORY and SHOP overlays.

### HUD Toast

`WorldScene` connects `GameBus.story_scroll_collected` and calls `_show_tip("Lore scroll found: [title]")` (yellow tip label, 5 seconds). After showing the tip, it checks `collected_scrolls.size() >= SCROLL_COUNT` and emits `GameBus.all_scrolls_collected` if true.

---

## Integrations with Other Features

| System | Integration |
|---|---|
| `SaveManager` | `collected_scrolls` field; `mark_scroll_collected` / `is_scroll_collected` API |
| `GameBus` | `story_scroll_collected`, `all_scrolls_collected`, `journal_requested`, `dialogue_state_changed` |
| `WorldMap` | `SCROLL` directive; `scrolls: Array[Dictionary]` field; `find_nearby_scroll()` |
| `WorldScene` | Spawns named-map scrolls; wires scroll interaction; shows pickup toast |
| `ChunkRenderer` | Spawns infinite-world scroll in `_spawn_entities()` |
| `InfiniteWorldGen` | `get_chunk_scroll_id()` — seed-deterministic placement |
| `AudioManager` | Dedicated narration channel; suppressed by NPC dialogue |
| `SceneManager` | JOURNAL state; JournalScene overlay lifecycle |

---

## Asset Requirements

| Asset | Path | Notes |
|---|---|---|
| `ScrollRegistry.gd` | `autoloads/ScrollRegistry.gd` | Autoload; registered in `project.godot` |
| `StoryScroll.gd` | `scenes/world/entities/StoryScroll.gd` | Entity script |
| `StoryScroll.tscn` | `scenes/world/entities/StoryScroll.tscn` | Scene (uid `uid://dxenhuluro19`) |
| `JournalScene.gd` | `scenes/ui/JournalScene.gd` | UI overlay script |
| `JournalScene.tscn` | `scenes/ui/JournalScene.tscn` | Scene (uid `uid://t1ahgm0fg74z`) |
| Narration audio | `assets/audio/narration/<scroll_id>.ogg` | Optional — graceful no-op if absent |
| Scroll pickup SFX | `assets/audio/sfx/scroll_pickup.wav` | Optional — graceful no-op if absent |
