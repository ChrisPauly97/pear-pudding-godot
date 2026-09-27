## Quest wayfinding in the world (GID-139): the cached quest list and tracked
## quest the compass, minimap and realm map poll, the in-world objective beacon,
## the "New objective" tip, and the overworld realm map (M).
##
## QuestLog (game_logic) builds the quests from save data; this module owns the
## per-frame side. Created by `WorldScene._ensure_world_modules()` as
## `quest_tracker`.
extends Node

const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _QuestLog = preload("res://game_logic/quests/QuestLog.gd")
const _ObjectiveBeacon = preload("res://scenes/world/entities/ObjectiveBeacon.gd")
const _RealmMapOverlay = preload("res://scenes/ui/RealmMapOverlay.gd")

## How often the cached quest list is re-read (ms). The compass and minimap
## poll every frame; a forced refresh (story flag, tracking change) is immediate.
const REFRESH_MS: int = 250

var _world: _WorldScene = null
var _quests: Array[Dictionary] = []
var _tracked: Dictionary = {}
var _read_ms: int = -REFRESH_MS
# One beacon at most, on the tracked quest's nearest target.
var _beacon: _ObjectiveBeacon = null
# Story step label last announced with a "New objective" tip.
var _announced_step: String = ""
var _realm_overlay: _RealmMapOverlay = null


## Every active quest (QuestLog), story first.
func active_quests() -> Array[Dictionary]:
	refresh(false)
	return _quests

## The quest the compass chevron, beacon and minimap pin follow.
func tracked_quest() -> Dictionary:
	refresh(false)
	return _tracked

## World position of the tracked quest's nearest target on this map, or null.
func tracked_quest_pos() -> Variant:
	return quest_pos(tracked_quest())

func quest_pos(quest: Dictionary) -> Variant:
	if quest.is_empty() or _world._player == null:
		return null
	return _QuestLog.world_pos(quest, _world.map_name, _world._player.position)

## Re-reads the quest list when stale (or `force`d) and moves the beacon along
## with it — a claimed bounty or a nearer board moves the target without any
## story flag changing.
func refresh(force: bool) -> void:
	var now: int = Time.get_ticks_msec()
	if not force and now - _read_ms < REFRESH_MS:
		return
	_read_ms = now
	var sm := SceneManager.save_manager
	_quests = sm.active_quests()
	_tracked = _QuestLog.tracked(_quests, sm.tracked_quest)
	_place_beacon()

## Map load: plant the beacon and take the current story step as already seen.
func on_map_ready() -> void:
	refresh(true)
	_announced_step = _story_step_label()

## Story flag changed (or the world came back from a battle).
func on_story_changed() -> void:
	refresh(true)
	announce_story_step()

## The compass ribbon only gives a bearing; standing in the right street still
## left the player guessing which hut or NPC was the target, so the tracked
## quest also gets a beacon on the thing itself.
func _place_beacon() -> void:
	if NetworkManager.is_dedicated_server():
		return
	var raw: Variant = tracked_quest_pos()
	if raw == null:
		if is_instance_valid(_beacon):
			_beacon.queue_free()
		_beacon = null
		return
	var pos: Vector3 = raw as Vector3
	if not is_instance_valid(_beacon):
		_beacon = _ObjectiveBeacon.new()
		_beacon.name = "ObjectiveBeacon"
		_world.add_child(_beacon)
		_beacon.setup(_world._player)
	var at := Vector3(pos.x, _world.get_terrain_height(pos.x, pos.z), pos.z)
	if not _beacon.position.is_equal_approx(at):
		_beacon.position = at

func _story_step_label() -> String:
	return str(_QuestLog.story_quest(SceneManager.save_manager.story_flags).get("label", ""))

## Tells the player when the story hands them a new objective. Uses the tip line,
## not the dialogue line, so the NPC's last words stay readable. When the step
## moved during a battle (world detached) it waits for the re-attach.
func announce_story_step() -> void:
	if not _world.is_inside_tree() or NetworkManager.is_dedicated_server():
		return
	var label: String = _story_step_label()
	if label == _announced_step:
		return
	_announced_step = label
	_world._show_tip("New objective: " + label)

## The overworld has no tile grid to show, so M opens the realm map.
func toggle_realm_map() -> void:
	if is_instance_valid(_realm_overlay):
		_realm_overlay.queue_free()
		_realm_overlay = null
		return
	_realm_overlay = _RealmMapOverlay.new()
	_world.add_child(_realm_overlay)
	_realm_overlay.setup(_world._player, _world.map_name, active_quests(), tracked_quest())
	_realm_overlay.closed.connect(func() -> void: _realm_overlay = null)

func is_realm_map_open() -> bool:
	return is_instance_valid(_realm_overlay)
