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

const _StoryQuests = preload("res://game_logic/quests/StoryQuests.gd")
const _ObjectiveTracker = preload("res://game_logic/ObjectiveTracker.gd")
const _RealmLayout = preload("res://game_logic/world/RealmLayout.gd")
const _BountyGen = preload("res://game_logic/BountyGen.gd")

const STORY_ID: String = "story"
const TREASURE_ID: String = "treasure"
const BOUNTY_PREFIX: String = "bounty:"

## Marker colour per quest kind (compass dots, minimap / realm-map pins).
const KIND_COLORS: Dictionary = {
	"story": Color(1.0, 0.82, 0.15),
	"treasure": Color(1.0, 0.60, 0.15),
	"bounty": Color(0.85, 0.55, 1.0),
}

static var _board_targets: Array[Dictionary] = []


## All active quests, story first.
static func active_quests(flags: Dictionary, treasure: Dictionary,
		bounties: Array) -> Array[Dictionary]:
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
	return out

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
			_board_targets.append({"map": "main",
				"tx": int(floor(float(npc.get("x", 0.0)) / IsoConst.TILE_SIZE)),
				"tz": int(floor(float(npc.get("z", 0.0)) / IsoConst.TILE_SIZE))})
	var out: Array[Dictionary] = []
	out.assign(_board_targets)
	return out

## Overhead mark for an NPC (GID-140), WoW-style: "!" = go here / work waiting,
## "?" = hand something in. `npc` is its spawn dict ({x, z, npc_type});
## `story_tile` the story step's tile on this map (or null). Returns
## {"text", "kind"} or {} for no mark.
static func npc_mark(npc: Dictionary, story_tile: Variant, bounty_turn_in: bool,
		bounty_offers: bool) -> Dictionary:
	if str(npc.get("npc_type", "")) == "bounty_board":
		if bounty_turn_in:
			return {"text": "?", "kind": "bounty"}
		if bounty_offers:
			return {"text": "!", "kind": "bounty"}
		return {}
	if story_tile is Vector2i:
		var st: Vector2i = story_tile
		var tx: int = int(floor(float(npc.get("x", 0.0)) / IsoConst.TILE_SIZE))
		var tz: int = int(floor(float(npc.get("z", 0.0)) / IsoConst.TILE_SIZE))
		if absi(tx - st.x) <= 1 and absi(tz - st.y) <= 1:
			return {"text": "!", "kind": "story"}
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
