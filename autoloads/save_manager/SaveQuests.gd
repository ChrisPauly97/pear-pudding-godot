## Side quests (SideQuests table): accept, progress, turn in (GID-136 / TID-533).
##
## Owned by SaveManager (`SaveManager.quests`), created in its `_init`. State stays
## on SaveManager (PERSISTED_FIELDS walks its properties):
##   quests_active    — {quest_id: {"progress": [int per objective]}}
##   quests_completed — [quest_id] turned in
extends RefCounted

const _SaveManager = preload("res://autoloads/SaveManager.gd")
const _SideQuests = preload("res://game_logic/quests/SideQuests.gd")
const _GearRolls = preload("res://game_logic/items/GearRolls.gd")
const _RiddleSpots = preload("res://game_logic/world/RiddleSpots.gd")

var _save: _SaveManager


func _init(save_manager: _SaveManager) -> void:
	_save = save_manager


func is_active(id: String) -> bool:
	return _save.quests_active.has(id)

func is_turned_in(id: String) -> bool:
	return _save.quests_completed.has(id)

func progress_of(id: String) -> Array:
	var entry: Dictionary = _save.quests_active.get(id, {})
	var p: Array = entry.get("progress", [])
	return p

## Every objective met, waiting to be handed in.
func is_ready(id: String) -> bool:
	if not is_active(id):
		return false
	return _SideQuests.is_complete(_SideQuests.def(id), progress_of(id))

func offers_for(npc_id: String) -> Array[Dictionary]:
	return _SideQuests.offers_for(npc_id, _save.level, _save.story_flags, _save.quests_active,
			_save.quests_completed)

## Overhead-mark state for `npc_id` (QuestLog.npc_mark's `side`).
func npc_state(npc_id: String) -> String:
	return str(npc_states().get(npc_id, ""))

## npc_id → "turn_in" | "offer" | "upcoming" for every NPC with side-quest
## business, in one pass over the quests (GID-162: the mark refresh used to run
## three full quest scans per loaded NPC). Same precedence as turn_ins_for /
## offers_for / SideQuests.upcoming_for: a hand-in beats an offer beats upcoming.
func npc_states() -> Dictionary:
	var out: Dictionary = {}
	for id: Variant in _save.quests_active.keys():
		var q: Dictionary = _SideQuests.def(str(id))
		if not q.is_empty() and is_ready(str(id)):
			out[_SideQuests.turn_in_npc(q)] = "turn_in"
	for q: Dictionary in _SideQuests.all():
		var giver: String = str(q.get("giver", ""))
		if giver == "" or out.get(giver, "") == "turn_in":
			continue
		var min_level: int = int(q.get("min_level", 1))
		if _SideQuests.can_offer(q, _save.level, _save.story_flags, _save.quests_active, _save.quests_completed):
			out[giver] = "offer"
		elif (_save.level < min_level and not out.has(giver)
				and _SideQuests.can_offer(q, min_level, _save.story_flags, _save.quests_active, _save.quests_completed)):
			out[giver] = "upcoming"
	return out

## Active quests `npc_id` takes back that are ready to hand in.
func turn_ins_for(npc_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: Variant in _save.quests_active.keys():
		var q: Dictionary = _SideQuests.def(str(id))
		if not q.is_empty() and _SideQuests.turn_in_npc(q) == npc_id and is_ready(str(id)):
			out.append(q)
	return out

func accept(id: String) -> bool:
	var q: Dictionary = _SideQuests.def(id)
	if q.is_empty() or not _SideQuests.can_offer(q, _save.level, _save.story_flags,
			_save.quests_active, _save.quests_completed):
		return false
	var progress: Array = []
	for o: Dictionary in _SideQuests.objectives(q):
		# A flag already set, or something already learned (a trainer visit made
		# before taking the quest), counts at once.
		var otype: String = str(o.get("type", ""))
		var target: String = str(o.get("target", ""))
		var met: bool = ((otype == "flag" and _save.get_story_flag(target))
				or (otype == "learn" and _save.learned_abilities.has(target)))
		progress.append(int(o.get("count", 1)) if met else 0)
	_save.quests_active[id] = {"progress": progress}
	_save._dirty = true
	GameBus.quest_accepted.emit(id)
	if _SideQuests.is_complete(q, progress):
		GameBus.quest_ready.emit(id)
	return true

## Counts one (or `amount`) of an event toward every active quest objective it
## matches. Returns true when any progress changed.
func progress_event(event_type: String, target: String = "", amount: int = 1) -> bool:
	if event_type == "kill":
		_legend_sigh(target)
	var changed: bool = false
	for idv: Variant in _save.quests_active.keys():
		var id: String = str(idv)
		var q: Dictionary = _SideQuests.def(id)
		if q.is_empty():
			continue
		var was_ready: bool = _SideQuests.is_complete(q, progress_of(id))
		var progress: Array = progress_of(id).duplicate()
		var objs: Array[Dictionary] = _SideQuests.objectives(q)
		var touched: bool = false
		for i: int in range(objs.size()):
			if not _SideQuests.objective_matches(objs[i], event_type, target):
				continue
			while progress.size() <= i:
				progress.append(0)
			var need: int = int(objs[i].get("count", 1))
			if int(progress[i]) >= need:
				continue
			progress[i] = mini(int(progress[i]) + amount, need)
			touched = true
		if not touched:
			continue
		_save.quests_active[id] = {"progress": progress}
		changed = true
		GameBus.quest_progressed.emit(id)
		if not was_ready and _SideQuests.is_complete(q, progress):
			GameBus.quest_ready.emit(id)
			if bool(q.get("auto", false)):
				_auto_complete(id, q)
	if changed:
		_save._dirty = true
	return changed

## GID-177 / TID-722: starts a giver-less bonus objective (a camp's "Cull"
## quest) when the player walks into its camp — once the level allows and its
## cooldown has run out. Returns true when it started.
func auto_start(id: String, now: float = -1.0) -> bool:
	var q: Dictionary = _SideQuests.def(id)
	if q.is_empty() or not bool(q.get("auto", false)) or is_active(id):
		return false
	if (now if now >= 0.0 else _now()) < float(_save.quest_repeat_at.get(id, 0.0)):
		return false
	if not accept(id):
		return false
	GameBus.hud_message_requested.emit("Bonus objective: %s" % str(q.get("title", "")))
	return true

## A bonus objective pays out the moment it is done (no NPC to hand it to).
func _auto_complete(id: String, q: Dictionary) -> void:
	var rewards: Dictionary = turn_in(id)
	if not rewards.is_empty():
		GameBus.hud_message_requested.emit("%s complete — +%d XP" % [str(q.get("title", "")),
				int(rewards.get("xp", 0))])

static func _now() -> float:
	return Time.get_unix_time_from_system()

## Hands a ready quest in: pays its rewards, sets its flag and records it.
## `gear_pick` is the chosen item of a `gear_choice` reward (TID-538; granted as a
## rare roll at the quest level); an empty or unknown pick takes the first choice.
## Returns the rewards dict granted (plus "gear" = the pick), or {} when it can't be turned in.
func turn_in(id: String, gear_pick: String = "") -> Dictionary:
	if not is_ready(id):
		return {}
	var q: Dictionary = _SideQuests.def(id)
	var rewards: Dictionary = (q.get("rewards", {}) as Dictionary).duplicate()
	var choice: Array = rewards.get("gear_choice", [])
	if not choice.is_empty():
		if not choice.has(gear_pick):
			gear_pick = str(choice[0])
		_save.gear.grant(gear_pick, quest_gear_roll(q))
		rewards["gear"] = gear_pick
	_save.quests_active.erase(id)
	if _SideQuests.is_repeatable(q):
		_save.quest_repeat_at[id] = _now() + float(q.get("cooldown_s", 0.0))
	elif not _save.quests_completed.has(id):
		_save.quests_completed.append(id)
	var coins: int = int(rewards.get("coins", 0))
	if coins > 0:
		_save.add_coins(coins)
	var cards: Array = rewards.get("cards", [])
	for c: Variant in cards:
		_save.grant_card_reward(str(c), "common")
	var flag: String = str(rewards.get("flag", ""))
	if flag != "":
		_save.set_story_flag(flag)
	var xp: int = int(rewards.get("xp", 0))
	if xp > 0:
		_save.add_xp(xp)
	_save._dirty = true
	GameBus.quest_turned_in.emit(id)
	return rewards

## The roll a quest's gear reward is granted at: QUEST_RARITY, item level one above the quest's.
static func quest_gear_roll(q: Dictionary) -> Dictionary:
	return {"rarity": _GearRolls.QUEST_RARITY, "ilvl": int(q.get("min_level", 1)) + 1}

## Active side quests as QuestLog entries.
func log_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for idv: Variant in _save.quests_active.keys():
		var id: String = str(idv)
		var q: Dictionary = _SideQuests.def(id)
		if q.is_empty():
			continue
		out.append({"quest": q, "progress": progress_of(id), "ready": is_ready(id)})
	return out


## GID-153: every won fight reports its kills here (spectres included), so the Pear
## Pudding legend's Spectre's Sigh rides along. Not a side quest: no log, no marks.
func _legend_sigh(enemy_type: String) -> void:
	if not _RiddleSpots.earns_sigh(enemy_type, _save.story_flags):
		return
	_save.set_story_flag(_RiddleSpots.SIGH_FLAG)
	GameBus.legend_riddle_solved.emit("spectre_sigh")
	GameBus.hud_message_requested.emit(_RiddleSpots.SIGH_TEXT)
