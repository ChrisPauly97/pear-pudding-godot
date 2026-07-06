extends Node

## MapRegistry — the single source of truth for named map data.
##
## Replaces BundledMaps.gd. The six const preloads guarantee the .tres files
## are tracked as resource dependencies and included in the Android APK/PCK by
## Godot's export system — no bundling script required.
##
## Usage:
##   var data := MapRegistry.get_map("main")   # returns Resource (cast to MapData)
##   if data == null: # map not found
##       pass

# ---------------------------------------------------------------------------
# Bundled maps — preloaded at compile time so they ship with every export.
# Add new built-in maps here AND to _BUNDLED below.
# ---------------------------------------------------------------------------

const _BLANCOGOV        := preload("res://assets/maps/blancogov.tres")
const _BLANCOGOV_TEMPLE := preload("res://assets/maps/blancogov_temple.tres")
const _FARSYTH_MANSION  := preload("res://assets/maps/farsyth_mansion.tres")
const _GUILDHALL        := preload("res://assets/maps/guildhall.tres")
const _LARIK            := preload("res://assets/maps/larik.tres")
const _MADRIAN          := preload("res://assets/maps/madrian.tres")
const _MAIN             := preload("res://assets/maps/main.tres")
const _MARSAX_HOLD      := preload("res://assets/maps/marsax_hold.tres")
const _MAYKALENE        := preload("res://assets/maps/maykalene.tres")
const _PLAYER_HOME      := preload("res://assets/maps/player_home.tres")

const _BUNDLED: Dictionary = {
	"blancogov":        _BLANCOGOV,
	"blancogov_temple": _BLANCOGOV_TEMPLE,
	"farsyth_mansion":  _FARSYTH_MANSION,
	"guildhall":        _GUILDHALL,
	"larik":            _LARIK,
	"madrian":          _MADRIAN,
	"main":             _MAIN,
	"marsax_hold":      _MARSAX_HOLD,
	"maykalene":        _MAYKALENE,
	"player_home":      _PLAYER_HOME,
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns the MapData resource for map_name, or null if not found.
## Cast the result at the call site: `var d := MapRegistry.get_map(n) as MapData`
func get_map(map_name: String) -> Resource:
	# 1. Bundled maps — always available on all platforms.
	if _BUNDLED.has(map_name):
		return _BUNDLED[map_name] as Resource

	# 2. User maps saved as .tres (editor saves, procedural dungeons).
	var tres_path := "user://maps/%s.tres" % map_name
	if ResourceLoader.exists(tres_path):
		return ResourceLoader.load(tres_path)

	# 3. Legacy .txt files in user:// (backwards compatibility for old editor saves).
	#    Pass p_skip_load=true to avoid re-entering MapRegistry from WorldMap._init().
	#    Use load() (not preload) to avoid a circular compile-time dependency.
	var txt_path := "user://maps/%s.txt" % map_name
	if FileAccess.file_exists(txt_path):
		var _WorldMap: GDScript = load("res://game_logic/world/WorldMap.gd") as GDScript
		var wm: Object = _WorldMap.new(map_name, true)
		wm.call("load_from_file", txt_path)
		return wm.call("to_map_data", map_name) as Resource

	return null

## Returns names of all known maps (bundled + any saved in user://maps/).
func list_map_names() -> Array[String]:
	var result: Array[String] = []
	var seen: Dictionary = {}

	for key: Variant in _BUNDLED.keys():
		var n: String = str(key)
		result.append(n)
		seen[n] = true

	var da := DirAccess.open("user://maps/")
	if da:
		da.list_dir_begin()
		var fname := da.get_next()
		while fname != "":
			if fname.ends_with(".tres") or fname.ends_with(".txt"):
				var n := fname.get_basename()
				if not seen.has(n):
					result.append(n)
					seen[n] = true
			fname = da.get_next()

	return result
