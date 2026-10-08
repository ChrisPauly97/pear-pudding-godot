## Levelling pacing simulation (GID-177 / TID-723): a scripted player works
## through Chapter 1 on the real save API (SideQuests rewards, camp levels, kill
## XP, XpCurve, trainer costs) with a simple time model, and reports how many
## minutes each level took. Used by test_pacing.gd; not a unit test itself.
##
## Time model (assumptions, documented in starter-zone-and-training.md):
##   KILL_S      — one camp kill: walk to the next mob + a ~20 s fight + recover
##   QUEST_S     — accepting + handing in an authored quest (walk to the giver, talk)
##   TRAVEL_S    — getting to a quest's camp
##   OTHER_S     — a non-kill objective (learn at a trainer, use a skill, dig…)
## The player does authored quests when offered (in table order); otherwise the
## bonus objective at the best camp for their level; trainings are learned as soon
## as they are offered and affordable.
extends RefCounted

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const SideQuests = preload("res://game_logic/quests/SideQuests.gd")
const StarterZone = preload("res://game_logic/world/StarterZone.gd")
const ZoneLevels = preload("res://game_logic/world/ZoneLevels.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const UnlockLadder = preload("res://game_logic/progression/UnlockLadder.gd")

const KILL_S: float = 60.0
const QUEST_S: float = 90.0
const TRAVEL_S: float = 90.0
const OTHER_S: float = 60.0
const MAX_S: float = 10.0 * 3600.0

var sm: SaveManagerScript
var t: float = 0.0
## level → seconds spent at that level; quest counts per level.
var level_secs: Dictionary = {}
var quests_at: Dictionary = {}
## ladder id → the level it was learned at.
var learned_at: Dictionary = {}
var _level_started: float = 0.0
var _starts: Dictionary = {}

func run(to_level: int = 10) -> void:
	sm = SaveManagerScript.new()
	sm.new_game(false)
	sm.quests.clock_override = 0.0
	while sm.level < to_level and t < MAX_S:
		_learn_what_you_can()
		var q: Dictionary = _next_authored()
		if not q.is_empty():
			_do_authored(q)
		else:
			_do_bonus()

func minutes(level: int) -> float:
	return float(level_secs.get(level, 0.0)) / 60.0

func _spend(secs: float) -> void:
	t += secs
	sm.quests.clock_override = t

func _note_level(before: int) -> void:
	if sm.level > before:
		level_secs[before] = t - _level_started
		_level_started = t

func _learn_what_you_can() -> void:
	for id: String in UnlockLadder.all_ids():
		if UnlockLadder.level_req(id) <= 10 and UnlockLadder.can_learn(id, sm.level, sm.coins, sm.learned_abilities):
			sm.learn_ability(id, UnlockLadder.cost(id))
			learned_at[id] = sm.level
			_spend(OTHER_S)

func _next_authored() -> Dictionary:
	for q: Dictionary in SideQuests.QUESTS:
		if int(q.get("min_level", 1)) > 10:
			continue
		if SideQuests.can_offer(q, sm.level, sm.story_flags, sm.quests_active, sm.quests_completed):
			return q
	return {}

func _do_authored(q: Dictionary) -> void:
	var id: String = str(q["id"])
	sm.quests.accept(id)
	_spend(QUEST_S * 0.5)
	for o: Dictionary in SideQuests.objectives(q):
		var kind: String = str(o["type"])
		var target: String = str(o["target"])
		for _i: int in int(o.get("count", 1)):
			if kind == "kill":
				var lvl: int = sm.level
				var camp: Dictionary = _camp_at(o)
				if not camp.is_empty():
					lvl = StarterZone.camp_level(camp)
				_kill(target, lvl)
			elif kind == "learn":
				while not sm.learned_abilities.has(target) and t < MAX_S:
					if UnlockLadder.can_learn(target, sm.level, sm.coins, sm.learned_abilities):
						sm.learn_ability(target, UnlockLadder.cost(target))
						learned_at[target] = sm.level
					else:
						_do_bonus()  # earn the gold / level first
				_spend(OTHER_S)
				sm.quests.progress_event("learn", target)
			else:
				_spend(OTHER_S)
				sm.quests.progress_event(kind, target)
	if o_has_camp(q):
		_spend(TRAVEL_S)
	var before: int = sm.level
	if not sm.quests.turn_in(id).is_empty():
		_count_quest()
	_spend(QUEST_S * 0.5)
	_note_level(before)

func o_has_camp(q: Dictionary) -> bool:
	for o: Dictionary in SideQuests.objectives(q):
		if o.has("tx"):
			return true
	return false

## The best camp for a bonus objective: the highest-level camp at or below the
## player's level whose bonus objective can start now (else just grind it).
func _do_bonus() -> void:
	var best: Dictionary = {}
	for c: Dictionary in StarterZone.CAMPS:
		var cl: int = StarterZone.camp_level(c)
		if cl > sm.level:
			continue
		if best.is_empty() or cl > StarterZone.camp_level(best) \
				or (cl == StarterZone.camp_level(best) and _ready(c) and not _ready(best)):
			best = c
	if best.is_empty():
		best = StarterZone.camp_for_level(sm.level)
	_spend(TRAVEL_S)
	var id: String = SideQuests.camp_quest_id(str(best["id"]))
	var started: bool = sm.quests.auto_start(id, t)
	for _i: int in SideQuests.CAMP_QUEST_KILLS:
		_kill(str(best["enemy_type"]), StarterZone.camp_level(best))
	if started and not sm.quests.is_active(id):
		_count_quest()

func _ready(c: Dictionary) -> bool:
	var id: String = SideQuests.camp_quest_id(str(c["id"]))
	return t >= float(sm.quest_repeat_at.get(id, 0.0)) and sm.level >= int(SideQuests.def(id)["min_level"])

func _kill(enemy_type: String, enemy_level: int) -> void:
	var before: int = sm.level
	_spend(KILL_S)
	sm.add_xp(ZoneLevels.scaled_xp(EnemyRegistry.get_xp_reward(enemy_type), enemy_level, sm.level))
	sm.add_coins(EnemyRegistry.get_coin_reward(enemy_type))
	sm.quests.progress_event("kill", enemy_type)
	_note_level(before)

func _count_quest() -> void:
	quests_at[sm.level] = int(quests_at.get(sm.level, 0)) + 1

func _camp_at(o: Dictionary) -> Dictionary:
	if not o.has("tx"):
		return {}
	for c: Dictionary in StarterZone.CAMPS:
		if c["tile"] == Vector2i(int(o["tx"]), int(o["tz"])):
			return c
	return {}
