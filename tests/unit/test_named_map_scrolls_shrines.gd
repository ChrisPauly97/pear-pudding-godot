## Regression coverage for BID-059: a `.tres` map file's `scrolls`/`shrines`/
## `music_track` properties silently attach to the wrong sub-resource (and get
## dropped on load with no error) if they're written before the `[resource]`
## header instead of inside it — see docs/agent/named-maps-and-dungeons.md
## "Hand-editing/generating .tres map files" for the full explanation. This
## bug shipped in all 5 Chapter 1 story maps; a clean headless import never
## catches it (the file is syntactically valid, just structurally wrong).
extends "res://tests/framework/test_case.gd"

const WorldMapScript = preload("res://game_logic/world/WorldMap.gd")

## Every map here is known (from docs/human/story.md) to author at least one
## scroll and one puzzle shrine. If any of these regress to 0, the dangling-
## property bug (or something equivalent) has reappeared.
const _MAPS_WITH_AUTHORED_CONTENT: Array[String] = [
	"madrian", "maykalene", "farsyth_mansion", "blancogov", "blancogov_temple",
]

func test_story_maps_load_at_least_one_scroll() -> void:
	for map_name: String in _MAPS_WITH_AUTHORED_CONTENT:
		var wm: RefCounted = WorldMapScript.new(map_name)
		assert_gt(wm.scrolls.size(), 0, "%s should load at least one authored scroll" % map_name)

func test_story_maps_load_at_least_one_shrine() -> void:
	for map_name: String in _MAPS_WITH_AUTHORED_CONTENT:
		var wm: RefCounted = WorldMapScript.new(map_name)
		assert_gt(wm.shrines.size(), 0, "%s should load at least one authored puzzle shrine" % map_name)

func test_story_maps_load_non_empty_music_track() -> void:
	for map_name: String in _MAPS_WITH_AUTHORED_CONTENT:
		var res: Resource = load("res://assets/maps/%s.tres" % map_name)
		var track: String = str(res.get("music_track"))
		assert_true(track.length() > 0, "%s should load a non-empty music_track" % map_name)
