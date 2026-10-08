## Quest wayfinding in the world (GID-140): the cached quest list and tracked
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
const _ObjectiveTracker = preload("res://game_logic/ObjectiveTracker.gd")
const _StoryQuests = preload("res://game_logic/quests/StoryQuests.gd")
const _SideQuests = preload("res://game_logic/quests/SideQuests.gd")
const _UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")
const _NpcInteractions = preload("res://scenes/world/modules/NpcInteractions.gd")

## First-time guide (TutorialRegistry id) opened when a ladder entry is learned.
const _LEARNED_GUIDES: Dictionary = {
	"feat_spells": "tap_to_cast", "feat_minions": "soulbinding", "feat_skills": "skill_tree",
	"feat_night_hunts": "night_hunts", "feat_dig": "cantrips", "feat_phase": "cantrips",
	"feat_spire": "spire_intro",
}
## HUD action to pulse after learning (the new button to press).
const _LEARNED_BUTTONS: Dictionary = {
	"feat_dig": "cantrip_skeleton_dig", "feat_phase": "cantrip_ghost_phase", "feat_mount": "mount",
}

const _MARK_NAME: String = "QuestMark"
## Most bounties a player can hold at once (SaveBounties.accept_bounty).
const _MAX_BOUNTIES: int = 3

## How often the cached quest list is re-read (ms). The compass and minimap
## poll every frame; a forced refresh (story flag, tracking change) is immediate.
const REFRESH_MS: int = 250

var _world: _WorldScene = null
var _quests: Array[Dictionary] = []
var _tracked: Dictionary = {}
var _read_ms: int = -REFRESH_MS
## quest id|map → world pos (or null), dropped at each re-read: the minimap pins,
## compass and beacon ask every frame (GID-164 / TID-677).
var _pos_cache: Dictionary = {}
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
	var key: String = str(quest.get("id", "")) + "|" + _world.map_name
	if _pos_cache.has(key):
		return _pos_cache[key]
	var pos: Variant = _QuestLog.world_pos(quest, _world.map_name, _world._player.position)
	_pos_cache[key] = pos
	return pos

## Re-reads the quest list when stale (or `force`d) and moves the beacon along
## with it — a claimed bounty or a nearer board moves the target without any
## story flag changing.
func refresh(force: bool) -> void:
	var now: int = Time.get_ticks_msec()
	if not force and now - _read_ms < REFRESH_MS:
		return
	_read_ms = now
	_pos_cache.clear()
	var sm := SceneManager.save_manager
	_quests = sm.active_quests()
	_tracked = _QuestLog.tracked(_quests, sm.tracked_quest)
	_place_beacon()
	_refresh_npc_marks()

## GID-141: a level-up made training available — say who teaches it and point
## the tracker at them.
func on_training_available(ids: Array[String]) -> void:
	var parts: Array[String] = []
	for id: String in ids:
		parts.append("%s — see %s" % [str(_UnlockLadder.def(id).get("title", id)),
				_UnlockLadder.trainer_name(_UnlockLadder.trainer_for(id))])
	GameBus.hud_message_requested.emit("New training: " + "; ".join(parts))
	SceneManager.save_manager.set_tracked_quest(_QuestLog.TRAINING_ID)
	refresh(true)

## Learned at a trainer: confirm it and open the matching guide once.
func on_feature_learned(id: String) -> void:
	GameBus.hud_message_requested.emit("Learned: " + str(_UnlockLadder.def(id).get("title", id)))
	var guide: String = str(_LEARNED_GUIDES.get(id, ""))
	if guide != "":
		GameBus.tutorial_popup_requested.emit(guide)
	_world._world_hud.pulse_action(str(_LEARNED_BUTTONS.get(id, "")))
	refresh(true)

## A side quest's objectives are all met: say where to hand it in.
func on_side_quest_ready(quest_id: String) -> void:
	refresh(true)
	var q: Dictionary = _SideQuests.def(quest_id)
	if not q.is_empty():
		GameBus.hud_message_requested.emit("%s — done! Return to %s." % [str(q.get("title", "")),
				_SideQuests.turn_in_name(q)])

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

## "!" / "?" over NPCs (GID-140): the story step's NPC, and bounty boards with a
## contract to hand in ("?") or offers you have room for ("!"). Runs with every
## quest refresh; only touches a node when its mark changes.
func _refresh_npc_marks() -> void:
	if NetworkManager.is_dedicated_server():
		return
	var sm := SceneManager.save_manager
	var story_tile: Variant = null
	var step: Dictionary = _StoryQuests.current_step(sm.story_flags)
	if not step.is_empty():
		var placed: Dictionary = _ObjectiveTracker.place_on_map(step, _world.map_name)
		if not placed.is_empty():
			story_tile = Vector2i(int(placed["tx"]), int(placed["tz"]))
	var turn_in: bool = _QuestLog.has_bounty_turn_in(sm.active_bounties)
	var offers: bool = (sm.active_bounties.size() < _MAX_BOUNTIES
			and not sm.bounties.get_offered_bounties().is_empty())
	var side_states: Dictionary = sm.quests.npc_states()
	for nid: Variant in _world._npc_nodes:
		var node: Node3D = _world._valid_node3d(_world._npc_nodes[nid])
		if node == null:
			continue
		var data: Dictionary = _world._active_npc_data.get(nid, {})
		var trainer: String = _UnlockLadder.trainer_at(str(nid))
		var training: bool = trainer != "" and _NpcInteractions.trainer_has_pending(trainer)
		_set_mark(node, _QuestLog.npc_mark(data, story_tile, turn_in, offers,
				str(side_states.get(str(nid), "")), training))
	var maiteln: Node3D = _world._valid_node3d(_world._maiteln_node)
	if maiteln != null:
		_set_mark(maiteln, {"text": "!", "kind": "training"} if _NpcInteractions.trainer_has_pending("maiteln")
				else {})

## The "!" / "?" a quest giver wears, for the map views: {text, color}, or {} when
## the NPC has no mark. Reads the Label3D `_set_mark` keeps, so maps and world agree.
## Townsfolk indoors at night (hidden) keep theirs, at their house.
static func map_mark(node: Node3D) -> Dictionary:
	if not is_instance_valid(node):
		return {}
	var lbl: Label3D = node.get_node_or_null(_MARK_NAME) as Label3D
	if lbl == null or lbl.is_queued_for_deletion():
		return {}
	return {"text": lbl.text, "color": lbl.modulate}

## Every marked quest giver on this map: [{pos: Vector3, text, color}].
func npc_map_marks() -> Array[Dictionary]:
	refresh(false)
	var out: Array[Dictionary] = []
	var nodes: Array = _world._npc_nodes.values()
	nodes.append(_world._maiteln_node)
	for raw: Variant in nodes:
		var node: Node3D = _world._valid_node3d(raw)
		var mark: Dictionary = map_mark(node)
		if not mark.is_empty():
			mark["pos"] = node.position
			out.append(mark)
	return out

func _set_mark(node: Node3D, mark: Dictionary) -> void:
	var lbl: Label3D = node.get_node_or_null(_MARK_NAME) as Label3D
	if mark.is_empty():
		if lbl != null:
			lbl.queue_free()
		return
	var text: String = str(mark["text"])
	var col: Color = _QuestLog.kind_color(str(mark["kind"]))
	if lbl != null and lbl.text == text and lbl.modulate == col:
		return
	if lbl == null:
		lbl = Label3D.new()
		lbl.name = _MARK_NAME
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.font_size = 72
		lbl.outline_size = 18
		lbl.outline_modulate = Color(0.1, 0.07, 0.0)
		lbl.pixel_size = 0.02
		lbl.position = Vector3(0.0, _mark_height(node), 0.0)
		node.add_child(lbl)
	lbl.text = text
	lbl.modulate = col

## Above the NPC's name tag (its highest Label3D child) and clear of the
## objective beacon's bobbing arrow, which often marks the same NPC.
static func _mark_height(node: Node3D) -> float:
	var top: float = 1.9
	for c: Node in node.get_children():
		var l := c as Label3D
		if l != null and l.name != _MARK_NAME:
			top = maxf(top, l.position.y)
	return maxf(top + 0.7, _ObjectiveBeacon.ARROW_Y + _ObjectiveBeacon.BOB_AMPLITUDE + 0.8)

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
	_realm_overlay.setup(_world._player, _world.map_name, active_quests(), tracked_quest(), npc_map_marks())
	_realm_overlay.closed.connect(func() -> void: _realm_overlay = null)
	_realm_overlay.fast_travel_requested.connect(_world.named_props.open_fast_travel_panel)

func is_realm_map_open() -> bool:
	return is_instance_valid(_realm_overlay)


## GameBus wiring, called from WorldScene._wire_gamebus_signals in every mode (not
## CoopSession._setup_coop, which returns early outside a session).
func wire_signals() -> void:
	GameBus.quest_tracking_changed.connect(func(_id: String) -> void: refresh(true))
	# Side quests (TID-534): marks and tracker follow accept / progress / hand-in.
	GameBus.quest_accepted.connect(func(_id: String) -> void: refresh(true))
	GameBus.quest_progressed.connect(func(_id: String) -> void: refresh(true))
	GameBus.quest_ready.connect(on_side_quest_ready)
	GameBus.quest_turned_in.connect(func(_id: String) -> void: refresh(true))
	# GID-141 / TID-590: level-up training notices and learn confirmations.
	GameBus.training_available.connect(on_training_available)
	GameBus.feature_learned.connect(on_feature_learned)
