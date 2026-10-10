## Technique cards (GID-175 / TID-707): the old skill-bar abilities as deck
## cards. The `.tres` in data/cards/ holds the card face (cost, turn-based
## `spell_effect` / `spell_power`); this table holds what a card face can't —
## real-time numbers and the trainer price. See combat-model.md → "Technique cards".
##
## A technique is a spell that, once resolved, goes to the **bottom of the draw
## pile** instead of the discard (`PlayerState.play_card`). In real time it then
## comes back to the hand after its `recycle` cooldown (`PlayerCaster`, GID-178),
## so the basics keep a steady rhythm. Pure logic, safe for `-s` tests.
extends RefCounted

## Most techniques one deck may hold (the old bar had 3 slots).
const DECK_MAX: int = 3
## Copies of one technique a deck may hold.
const MAX_COPIES: int = 1

## card id → {rt_value (real-time power), cast (s, -1 = card cast formula),
## off_gcd, mana_value (units, mana_tap), level_req, learn_cost, recycle (s back
## to the hand in real time, × CombatTuning `tech_recycle_mult` — GID-178)}.
const DEFS: Dictionary = {
	"tech_strike": {"rt_value": 2, "recycle": 3.0, "cast": 0.0, "off_gcd": false, "level_req": 0, "learn_cost": 0},
	"tech_mend": {"rt_value": 6, "recycle": 20.0, "cast": 1.5, "off_gcd": false, "level_req": 2, "learn_cost": 15},
	"tech_kick": {"rt_value": 0, "recycle": 15.0, "cast": 0.0, "off_gcd": true, "level_req": 3, "learn_cost": 25},
	"tech_guard": {"rt_value": 6, "recycle": 15.0, "cast": 0.0, "off_gcd": false, "level_req": 11, "learn_cost": 60},
	"tech_ember_lance": {"rt_value": 9, "recycle": 6.0, "cast": 1.0, "off_gcd": false, "level_req": 13, "learn_cost": 90},
	"tech_mana_tap": {"rt_value": 2, "recycle": 15.0, "cast": 0.0, "off_gcd": false, "level_req": 14, "learn_cost": 90,
		"mana_value": 1},
	"tech_sweep": {"rt_value": 3, "recycle": 6.0, "cast": 0.0, "off_gcd": false, "level_req": 16, "learn_cost": 120},
	"tech_daze": {"rt_value": 0, "recycle": 20.0, "cast": 0.0, "off_gcd": true, "level_req": 18, "learn_cost": 150},
	# Skill-tree techniques (GID-179 / TID-734): owned by unlocking `skill` in the
	# skill tree, never taught by a trainer. Branch-typed, so branch modifiers reach them.
	"tech_pyroblast": {"rt_value": 4, "recycle": 10.0, "cast": 1.5,
		"off_gcd": false, "skill": "ember_pyroblast"},
	"tech_blazing_draw": {"rt_value": 2, "recycle": 20.0, "cast": 0.0,
		"off_gcd": false, "skill": "ember_blazing_draw"},
	"tech_restoration": {"rt_value": 9, "recycle": 18.0, "cast": 1.5,
		"off_gcd": false, "skill": "dawn_restoration"},
	"tech_arcane_clarity": {"rt_value": 2, "recycle": 20.0, "cast": 0.0,
		"off_gcd": false, "skill": "dawn_arcane_clarity"},
	"tech_soul_siphon": {"rt_value": 3, "recycle": 12.0, "cast": 1.0,
		"off_gcd": false, "skill": "dusk_soul_siphon"},
	"tech_mana_drain": {"rt_value": 2, "recycle": 15.0, "cast": 0.0,
		"off_gcd": false, "skill": "dusk_mana_drain", "mana_value": 1},
	"tech_grave_call": {"rt_value": 2, "recycle": 20.0, "cast": 0.0,
		"off_gcd": false, "skill": "ash_grave_call"},
	"tech_brittle_curse": {"rt_value": 3, "recycle": 10.0, "cast": 1.0,
		"off_gcd": false, "skill": "ash_brittle_curse"},
	"tech_overgrowth": {"rt_value": 4, "recycle": 16.0, "cast": 1.0,
		"off_gcd": false, "skill": "bloom_overgrowth"},
	"tech_bountiful_harvest": {"rt_value": 2, "recycle": 20.0, "cast": 0.0,
		"off_gcd": false, "skill": "bloom_bountiful_harvest", "mana_value": 2},
	"tech_thornburst": {"rt_value": 3, "recycle": 8.0, "cast": 0.0,
		"off_gcd": false, "skill": "thorn_thornburst"},
	"tech_second_bloom": {"rt_value": 7, "recycle": 15.0, "cast": 0.0,
		"off_gcd": false, "skill": "thorn_second_bloom"},
	"tech_reweave": {"rt_value": 2, "recycle": 15.0, "cast": 0.0,
		"off_gcd": false, "skill": "flux_reweave"},
	"tech_mana_surge": {"rt_value": 2, "recycle": 18.0, "cast": 0.0,
		"off_gcd": false, "skill": "flux_mana_surge", "mana_value": 2},
	"tech_shatterwave": {"rt_value": 4, "recycle": 12.0, "cast": 1.5,
		"off_gcd": false, "skill": "fracture_shatterwave"},
	"tech_scavenged_shards": {"rt_value": 2, "recycle": 15.0, "cast": 0.0,
		"off_gcd": false, "skill": "fracture_scavenged_shards"},
}

## Trainer techniques in display order (Strike is never taught — every save
## starts with it). Skill-tree techniques (a `skill` key) are not listed here.
const ORDER: Array[String] = [
	"tech_strike", "tech_mend", "tech_kick", "tech_guard",
	"tech_ember_lance", "tech_mana_tap", "tech_sweep", "tech_daze",
]

## Ability id as stored in `SaveManager.learned_abilities` / the UnlockLadder
## ("mend") → its technique card id ("tech_mend"); "" when it isn't one.
static func card_for(ability_id: String) -> String:
	var id: String = "tech_" + ability_id
	return id if DEFS.has(id) else ""

## The reverse of `card_for`.
static func ability_for(card_id: String) -> String:
	return card_id.trim_prefix("tech_") if DEFS.has(card_id) else ""

## Technique card ids a save knows: Strike always, each learned ability, and
## each unlocked skill-tree node that grants one (GID-179).
static func known_cards(learned: Array, skills: Array = []) -> Array[String]:
	var out: Array[String] = ["tech_strike"]
	for v: Variant in learned:
		var id: String = card_for(str(v))
		if id != "" and not out.has(id):
			out.append(id)
	for v: Variant in skills:
		var sid: String = card_for_skill(str(v))
		if sid != "" and not out.has(sid):
			out.append(sid)
	return out

## Skill-tree node id ("ember_pyroblast") → its technique card id, or "".
static func card_for_skill(skill_id: String) -> String:
	for id: String in DEFS:
		if str((DEFS[id] as Dictionary).get("skill", "")) == skill_id:
			return id
	return ""

## True for a technique granted by the skill tree rather than a trainer.
static func is_skill_technique(card_id: String) -> bool:
	return def(card_id).has("skill")

static func is_technique(card_id: String) -> bool:
	return DEFS.has(card_id)

## Every technique card id: trainer ones in ORDER, then the skill-tree ones.
static func ids() -> Array[String]:
	var out: Array[String] = ORDER.duplicate()
	for id: String in DEFS:
		if not out.has(id):
			out.append(id)
	return out

static func def(card_id: String) -> Dictionary:
	return DEFS.get(card_id, {}) as Dictionary

## The power a technique resolves with: `rt_value` in real time, else the card's
## printed (turn-based) `spell_power`. Non-techniques keep `printed`.
static func power(card_id: String, printed: int, realtime: bool) -> int:
	if not realtime or not DEFS.has(card_id):
		return printed
	return int(def(card_id).get("rt_value", printed))

## Real-time cast time override in seconds, or -1 to use the spell formula.
## Seconds before a resolved technique returns to the hand (real time).
static func recycle_time(card_id: String) -> float:
	return float(def(card_id).get("recycle", 8.0))

static func cast_time(card_id: String) -> float:
	return float(def(card_id).get("cast", -1.0)) if DEFS.has(card_id) else -1.0

static func off_gcd(card_id: String) -> bool:
	return bool(def(card_id).get("off_gcd", false))

## Mana units a `mana_tap` technique gives back.
static func mana_value(card_id: String) -> int:
	return int(def(card_id).get("mana_value", 1))

## Why a deck's technique mix is illegal, or "" when fine: more than
## MAX_COPIES of one technique, or more than DECK_MAX techniques in total.
static func deck_violation(card_ids: Array) -> String:
	var counts: Dictionary = {}
	var total: int = 0
	for v: Variant in card_ids:
		var id: String = str(v)
		if not DEFS.has(id):
			continue
		total += 1
		counts[id] = int(counts.get(id, 0)) + 1
		if int(counts[id]) > MAX_COPIES:
			return "Only %d copy of each technique per deck." % MAX_COPIES
	if total > DECK_MAX:
		return "At most %d techniques per deck." % DECK_MAX
	return ""
