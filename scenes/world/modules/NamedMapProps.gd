## Authored props on named (non-infinite) maps: lore scrolls, puzzle shrines,
## waystones (plus the injected town waystone when the .tres has none), the
## injected mailbox, and the waystone fast-travel panel.
##
## The node and data tables (`_scroll_nodes`, `_shrine_nodes`, `_waystone_nodes`,
## `_active_waystone_data`, `_mailbox_nodes`, `_active_mailbox_data`) stay on
## WorldScene — the `_find_nearby_*` finders and the co-op modules read them.
extends Node

const WorldMap = preload("res://game_logic/world/WorldMap.gd")
const _MailboxScene = preload("res://scenes/world/entities/MailboxNPC.tscn")
const _PuzzleShrineScene = preload("res://scenes/world/entities/PuzzleShrine.tscn")
const _StoryScrollScene = preload("res://scenes/world/entities/StoryScroll.tscn")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _WaystoneScene = preload("res://scenes/world/entities/Waystone.tscn")

## Town maps that get a waystone injected near spawn when their .tres has none.
const NAMED_MAP_WAYSTONE_LABELS: Dictionary = {
	"main": "Main Outpost",
	"madrian": "Madrian",
	"maykalene": "Maykalene",
	"blancogov": "Blancogov",
	"farsyth_mansion": "Farsyth Mansion",
	"blancogov_temple": "Temple of Blancogov",
}
## Maps that get an injected mailbox (there is no MailboxData on the .tres maps).
const MAILBOX_MAPS: Array[String] = ["madrian", "maykalene", "blancogov", "player_home"]
## Tile offsets from the map spawn, tried in order, for the injected mailbox.
## The first walkable one clear of everything the map already placed wins — a
## fixed spawn+(5, 0) once stood the Madrian mailbox on Maiteln's tile (45, 36).
const MAILBOX_TILE_OFFSETS: Array[Vector2i] = [
	Vector2i(5, 0), Vector2i(5, -3), Vector2i(5, 3), Vector2i(2, -4),
	Vector2i(2, 4), Vector2i(-3, -3), Vector2i(-3, 3), Vector2i(-5, 0),
]
## How far the injected mailbox stays clear of an authored entity, in tiles.
const MAILBOX_CLEARANCE_TILES: float = 2.0
const _FAST_TRAVEL_BG := Color(0.05, 0.05, 0.10, 0.96)

var _world: Node = null
var _fast_travel_layer: CanvasLayer = null

## Spawns every prop on the current named map. Waystones go before the mailbox:
## its placement avoids them.
func spawn_all() -> void:
	if _world.world_map == null:
		return
	_spawn_scrolls()
	_spawn_shrines()
	_spawn_waystones()
	_spawn_mailbox()

## Instantiates `scene` on the terrain at (wx, wz), `lift` units up.
func _place(scene: PackedScene, wx: float, wz: float, lift: float) -> Node3D:
	var node := scene.instantiate() as Node3D
	_world._entity_root.add_child(node)
	node.position = Vector3(wx, _world.get_terrain_height(wx, wz) + lift, wz)
	return node

func _spawn_scrolls() -> void:
	for entry: Dictionary in _world.world_map.scrolls:
		var node: Node3D = _place(_StoryScrollScene, float(entry["x"]), float(entry["z"]), 0.1)
		node.setup(str(entry["scroll_id"]), _world._player)
		if not node.is_queued_for_deletion():   # setup frees an already-collected scroll
			_world._scroll_nodes.append(node)

func _spawn_shrines() -> void:
	for entry: Dictionary in _world.world_map.shrines:
		var node: Node3D = _place(_PuzzleShrineScene, float(entry["x"]), float(entry["z"]), 0.1)
		node.setup(str(entry["puzzle_id"]), _world._player)
		if not node.is_queued_for_deletion():
			_world._shrine_nodes.append(node)

func _spawn_waystones() -> void:
	var sm: Node = SceneManager.save_manager
	var entries: Array[Dictionary] = _world.world_map.waystones
	if entries.is_empty():
		entries = _injected_waystone()
	for entry: Dictionary in entries:
		var wid: String = str(entry.get("id", "map:%s" % _world.map_name))
		var w_dict: Dictionary = entry.duplicate()
		w_dict["active"] = sm.is_waystone_activated(wid)
		var node: Node3D = _place(_WaystoneScene, float(entry["x"]), float(entry["z"]), 0.75)
		node.init_from_data(w_dict)
		_world._waystone_nodes[wid] = node
		_world._active_waystone_data[wid] = w_dict

## A town map without authored waystones gets one three tiles east of spawn.
func _injected_waystone() -> Array[Dictionary]:
	var map_name: String = _world.map_name
	if not NAMED_MAP_WAYSTONE_LABELS.has(map_name):
		return []
	var wm: RefCounted = _world.world_map
	var tx: int = clampi(wm.player_spawn_x + 3 if wm.has_player_spawn() else 8, 1, WorldMap.MAP_WIDTH - 2)
	var tz: int = clampi(wm.player_spawn_z if wm.has_player_spawn() else 8, 1, WorldMap.MAP_HEIGHT - 2)
	return [{
		"id": "map:%s" % map_name,
		"x": float(tx) * WorldMap.TILE_SIZE,
		"z": float(tz) * WorldMap.TILE_SIZE,
		"label": str(NAMED_MAP_WAYSTONE_LABELS[map_name]),
	}]

func _spawn_mailbox() -> void:
	var map_name: String = _world.map_name
	if not MAILBOX_MAPS.has(map_name):
		return
	if map_name == "player_home" and not SceneManager.save_manager.home_owned:
		return
	# Waystones come from _active_waystone_data rather than world_map.waystones:
	# town maps get theirs injected, and they were spawned just before this.
	var tile: Vector2i = _world.world_map.pick_free_tile_near_spawn(
		MAILBOX_TILE_OFFSETS, MAILBOX_CLEARANCE_TILES, _world._active_waystone_data.values())
	var mid: String = "map:%s" % map_name
	var m_dict: Dictionary = {
		"id": mid,
		"x": float(tile.x) * WorldMap.TILE_SIZE,
		"z": float(tile.y) * WorldMap.TILE_SIZE,
	}
	var node: Node3D = _place(_MailboxScene, m_dict["x"], m_dict["z"], 0.55)
	node.init_from_data(m_dict)
	_world._mailbox_nodes[mid] = node
	_world._active_mailbox_data[mid] = m_dict

# ── Waystones & fast travel ──────────────────────────────────────────────────

func on_waystone_activated(waystone_id: String) -> void:
	var w_data: Dictionary = _world._active_waystone_data.get(waystone_id, {})
	SceneManager.show_toast("Waystone Activated", str(w_data.get("label", "Unknown")))

## "map:madrian" → "Madrian"; "world:3:-2" → "Waystone (3, -2)".
static func waystone_label(wid: String) -> String:
	if wid.begins_with("map:"):
		return wid.substr(4).capitalize().replace("_", " ")
	if wid.begins_with("world:"):
		var parts: PackedStringArray = wid.split(":")
		if parts.size() >= 3:
			return "Waystone (%s, %s)" % [parts[1], parts[2]]
	return wid

## Closes the fast-travel panel if open. Returns whether it was.
func close_fast_travel() -> bool:
	if not is_instance_valid(_fast_travel_layer):
		_fast_travel_layer = null
		return false
	_fast_travel_layer.queue_free()
	_fast_travel_layer = null
	return true

## One button per activated waystone; blocked inside dungeons. Esc closes it
## (WorldScene's pause handler asks close_fast_travel() first).
func open_fast_travel_panel() -> void:
	if is_instance_valid(_fast_travel_layer):
		return
	var vh: float = _world.get_viewport().get_visible_rect().size.y
	var modal: Dictionary = _world._build_modal(0.55, 0.62, _FAST_TRAVEL_BG, 0.018)
	var vbox: VBoxContainer = modal["vbox"]
	_fast_travel_layer = modal["layer"]
	var note_font: int = int(vh * 0.022)
	_UiUtil.make_label("Fast Travel", int(vh * 0.035), Color(0.40, 0.90, 1.00), HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var activated: Array[String] = SceneManager.save_manager.activated_waystones
	if activated.is_empty():
		_note("No waystones activated yet.\nFind and interact with a waystone pillar to unlock fast travel.",
			note_font, Color(0.6, 0.6, 0.6), vbox)
	elif SceneManager.current_map.begins_with("dungeon_"):
		_note("Fast travel is unavailable inside dungeons.", note_font, Color(1.0, 0.4, 0.4), vbox)
	else:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, vh * 0.62 * 0.62)
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(scroll)
		var list := _UiUtil.make_vbox(int(vh * 0.010), scroll)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for wid: String in activated:
			var travel := func() -> void:
				close_fast_travel()
				SceneManager.teleport_to_waystone(wid)
			var btn := _UiUtil.make_button(waystone_label(wid), Vector2(0, vh * 0.060), int(vh * 0.024), travel, list)
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var close_text: String = "Close" if OS.has_feature("android") else "Close  [Esc]"
	var close_btn := _UiUtil.make_button(close_text, Vector2(vh * 0.20, vh * 0.06), int(vh * 0.024),
		close_fast_travel, vbox)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func _note(text: String, font_size: int, tint: Color, parent: Node) -> void:
	var lbl := _UiUtil.make_label(text, font_size, tint, HORIZONTAL_ALIGNMENT_CENTER, parent)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
