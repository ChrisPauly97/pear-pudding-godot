## Which stitched story town the player is walking through (GID-138).
##
## The outdoor towns live inside the overworld (see RealmLayout), so "entering
## Maykalene" is no longer a map load — it is the player's tile crossing into the
## town's rectangle. This module notices that crossing and runs what a named-map
## load used to: the HUD place name and music, the entry story flags, the town's
## rival and siege spawns. `WorldScene.current_town` holds the result (other
## modules read it through `WorldScene.story_place()`).
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _PlaceNames = preload("res://game_logic/PlaceNames.gd")
const _WorldMap = preload("res://game_logic/world/WorldMap.gd")
const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")

var _world: _WorldScene = null
var _last_tile := Vector2i(1 << 30, 1 << 30)

## Per-frame (overworld only): cheap until the player changes tile.
func tick() -> void:
	if _world._player == null:
		return
	var tile := Vector2i(int(floor(_world._player.position.x / IsoConst.TILE_SIZE)),
			int(floor(_world._player.position.z / IsoConst.TILE_SIZE)))
	if tile == _last_tile:
		return
	_last_tile = tile
	var town: String = RealmLayout.town_at_tile(tile.x, tile.y)
	if town != _world.current_town:
		_set_town(town)

## Applies the entry/exit effects for moving from the current town to `town`
## ("" = the wilds). Also run once on load so a save inside a town is "in" it.
func _set_town(town: String) -> void:
	var prev: String = _world.current_town
	_world.current_town = town
	var sm := SceneManager.save_manager
	if prev == "madrian" and town == "" and sm.get_story_flag("story_intro_complete"):
		sm.set_story_flag("chapter1_left_madrian")  # the camp appears via story_flag_set
	if town == "":
		if _world._current_biome >= 0:
			_world._on_player_chunk_changed(Vector2i.ZERO, _world._current_biome)
		return
	_world._map_label.text = _PlaceNames.title(town)
	AudioManager.play_music(_world.town_siege.music_for(town, town_music(town)))
	if prev == "" and _world._world_hud != null:
		GameBus.hud_message_requested.emit(_PlaceNames.title(town))
	_world.hero_health.full_heal()  # a town's hearths and healers (TID-543)
	_world.story_cast.spawn_named_map_rivals()
	_world.town_siege.on_map_entered(town)
	if town == "blancogov":
		sm.set_story_flag("chapter1_reached_blancogov")
	elif town == "larik":
		sm.set_story_flag("chapter2_reached_larik")

func town_music(town: String) -> String:
	var wm: _WorldMap = RealmLayout.town_map(town)
	var track: String = wm.music_track if wm != null else ""
	return track if track != "" else _WorldScene._TOWN_MUSIC_DEFAULT

## World position of `town`'s siege gate, moved into the overworld when the
## town is stitched there (SiegeDefs stores town-local positions).
func siege_gate(town: String) -> Vector3:
	var gate: Vector3 = _SiegeDefs.TOWN_GATES.get(town, Vector3.ZERO)
	if _world._is_infinite and RealmLayout.is_stitched(town):
		var shift: Vector2 = RealmLayout.world_shift(town)
		gate += Vector3(shift.x, 0.0, shift.y)
	return gate
