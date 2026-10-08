## Technique cards (GID-175 / TID-707): the old skill-bar abilities as deck
## cards. The `.tres` in data/cards/ holds the card face (cost, turn-based
## `spell_effect` / `spell_power`); this table holds what a card face can't —
## real-time numbers and the trainer price. See combat-model.md → "Technique cards".
##
## A technique is a spell that, once resolved, goes to the **bottom of the draw
## pile** instead of the discard (`PlayerState.play_card`): deck cycling is its
## cooldown. Pure logic, safe for `-s` tests.
extends RefCounted

## Most techniques one deck may hold (the old bar had 3 slots).
const DECK_MAX: int = 3
## Copies of one technique a deck may hold.
const MAX_COPIES: int = 1

## card id → {rt_value (real-time power), cast (s, -1 = card cast formula),
## off_gcd, mana_value (units, mana_tap), level_req, learn_cost}.
## Real-time values match the retired `SkillBar.ABILITIES`.
const DEFS: Dictionary = {
	"tech_strike": {"rt_value": 5, "cast": 0.0, "off_gcd": false, "level_req": 0, "learn_cost": 0},
	"tech_mend": {"rt_value": 6, "cast": 1.5, "off_gcd": false, "level_req": 2, "learn_cost": 15},
	"tech_kick": {"rt_value": 0, "cast": 0.0, "off_gcd": true, "level_req": 3, "learn_cost": 25},
	"tech_guard": {"rt_value": 6, "cast": 0.0, "off_gcd": false, "level_req": 11, "learn_cost": 60},
	"tech_ember_lance": {"rt_value": 9, "cast": 1.0, "off_gcd": false, "level_req": 13, "learn_cost": 90},
	"tech_mana_tap": {"rt_value": 2, "cast": 0.0, "off_gcd": false, "level_req": 14, "learn_cost": 90,
		"mana_value": 1},
	"tech_sweep": {"rt_value": 3, "cast": 0.0, "off_gcd": false, "level_req": 16, "learn_cost": 120},
	"tech_daze": {"rt_value": 0, "cast": 0.0, "off_gcd": true, "level_req": 18, "learn_cost": 150},
}

## Trainer display order (Strike is never taught — every save starts with it).
const ORDER: Array[String] = [
	"tech_strike", "tech_mend", "tech_kick", "tech_guard",
	"tech_ember_lance", "tech_mana_tap", "tech_sweep", "tech_daze",
]

static func is_technique(card_id: String) -> bool:
	return DEFS.has(card_id)

static func ids() -> Array[String]:
	return ORDER.duplicate()

static func def(card_id: String) -> Dictionary:
	return DEFS.get(card_id, {}) as Dictionary

## The power a technique resolves with: `rt_value` in real time, else the card's
## printed (turn-based) `spell_power`. Non-techniques keep `printed`.
static func power(card_id: String, printed: int, realtime: bool) -> int:
	if not realtime or not DEFS.has(card_id):
		return printed
	return int(def(card_id).get("rt_value", printed))

## Real-time cast time override in seconds, or -1 to use the spell formula.
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
