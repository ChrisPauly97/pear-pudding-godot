## QuestLog — every quest the player has going right now, in one shape (GID-140).
##
## Gathers the main story (StoryQuests), an assembled treasure map and accepted
## bounty contracts into a list of quest dicts, so the compass, beacon, minimap,
## realm map and Journal all read the same thing:
##
##   {id, kind, title, label, summary, giver, progress, targets}
##
## `targets` is a list of {map, tx, tz[, site]} places (see ObjectiveTracker for
## how one resolves on a given map); a quest with several (a bounty board in each
## town) points at the nearest. A quest with no targets has no marker — the
## Journal still lists it.
##
## Pure static logic over save data passed in — no autoloads.
extends RefCounted

const IsoConst = preload("res://autoloads/IsoConst.gd")  # usable before autoloads register (-s runs)
const _StoryQuests = preload("res://game_logic/quests/StoryQuests.gd")
const _ObjectiveTracker = preload("res://game_logic/ObjectiveTracker.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _BountyGen = preload("res://game_logic/BountyGen.gd")
const _SideQuests = preload("res://game_logic/quests/SideQuests.gd")
const _UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")

const STORY_ID: String = "story"
const TREASURE_ID: String = "treasure"
const BOUNTY_PREFIX: String = "bounty:"
const SIDE_PREFIX: String = "side:"
const TRAINING_ID: String = "training"

## Marker colour per quest kind (compass dots, minimap / realm-map pins).
const KIND_COLORS: Dictionary = {
	"story": Color(1.0, 0.82, 0.15),
	"treasure": Color(1.0, 0.60, 0.15),
	"bounty": Color(0.85, 0.55, 1.0),
	"side": Color(1.0, 0.95, 0.45),
	"side_upcoming": Color(0.6, 0.6, 0.6),
	"training": Color(0.45, 0.8, 1.0),
}

static var _board_targets: Array[Dictionary] = []


## All active quests, story first. `side` is SaveQuests.log_entries():
## [{quest, progress, ready}]; `training` the UnlockLadder ids waiting at a trainer.
static func active_quests(flags: Dictionary, treasure: Dictionary,
		bounties: Array, side: Array = [], training: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = [story_quest(flags)]
	if not treasure.is_empty() and not bool(treasure.get("completed", false)):
		out.append({
			"id": TREASURE_ID, "kind": "treasure", "title": "Buried Treasure",
			"label": "Dig at the treasure site", "giver": "",
			"summary": "Three map fragments made a treasure map. The X marks a dig site out in the wilds.",
			"progress": "",
			"targets": [{"map": "main", "tx": int(treasure.get("site_x", 0)),
				"tz": int(treasure.get("site_z", 0))}],
		})
	for raw: Variant in bounties:
		if not raw is Dictionary:
			continue
		var b: Dictionary = raw
		if bool(b.get("claimed", false)):
			continue
		var count: int = int(b.get("count", 1))
		var progress: int = mini(int(b.get("progress", 0)), count)
		var done: bool = bool(b.get("completed", false)) or progress >= count
		var desc: String = _BountyGen.describe(str(b.get("type", "")), str(b.get("target", "")), count)
		var targets: Array[Dictionary] = []
		if done:
			targets = bounty_board_targets()
		out.append({
			"id": BOUNTY_PREFIX + str(b.get("id", "")), "kind": "bounty", "title": "Contract: " + desc,
			"label": "Claim your bounty reward" if done else desc, "giver": "Bounty board",
			"summary": ("Contract fulfilled. Any bounty board will pay out." if done
				else "A posted contract. Progress counts anywhere in the realm."),
			"progress": "%d / %d" % [progress, count],
			"targets": targets,
		})
	if not training.is_empty():
		out.append(training_quest(training))
	for raw: Variant in side:
		if raw is Dictionary:
			out.append(side_quest(raw as Dictionary))
	return out

## GID-141 / TID-590: training that levelling up made available. Points at the
## trainer(s); Maiteln (a follower, no fixed spot) gets no marker.
static func training_quest(pending: Array) -> Dictionary:
	var first: String = str(pending[0])
	var titles: Array[String] = []
	var targets: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw: Variant in pending:
		var id: String = str(raw)
		var trainer: String = _UnlockLadder.trainer_for(id)
		titles.append("%s (%s, %d gold)" % [str(_UnlockLadder.def(id).get("title", id)),
				_UnlockLadder.trainer_name(trainer), _UnlockLadder.cost(id)])
		if seen.has(trainer):
			continue
		seen[trainer] = true
		var t: Dictionary = npc_target(str(_UnlockLadder.TRAINER_NPCS.get(trainer, "")))
		if not t.is_empty():
			targets.append(t)
	var ft: String = _UnlockLadder.trainer_for(first)
	return {
		"id": TRAINING_ID, "kind": "training", "title": "Training Available",
		"label": "Learn %s from %s" % [str(_UnlockLadder.def(first).get("title", first)),
			("Maiteln" if ft == "maiteln" else "the " + _UnlockLadder.trainer_name(ft))],
		"giver": _UnlockLadder.trainer_name(ft),
		"summary": "You've grown strong enough to learn more. Waiting for you: " + ", ".join(titles) + ".",
		"progress": "", "targets": targets,
	}

## One active side quest (SideQuests) as a quest dict. It points at its first
## unfinished objective's place, or at the turn-in NPC once every objective is met.
static func side_quest(entry: Dictionary) -> Dictionary:
	var q: Dictionary = entry.get("quest", {})
	var progress: Array = entry.get("progress", [])
	var ready: bool = bool(entry.get("ready", false))
	var label: String = ""
	var targets: Array[Dictionary] = []
	var objs: Array[Dictionary] = _SideQuests.objectives(q)
	if ready:
		var npc_id: String = _SideQuests.turn_in_npc(q)
		label = "Return to %s" % _SideQuests.turn_in_name(q)
		var t: Dictionary = npc_target(npc_id)
		if not t.is_empty():
			targets.append(t)
	else:
		for i: int in range(objs.size()):
			var have: int = int(progress[i]) if i < progress.size() else 0
			if have >= int(objs[i].get("count", 1)):
				continue
			label = str(objs[i].get("label", ""))
			if objs[i].has("map"):
				targets.append(objs[i])
			elif str(objs[i].get("type", "")) == "talk":
				var nt: Dictionary = npc_target(str(objs[i].get("target", "")))
				if not nt.is_empty():
					targets.append(nt)
			break
	return {
		"id": SIDE_PREFIX + str(q.get("id", "")), "kind": "side", "title": str(q.get("title", "")),
		"label": label, "giver": str(q.get("giver_name", "")), "summary": str(q.get("summary", "")),
		"progress": _SideQuests.progress_text(q, progress), "targets": targets,
	}

## Overworld tile target of the stitched-town NPC with entity id `npc_id`, or {}.
## Waypoint target {map, tx, tz} for an overworld entity dict.
static func _overworld_target(e: Dictionary) -> Dictionary:
	var t := IsoConst.entity_tile(e)
	return {"map": "main", "tx": t.x, "tz": t.y}

static func npc_target(npc_id: String) -> Dictionary:
	for npc: Dictionary in _RealmLayout.entities("npcs"):
		if str(npc.get("id", "")) == npc_id:
			return _overworld_target(npc)
	return {}

## The main-story entry. Past the last written step it becomes a standing
## "between chapters" quest pointing at the bounty boards, so the tracker is
## never blank.
static func story_quest(flags: Dictionary) -> Dictionary:
	var step: Dictionary = _StoryQuests.current_step(flags)
	if step.is_empty():
		var boards: Array[Dictionary] = bounty_board_targets()
		return {
			"id": STORY_ID, "kind": "story", "title": "Between Chapters",
			"label": "Take a contract at a bounty board", "giver": "Maiteln",
			"summary": ("The tribe marches on the lords one by one, and the traitor sits on the King's own "
				+ "council. Until the next road opens, grow strong: take contracts, climb the Endless Spire "
				+ "and cleanse the blight."),
			"progress": "", "targets": boards,
		}
	var targets: Array[Dictionary] = [step]
	return {
		"id": STORY_ID, "kind": "story", "title": _StoryQuests.chapter_title(int(step["chapter"])),
		"label": str(step["label"]), "giver": str(step.get("giver", "")),
		"summary": str(step.get("summary", "")), "progress": "", "targets": targets,
	}

## The quest with `tracked_id`, else the story quest (a tracked bounty that was
## claimed, or a dug-up treasure, falls back to the story).
static func tracked(quests: Array[Dictionary], tracked_id: String) -> Dictionary:
	for q: Dictionary in quests:
		if str(q.get("id", "")) == tracked_id:
			return q
	for q: Dictionary in quests:
		if str(q.get("id", "")) == STORY_ID:
			return q
	return {}

## World position (tile centre) of the quest's nearest target on `map_name`, or
## null when none of its targets is on (or reachable by a door from) this map.
static func world_pos(quest: Dictionary, map_name: String, from: Vector3) -> Variant:
	var best: Variant = null
	var best_d: float = INF
	var targets: Array = quest.get("targets", [])
	for raw: Variant in targets:
		if not raw is Dictionary:
			continue
		var p: Variant = _ObjectiveTracker.target_world_pos(raw as Dictionary, map_name)
		if p == null:
			continue
		var pos: Vector3 = p as Vector3
		var d: float = Vector2(pos.x - from.x, pos.z - from.z).length_squared()
		if d < best_d:
			best_d = d
			best = pos
	return best

## True when the quest has somewhere to point at (in the overworld).
static func has_target(quest: Dictionary) -> bool:
	return world_pos(quest, "main", Vector3.ZERO) != null

## Every stitched town's bounty board, as overworld tile targets.
static func bounty_board_targets() -> Array[Dictionary]:
	if _board_targets.is_empty():
		for npc: Dictionary in _RealmLayout.entities("npcs"):
			if str(npc.get("npc_type", "")) != "bounty_board":
				continue
			_board_targets.append(_overworld_target(npc))
	var out: Array[Dictionary] = []
	out.assign(_board_targets)
	return out

## Overhead mark for an NPC (GID-140), WoW-style: "!" = go here / work waiting,
## "?" = hand something in. `npc` is its spawn dict ({x, z, npc_type});
## `story_tile` the story step's tile on this map (or null). Returns
## {"text", "kind"} or {} for no mark.
##
## `side` (TID-534) is the NPC's side-quest state: "turn_in" (a quest of theirs is
## ready → yellow "?"), "offer" (yellow "!"), "upcoming" (grey "!" — offered once
## you level up) or "". A hand-in outranks the story mark; an offer does not.
static func npc_mark(npc: Dictionary, story_tile: Variant, bounty_turn_in: bool,
		bounty_offers: bool, side: String = "", training: bool = false) -> Dictionary:
	if side == "turn_in":
		return {"text": "?", "kind": "side"}
	if str(npc.get("npc_type", "")) == "bounty_board":
		if bounty_turn_in:
			return {"text": "?", "kind": "bounty"}
		if bounty_offers:
			return {"text": "!", "kind": "bounty"}
		return {}
	if story_tile is Vector2i:
		var st: Vector2i = story_tile
		var t := IsoConst.entity_tile(npc)
		if absi(t.x - st.x) <= 1 and absi(t.y - st.y) <= 1:
			return {"text": "!", "kind": "story"}
	if training:
		return {"text": "!", "kind": "training"}
	if side == "offer":
		return {"text": "!", "kind": "side"}
	if side == "upcoming":
		return {"text": "!", "kind": "side_upcoming"}
	return {}

## True when some accepted bounty is fulfilled but not yet claimed.
static func has_bounty_turn_in(bounties: Array) -> bool:
	for raw: Variant in bounties:
		if raw is Dictionary:
			var b: Dictionary = raw
			if not bool(b.get("claimed", false)) and (bool(b.get("completed", false))
					or int(b.get("progress", 0)) >= int(b.get("count", 1))):
				return true
	return false

static func kind_color(kind: String) -> Color:
	var c: Color = KIND_COLORS.get(kind, Color.WHITE)
	return c
