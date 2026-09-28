## SideQuests — NPC-given quests with tracked objectives (GID-136 / TID-533).
##
## The story is StoryQuests (one ordered chain of flags); these are the WoW-style
## asks townspeople, trainers and rift keepers hand out. Pure static data + the
## matching rules, no autoloads, so tests and every UI read one table
## (SaveQuests owns the save state, QuestLog shows the active ones).
##
## Quest keys:
##   id        — stable id (saved)
##   title     — shown in the Journal / accept prompt
##   giver     — entity id of the NPC that offers it (stitched-town ids: named ids as
##               authored, generic npc_N become "madrian:npc_2")
##   giver_name— display name of the giver
##   turn_in   — entity id of the NPC that takes it back ("" = giver)
##   turn_in_name — display name of the turn-in NPC ("" = giver_name)
##   summary   — the ask, in the giver's voice
##   done_text — what the turn-in NPC says (hints at the next step: a trainer…)
##   objectives— [{type, target, count, label[, map, tx, tz, site]}]
##   prereqs   — quest ids that must be turned in first
##   min_level — level needed before the giver offers it
##   req_flag  — story flag needed before it is offered ("" = none)
##   rewards   — {xp, coins, cards: [template ids], flag: story flag set on turn-in}
##
## Objective types (progressed by SaveQuests.progress_event(type, target)):
##   kill      — win a fight against `target` enemy type ("" = any)
##   use_skill — win a fight having used skill `target`
##   learn     — learn ladder entry / skill `target` at a trainer
##   talk      — speak to NPC entity `target`
##   flag      — story flag `target` becomes set
##   explore   — reach story site `target`
##   rift_tier — clear tier N of a rift, `target` = "<rift_id>:<tier>"
extends RefCounted

const OBJECTIVE_TYPES: Array[String] = ["kill", "use_skill", "learn", "talk", "flag", "explore", "rift_tier"]

const QUESTS: Array[Dictionary] = [
	{"id": "rats_in_grain", "title": "Rats in the Grain Store", "giver": "hilda_baker",
		"giver_name": "Hilda the Baker",
		"summary": ("Rats have got into my grain store again — big ones, bold as brass. Clear three of them "
			+ "out and there's coin and a warm loaf in it for you."),
		"done_text": "That's the lot of them! Here — you've earned this.",
		"objectives": [{"type": "kill", "target": "", "count": 3, "label": "Pests cleared"}],
		"min_level": 1, "rewards": {"xp": 50, "coins": 20}},
]


static func all() -> Array[Dictionary]:
	return QUESTS

## The quest with `id`, or {} when there is none.
static func def(id: String) -> Dictionary:
	for q: Dictionary in QUESTS:
		if str(q.get("id", "")) == id:
			return q
	return {}

static func turn_in_npc(q: Dictionary) -> String:
	var t: String = str(q.get("turn_in", ""))
	return t if t != "" else str(q.get("giver", ""))

static func turn_in_name(q: Dictionary) -> String:
	var n: String = str(q.get("turn_in_name", ""))
	if n == "":
		n = str(q.get("giver_name", ""))
	return n if n != "" else "the quest giver"

static func objectives(q: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var raw: Array = q.get("objectives", [])
	for o: Variant in raw:
		if o is Dictionary:
			out.append(o as Dictionary)
	return out

## True when the event (type, target) counts toward objective `o`.
static func objective_matches(o: Dictionary, event_type: String, event_target: String) -> bool:
	if str(o.get("type", "")) != event_type:
		return false
	var want: String = str(o.get("target", ""))
	return want == "" or want == event_target

## True when `q` may be offered: level, story flag and prereqs met, and not
## already active or turned in.
static func can_offer(q: Dictionary, level: int, flags: Dictionary, active: Dictionary,
		completed: Array) -> bool:
	var id: String = str(q.get("id", ""))
	if active.has(id) or completed.has(id):
		return false
	if level < int(q.get("min_level", 1)):
		return false
	var req: String = str(q.get("req_flag", ""))
	if req != "" and not bool(flags.get(req, false)):
		return false
	var prereqs: Array = q.get("prereqs", [])
	for p: Variant in prereqs:
		if not completed.has(str(p)):
			return false
	return true

## Quests `npc_id` would offer right now, in table order.
static func offers_for(npc_id: String, level: int, flags: Dictionary, active: Dictionary,
		completed: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q: Dictionary in QUESTS:
		if str(q.get("giver", "")) == npc_id and can_offer(q, level, flags, active, completed):
			out.append(q)
	return out

## Offered by `npc_id` once the player levels up (grey "!" in WoW terms).
static func upcoming_for(npc_id: String, level: int, flags: Dictionary, active: Dictionary,
		completed: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for q: Dictionary in QUESTS:
		if str(q.get("giver", "")) != npc_id or level >= int(q.get("min_level", 1)):
			continue
		if can_offer(q, int(q.get("min_level", 1)), flags, active, completed):
			out.append(q)
	return out

## Every objective's count reached for `progress` (Array[int], one per objective).
static func is_complete(q: Dictionary, progress: Array) -> bool:
	var objs: Array[Dictionary] = objectives(q)
	for i: int in range(objs.size()):
		var have: int = int(progress[i]) if i < progress.size() else 0
		if have < int(objs[i].get("count", 1)):
			return false
	return true

## "Rats slain 2 / 3 · Speak to Hilda 0 / 1" style line.
static func progress_text(q: Dictionary, progress: Array) -> String:
	var parts: Array[String] = []
	var objs: Array[Dictionary] = objectives(q)
	for i: int in range(objs.size()):
		var have: int = int(progress[i]) if i < progress.size() else 0
		var need: int = int(objs[i].get("count", 1))
		parts.append("%s %d / %d" % [str(objs[i].get("label", "")), mini(have, need), need])
	return " · ".join(parts)
