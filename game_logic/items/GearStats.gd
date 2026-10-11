## Gear stats (GID-187 / TID-788): what an item's stat ratings do in a fight.
##
## Stats are boosts to the **cards** (spec Identity: "not a stat bar"; user, 2026-10-11): haste
## speeds draws and technique returns, spell / physical crit and power raise damage and heal
## cards, command raises Ally swings. Only Stamina and Armor (the Basic band's "health only /
## armour only" items) are plain hero stats, plus Intellect for the mana the cards cost.
##
## Items carry ratings (`{"stats": {"haste": 12, "mastery:dark": 8}}`). A percent stat converts
## at the fight's player level: `stat_rating_base * (1 + stat_rating_growth * (level - 1))` rating
## per 1 %, capped at `stat_pct_cap`, so an old item's ratings are worth less as you level
## (WoW-style). Flat stats (stamina, armor, intellect) are points. `apply()` stores the converted
## values on `PlayerState.gear`; combat code reads them with `PlayerState.gear_stat(id)`.
##
## Pure: no autoloads, no scene tree (the balance sim and `-s` tests load it).
extends RefCounted

const _CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")
const _PlayerState = preload("res://game_logic/battle/PlayerState.gd")
const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")

## Flat stats: a rating point is a point.
const FLAT: Array[String] = ["stamina", "armor", "intellect"]
## Percent stats: rating converts by level (see the header).
const PERCENT: Array[String] = [
	"spell_power", "attack_power", "spell_crit", "phys_crit", "haste", "spirit", "command", "leech", "block",
]
## Per-school stats, keyed "<kind>:<school>": mastery = + % damage of that school, resist = − % taken.
const SCHOOL_KINDS: Array[String] = ["mastery", "resist"]
## Display names for UI (TID-792).
const LABELS: Dictionary = {
	"stamina": "Stamina", "armor": "Armor", "intellect": "Intellect", "spell_power": "Spell Power",
	"attack_power": "Attack Power", "spell_crit": "Spell Crit", "phys_crit": "Physical Crit", "haste": "Haste",
	"spirit": "Spirit", "command": "Command", "leech": "Leech", "block": "Block", "mastery": "Mastery",
	"resist": "Resist",
}

## True for a stat id this table knows (flat, percent or a valid "<kind>:<school>").
static func is_stat(id: String) -> bool:
	if FLAT.has(id) or PERCENT.has(id):
		return true
	var parts: PackedStringArray = id.split(":")
	return parts.size() == 2 and SCHOOL_KINDS.has(parts[0]) and _DamageSchools.is_school(parts[1])

## Summed ratings of every item's `stats` ({stat: rating}); unknown ids and non-numbers dropped.
static func totals(items: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for item: Dictionary in items:
		var stats: Variant = item.get("stats", {})
		if not stats is Dictionary:
			continue
		for k: Variant in (stats as Dictionary):
			var v: Variant = (stats as Dictionary)[k]
			if is_stat(str(k)) and (v is int or v is float):
				out[str(k)] = float(out.get(str(k), 0.0)) + float(v)
	return out

## Rating for 1 % at `level`.
static func rating_per_pct(level: int, tune: _CombatTuning = null) -> float:
	var t: _CombatTuning = tune if tune != null else _CombatTuning.new()
	return maxf(0.01, t.get_f("stat_rating_base") * (1.0 + t.get_f("stat_rating_growth") * float(maxi(0, level - 1))))

## Fraction (0..stat_pct_cap) that `rating` of a percent stat gives at `level`.
static func pct(rating: float, level: int, tune: _CombatTuning = null) -> float:
	var t: _CombatTuning = tune if tune != null else _CombatTuning.new()
	return clampf(rating / rating_per_pct(level, t) / 100.0, 0.0, t.get_f("stat_pct_cap"))

## Converted values for `ratings` at `level`: flat stats as ints, percent and school stats as
## fractions. School stats are returned under their "<kind>:<school>" id.
static func convert_ratings(ratings: Dictionary, level: int, tune: _CombatTuning = null) -> Dictionary:
	var out: Dictionary = {}
	for k: String in ratings:
		var r: float = float(ratings[k])
		if FLAT.has(k):
			out[k] = roundi(r)
		else:
			out[k] = pct(r, level, tune)
	return out

## Applies `ratings` (from `totals`) to `player` for a fight at `level`: Stamina → max HP, Armor →
## hero armor, Intellect → bonus mana (cost units), mastery → `school_power`; every converted value
## is stored on `player.gear` for the combat hooks. Resist goes through
## `BattleSetup.school_resist_sources` (it is capped with the other sources).
static func apply(player: _PlayerState, ratings: Dictionary, level: int, tune: _CombatTuning = null) -> void:
	var conv: Dictionary = convert_ratings(ratings, level, tune)
	player.gear = conv
	var hp: int = int(conv.get("stamina", 0))
	if hp > 0:
		player.hero.max_health += hp
		player.hero.health += hp
	var armor: int = int(conv.get("armor", 0))
	if armor > 0:
		player.hero.add_armor(armor)
	player.hero.bonus_mana += maxi(0, int(conv.get("intellect", 0)))
	for k: String in conv:
		if k.begins_with("mastery:"):
			var school: String = k.get_slice(":", 1)
			player.school_power[school] = float(player.school_power.get(school, 0.0)) + float(conv[k])

## `school` → resist fraction from converted gear (`player.gear`), for `school_resist_sources`.
static func resist_sources(conv: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: String in conv:
		if k.begins_with("resist:"):
			out[k.get_slice(":", 1)] = float(conv[k])
	return out

## `amount` raised by a fraction, rounded; a positive amount never drops to 0.
static func boost(amount: int, frac: float) -> int:
	if amount <= 0 or frac <= 0.0:
		return amount
	return roundi(float(amount) * (1.0 + frac))
