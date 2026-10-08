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
##   rewards   — {xp, coins, cards: [template ids], flag: story flag set on turn-in,
##                gear_choice: [item ids] — pick one on turn-in, a rare roll at the quest level (TID-538)}
##
## Objective types (progressed by SaveQuests.progress_event(type, target)):
##   kill      — win a fight against `target` enemy type ("" = any)
##   use_skill — use skill-bar ability `target` in a fight (a Kick counts only when it
##               interrupts); "skeleton_dig" = dig a burial mound
##   learn     — learn ladder entry / skill `target` at a trainer
##   talk      — speak to NPC entity `target`
##   flag      — story flag `target` becomes set
##   explore   — reach story site `target`
##   open      — open chest `target`
##   rift_tier — clear tier N of a rift, `target` = "<rift_id>:<tier>"
extends RefCounted

const _StarterZone = preload("res://game_logic/world/StarterZone.gd")
const _XpCurve = preload("res://game_logic/progression/XpCurve.gd")

## GID-177 / TID-722: every camp (Madrian's and the Chapter 1 road camps) runs a
## repeatable **bonus objective** — no giver: walking into the camp starts it
## (`SaveQuests.auto_start`), finishing it pays out at once, and it can start
## again CAMP_QUEST_COOLDOWN_S later. Generated, not authored (`camp_quests`).
const CAMP_QUEST_PREFIX: String = "cull_"
const CAMP_QUEST_KILLS: int = 5
const CAMP_QUEST_COOLDOWN_S: float = 600.0
## Madrian's first camps are the tutorial quests' ground: bonus objectives start at level 3.
const CAMP_QUEST_MIN_LEVEL: int = 3
## One camp quest pays this share of the level's XP (plus its kills): 3–4 per level.
const CAMP_QUEST_XP_SHARE: float = 0.09


const OBJECTIVE_TYPES: Array[String] = ["kill", "use_skill", "learn", "talk", "flag", "explore", "open",
	"rift_tier"]

## GID-141 / TID-592: the starter chain. Five townsfolk quests (levels 1→6) each
## send the player to the next camp (StarterZone) and to the trainer for the
## thing they just unlocked; the last sets `town_quests_done`, which brings
## Maiteln to Madrian. Rewards are tuned so quest + camp XP reaches the next
## level and quest gold covers the next training (UnlockLadder costs).
## Optional quests for levels 6–12 follow.
const QUESTS: Array[Dictionary] = [
	{"id": "rats_in_grain", "title": "Rats in the Grain Store", "giver": "hilda_baker",
		"giver_name": "Hilda the Baker",
		"summary": ("Something's been at my grain store — and it's no rat, dearie, it's the restless dead, "
			+ "shambling about the field just east of the village. Put three of them down for me. Just walk up and "
			+ "tap them; your weapon swings on its own and Strike hits harder."),
		"done_text": ("That's the lot of them! Here's your coin. You're quick on your feet — the Combat Trainer "
			+ "by the stables could teach you to patch yourself up. Mend, he calls it."),
		"objectives": [{"type": "kill", "target": "undead_basic", "count": 3, "label": "Restless dead put down",
			"map": "main", "tx": 21, "tz": 17}],
		"min_level": 1, "rewards": {"xp": 200, "coins": 20}},
	{"id": "bruised_and_battered", "title": "Bruised and Battered", "giver": "wenna_herbalist",
		"giver_name": "Wenna the Herbalist", "prereqs": ["rats_in_grain"],
		"summary": ("You look like you went three rounds with a haystack. Learn Mend from the Combat Trainer, "
			+ "then prove it on the dead in the South Field — heal yourself mid-fight at least once."),
		"done_text": ("Better colour in your cheeks already. Next you'll want Kick — some of these things mutter "
			+ "spells, and a boot to the chin stops that. The Trainer will teach you."),
		"objectives": [
			{"type": "learn", "target": "mend", "count": 1, "label": "Learn Mend (Combat Trainer)"},
			{"type": "use_skill", "target": "mend", "count": 1, "label": "Mend in a fight"},
			{"type": "kill", "target": "undead_basic", "count": 4, "label": "South Field dead put down",
				"map": "main", "tx": -7, "tz": 21}],
		"min_level": 2, "rewards": {"xp": 260, "coins": 30,
			"gear_choice": ["leather_cap", "travel_boots", "leather_pauldrons"]}},
	{"id": "hedge_witch_chant", "title": "The Chanting in the Orchard", "giver": "brother_aldo",
		"giver_name": "Brother Aldo", "prereqs": ["bruised_and_battered"],
		"summary": ("The dead in the Old Orchard east of town are chanting — casting, I'd swear it. Learn Kick "
			+ "from the Combat Trainer. When a cast bar fills over one of them, Kick it before it finishes."),
		"done_text": ("Blessed quiet. You've a soldier's instincts, child. Old Tam served the lord for forty years "
			+ "— he'll know what to make of you next."),
		"objectives": [
			{"type": "learn", "target": "kick", "count": 1, "label": "Learn Kick (Combat Trainer)"},
			{"type": "use_skill", "target": "kick", "count": 2, "label": "Casts interrupted"},
			{"type": "kill", "target": "undead_horde", "count": 3, "label": "Orchard dead put down",
				"map": "main", "tx": 47, "tz": 19}],
		"min_level": 3, "rewards": {"xp": 230, "coins": 45}},
	{"id": "raise_the_fallen", "title": "Raise the Fallen", "giver": "old_tam", "giver_name": "Old Tam",
		"prereqs": ["hedge_witch_chant"],
		"summary": ("One sword alone won't hold the North Barrow. Those cards you carry — the Trainer can teach "
			+ "you to call them up to fight beside you. Learn to summon allies, then clear four from the barrow."),
		"done_text": ("Ha! Like a proper company. Ivy the chandler has a spark of the old craft about her — go "
			+ "and see her before you head anywhere near the Hedge Ruins."),
		"objectives": [
			{"type": "learn", "target": "feat_minions", "count": 1, "label": "Learn to summon allies"},
			{"type": "kill", "target": "undead_horde", "count": 4, "label": "Barrow dead put down",
				"map": "main", "tx": 33, "tz": -21}],
		"min_level": 4, "rewards": {"xp": 170, "coins": 60}},
	{"id": "first_spark", "title": "First Spark", "giver": "ivy_chandler", "giver_name": "Ivy the Chandler",
		"prereqs": ["raise_the_fallen"],
		"summary": ("Spell cards, love — you've been carrying them about like dead weight. The Trainer will show "
			+ "you how to cast them. Then take that spark to the ghouls in the Hedge Ruins, north-east."),
		"done_text": ("There's an old man in a grey cloak been asking after you by the well — says his name is "
			+ "Maiteln. Says it can't wait."),
		"objectives": [
			{"type": "learn", "target": "feat_spells", "count": 1, "label": "Learn to cast spells"},
			{"type": "kill", "target": "ghoul_pack", "count": 3, "label": "Hedge Ruins ghouls put down",
				"map": "main", "tx": 53, "tz": -27}],
		"min_level": 5, "rewards": {"xp": 180, "coins": 80, "flag": "town_quests_done",
			"gear_choice": ["iron_helm", "iron_greaves", "buckler"]}},
	# ── Optional: levels 6–12 ─────────────────────────────────────────────────
	# GID-177 / TID-722: the level 6–9 quests send you down the south road to the
	# road camps of their level (Madrian's own camps top out at 5). Ids kept (saves).
	{"id": "east_copse", "title": "Shades on the South Road", "giver": "old_tam", "giver_name": "Old Tam",
		"prereqs": ["raise_the_fallen"],
		"summary": ("Woodcutters coming up from Maykalene won't use the south road any more — shades in the "
			+ "Shade Thicket, they say. Four fewer would help them sleep."),
		"done_text": "Good work. Keep that blade oiled — the road only gets worse past the thicket.",
		"objectives": [{"type": "kill", "target": "forest_shade", "count": 4, "label": "Thicket shades put down",
			"map": "main", "tx": -15, "tz": 83}],
		"min_level": 6, "rewards": {"xp": 280, "coins": 80}},
	{"id": "west_crossing", "title": "The Mire Edge Hags", "giver": "brother_aldo",
		"giver_name": "Brother Aldo", "prereqs": ["hedge_witch_chant"],
		"summary": ("Pilgrims bound for Maykalene's shrine are vanishing at the Mire Edge, past the town. "
			+ "Bog hags. Clear five of them."),
		"done_text": "The pilgrim road is open again. Bless you.",
		"objectives": [{"type": "kill", "target": "bog_hag", "count": 5, "label": "Mire hags put down",
			"map": "main", "tx": 56, "tz": 128}],
		"min_level": 7, "rewards": {"xp": 350, "coins": 100}},
	{"id": "board_by_the_well", "title": "The Board by the Well", "giver": "bounty_master_madrian",
		"giver_name": "The Bounty Master",
		"summary": ("Contracts pay better than thanks. Learn how the board works from me, then show me you can "
			+ "handle the shades haunting the Old Watchtower on the Isfig road."),
		"done_text": "You'll do. Check the board every morning — the contracts change daily.",
		"objectives": [
			{"type": "learn", "target": "feat_bounties", "count": 1, "label": "Learn Bounty Contracts"},
			{"type": "kill", "target": "forest_shade", "count": 4, "label": "Watchtower shades put down",
				"map": "main", "tx": 92, "tz": 168}],
		"min_level": 8, "rewards": {"xp": 400, "coins": 120}},
	{"id": "after_dark", "title": "After Dark", "giver": "bounty_master_madrian", "giver_name": "The Bounty Master",
		"prereqs": ["board_by_the_well"],
		"summary": ("After sundown the spectres come out. Learn Night Hunts from me and bring down two wisps — "
			+ "they drop better than anything that walks by day."),
		"done_text": "Not bad for a night's work. The dark pays, if you live through it.",
		"objectives": [
			{"type": "learn", "target": "feat_night_hunts", "count": 1, "label": "Learn Night Hunts"},
			{"type": "kill", "target": "spectre_wisp", "count": 2, "label": "Wisps hunted after dark"}],
		"min_level": 9, "rewards": {"xp": 420, "coins": 140}},
	{"id": "south_road_wreck", "title": "The Stolen Flour Cart", "giver": "hilda_baker",
		"giver_name": "Hilda the Baker", "prereqs": ["first_spark"],
		"summary": ("My flour cart never made it back from Blancogov. Martarquas raiders took it to their "
			+ "outpost on the north road, they say. Five of them, and I'll bake you something special."),
		"done_text": "My flour! Well — what's left of it. Here, you've earned this.",
		"objectives": [{"type": "kill", "target": "martarquas_scout", "count": 5, "label": "Outpost scouts put down",
			"map": "main", "tx": 78, "tz": 206}],
		"min_level": 9, "rewards": {"xp": 450, "coins": 150,
			"gear_choice": ["hooded_cowl", "spurred_boots", "chainmail"]}},
	{"id": "old_bones", "title": "Old Bones", "giver": "gravedigger_madrian", "giver_name": "The Gravedigger",
		"summary": ("Carry enough skeleton cards and the old bones listen to you. I'll teach you to dig — "
			+ "then turn over one of the mounds here in my graveyard and see what the dead left behind."),
		"done_text": "Ha! You've the knack. There's more of those mounds out in the wilds.",
		"objectives": [
			{"type": "learn", "target": "feat_dig", "count": 1, "label": "Learn Skeleton Dig (Gravedigger)"},
			{"type": "use_skill", "target": "skeleton_dig", "count": 1, "label": "Burial mound dug",
				"map": "main", "tx": -24, "tz": 22}],
		"min_level": 10, "rewards": {"xp": 800, "coins": 200}},
	{"id": "sealed_crypt", "title": "The Sealed Crypt", "giver": "gravedigger_madrian",
		"giver_name": "The Gravedigger", "prereqs": ["old_bones"],
		"summary": ("See that crypt east of my yard, walled up with no door? Nobody's been in since my "
			+ "grandsire's day. Learn Ghost Phase and walk straight through the wall. Whatever's inside is yours."),
		"done_text": "Through solid stone! The dead are good teachers, aren't they?",
		"objectives": [
			{"type": "learn", "target": "feat_phase", "count": 1, "label": "Learn Ghost Phase (Gravedigger)"},
			{"type": "open", "target": "sealed_crypt_chest", "count": 1, "label": "Crypt chest opened",
				"map": "main", "tx": -13, "tz": 17}],
		"min_level": 12, "rewards": {"xp": 1000, "coins": 250,
			"gear_choice": ["iron_pauldrons", "warded_cloak", "parrying_dagger"]}},
	# ── Rifts (GID-142 / TID-599): one-time goals — the XP that repeat runs don't pay ──
	{"id": "into_the_rift", "title": "Into the Rift", "giver": "rift_warden_madrian", "giver_name": "The Rift Warden",
		"summary": ("There's a tear in the world just past this door. Learn the Rifts from the Combat Trainer, "
			+ "then clear the first tier of the Grasslands Rift — five floors, your own deck, and a guardian at "
			+ "the top. Fighting in there won't make you stronger by itself; what you prove will."),
		"done_text": ("You came back. Most do, the first time. Every land has its own rift — and every tier "
			+ "cleared is a story worth telling. I'll have more for you."),
		"objectives": [
			{"type": "learn", "target": "feat_spire", "count": 1, "label": "Learn the Rifts (Combat Trainer)"},
			{"type": "rift_tier", "target": "grasslands:1", "count": 1, "label": "Grasslands Rift tier 1 cleared"}],
		"min_level": 15, "rewards": {"xp": 1500, "coins": 300,
			"gear_choice": ["spiked_spaulders", "dusk_blade", "arcane_focus"]}},
	{"id": "rift_grasslands_3", "title": "Grasslands Rift: Tier 3", "giver": "rift_warden_madrian",
		"giver_name": "The Rift Warden", "prereqs": ["into_the_rift"],
		"summary": "Push the Grasslands Rift to its third tier. The guardian there won't go easy.",
		"done_text": "Tier three. The Grasslands Rift will remember your name.",
		"objectives": [{"type": "rift_tier", "target": "grasslands:3", "count": 1,
			"label": "Grasslands Rift tier 3 cleared"}],
		"min_level": 16, "rewards": {"xp": 2500, "coins": 400}},
	{"id": "rift_forest_3", "title": "Forest Rift: Tier 3", "giver": "rift_warden_madrian",
		"giver_name": "The Rift Warden", "prereqs": ["into_the_rift"],
		"summary": "Push the Forest Rift to its third tier. The guardian there won't go easy.",
		"done_text": "Tier three. The Forest Rift will remember your name.",
		"objectives": [{"type": "rift_tier", "target": "forest:3", "count": 1,
			"label": "Forest Rift tier 3 cleared"}],
		"min_level": 16, "rewards": {"xp": 2500, "coins": 400}},
	{"id": "rift_desert_3", "title": "Desert Rift: Tier 3", "giver": "rift_warden_madrian",
		"giver_name": "The Rift Warden", "prereqs": ["into_the_rift"],
		"summary": "Push the Desert Rift to its third tier. The guardian there won't go easy.",
		"done_text": "Tier three. The Desert Rift will remember your name.",
		"objectives": [{"type": "rift_tier", "target": "desert:3", "count": 1,
			"label": "Desert Rift tier 3 cleared"}],
		"min_level": 16, "rewards": {"xp": 2500, "coins": 400}},
	{"id": "rift_scorched_3", "title": "Scorched Rift: Tier 3", "giver": "rift_warden_madrian",
		"giver_name": "The Rift Warden", "prereqs": ["into_the_rift"],
		"summary": "Push the Scorched Rift to its third tier. The guardian there won't go easy.",
		"done_text": "Tier three. The Scorched Rift will remember your name.",
		"objectives": [{"type": "rift_tier", "target": "scorched:3", "count": 1,
			"label": "Scorched Rift tier 3 cleared"}],
		"min_level": 16, "rewards": {"xp": 2500, "coins": 400}},
	{"id": "rift_mountains_3", "title": "Mountain Rift: Tier 3", "giver": "rift_warden_madrian",
		"giver_name": "The Rift Warden", "prereqs": ["into_the_rift"],
		"summary": "Push the Mountain Rift to its third tier. The guardian there won't go easy.",
		"done_text": "Tier three. The Mountain Rift will remember your name.",
		"objectives": [{"type": "rift_tier", "target": "mountains:3", "count": 1,
			"label": "Mountain Rift tier 3 cleared"}],
		"min_level": 16, "rewards": {"xp": 2500, "coins": 400}},
	{"id": "rift_grasslands_5", "title": "Grasslands Rift: Tier 5", "giver": "rift_warden_madrian",
		"giver_name": "The Rift Warden", "prereqs": ["rift_grasslands_3"],
		"summary": "Tier five of the Grasslands Rift. Few from Madrian have seen it.",
		"done_text": "Five. I stopped counting the ones who tried.",
		"objectives": [{"type": "rift_tier", "target": "grasslands:5", "count": 1,
			"label": "Grasslands Rift tier 5 cleared"}],
		"min_level": 20, "rewards": {"xp": 4000, "coins": 600}},
]


static var _all: Array[Dictionary] = []

## Authored quests + the generated camp bonus objectives.
static func all() -> Array[Dictionary]:
	if _all.is_empty():
		_all.assign(QUESTS + camp_quests())
	return _all

## One repeatable "Cull" bonus objective per camp, at the camp's level.
static func camp_quests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for camp: Dictionary in _StarterZone.CAMPS:
		var lvl: int = _StarterZone.camp_level(camp)
		var tile: Vector2i = camp["tile"]
		out.append({"id": camp_quest_id(str(camp["id"])), "title": "Cull: %s" % str(camp["name"]),
			"giver": "", "giver_name": "", "auto": true, "repeatable": true, "cooldown_s": CAMP_QUEST_COOLDOWN_S,
			"summary": "Thin out the creatures at %s." % str(camp["name"]),
			"done_text": "Bonus objective complete.",
			"objectives": [{"type": "kill", "target": str(camp["enemy_type"]), "count": CAMP_QUEST_KILLS,
				"label": "Defeated at %s" % str(camp["name"]), "map": "main", "tx": tile.x, "tz": tile.y}],
			"min_level": maxi(CAMP_QUEST_MIN_LEVEL, lvl - 2),
			"rewards": {"xp": roundi(float(_XpCurve.step(lvl)) * CAMP_QUEST_XP_SHARE / 10.0) * 10,
				"coins": 10 + 4 * lvl}})
	return out

static func camp_quest_id(camp_id: String) -> String:
	return CAMP_QUEST_PREFIX + camp_id

static func is_repeatable(q: Dictionary) -> bool:
	return bool(q.get("repeatable", false))

## The quest with `id`, or {} when there is none.
static func def(id: String) -> Dictionary:
	for q: Dictionary in all():
		if str(q.get("id", "")) == id:
			return q
	return {}

static func turn_in_npc(q: Dictionary) -> String:
	var t: String = str(q.get("turn_in", ""))
	return t if t != "" else str(q.get("giver", ""))

## Display name for a quest giver's NPC id, or "" (for the townsperson name tag).
static func giver_name_for(npc_id: String) -> String:
	for q: Dictionary in all():
		if str(q.get("giver", "")) == npc_id and str(q.get("giver_name", "")) != "":
			return str(q["giver_name"])
	return ""

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
	if active.has(id) or (completed.has(id) and not is_repeatable(q)):
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
	if npc_id == "":
		return out  # giver-less camp bonus objectives start on their own
	for q: Dictionary in all():
		if str(q.get("giver", "")) == npc_id and can_offer(q, level, flags, active, completed):
			out.append(q)
	return out

## Offered by `npc_id` once the player levels up (grey "!" in WoW terms).
static func upcoming_for(npc_id: String, level: int, flags: Dictionary, active: Dictionary,
		completed: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if npc_id == "":
		return out
	for q: Dictionary in all():
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
