## The gear curve (GID-187 / TID-789): item bands by level, what stats each band's items may
## carry, and the stat budget a hand-made item must fit.
##
## Items are authored (fixed stats, user 2026-10-11). Each item has an item level, a slot and a
## rarity; its stat ratings, weighted by `STAT_COST`, must come to `budget(item_level, slot,
## rarity)` within `BUDGET_TOLERANCE`. `validate()` reports what is off, and
## `tests/unit/test_gear_curve.gd` runs it over every registered item so the catalogue can't drift.
##
## Pure: no autoloads, no scene tree.
extends RefCounted

const _GearStats = preload("res://game_logic/items/GearStats.gd")
const _WeaponData = preload("res://data/WeaponData.gd")

## [id, min level, max level, max secondary stats, school / special secondaries allowed].
const BANDS: Array = [
	["basic", 1, 9, 0, false],
	["fine", 10, 19, 1, false],
	["superior", 20, 34, 2, true],
	["heroic", 35, 49, 3, true],
	["legendary", 50, 60, 3, true],
]
## An item's main stat; every item with stats has exactly one.
const PRIMARY: Array[String] = ["stamina", "armor", "intellect", "attack_power", "spell_power"]
## Card-boost secondaries open from Fine.
const SECONDARY: Array[String] = ["spell_crit", "phys_crit", "haste", "spirit", "command"]
## Opened from Superior (bands with the flag set): school stats and the special secondaries.
const ADVANCED: Array[String] = ["leech", "block", "mastery", "resist"]
## Budget points one rating point costs.
const STAT_COST: Dictionary = {
	"stamina": 1.0, "armor": 2.0, "intellect": 6.0, "attack_power": 1.0, "spell_power": 1.0,
	"spell_crit": 1.0, "phys_crit": 1.0, "haste": 1.0, "spirit": 1.0, "command": 1.0,
	"leech": 1.5, "block": 1.5, "mastery": 0.8, "resist": 0.6,
}
## Share of a full item's budget by slot.
const SLOT_WEIGHT: Dictionary = {
	"weapon": 1.0, "armor": 1.0, "helmet": 0.8, "shoulders": 0.7, "boots": 0.6, "offhand": 0.6, "ring": 0.5,
	"trinket": 0.5,
}
const RARITY_BUDGET: Dictionary = {"common": 1.0, "rare": 1.15, "epic": 1.3, "legendary": 1.5}
## budget = slot weight × (BUDGET_BASE + BUDGET_PER_ILVL × item level) × rarity.
const BUDGET_BASE: float = 6.0
const BUDGET_PER_ILVL: float = 1.2
const BUDGET_TOLERANCE: float = 0.2
## Battle effects that are a weapon mechanic rather than stats (deck cards, off-hand swing): such an
## item's stats only have a ceiling.
const MECHANIC_EFFECTS: Array[String] = ["deck_inject", "offhand_atk"]

## The band row for an item level (clamped to 1..60).
static func band_for_level(item_level: int) -> Array:
	var lv: int = clampi(item_level, 1, 60)
	for b: Array in BANDS:
		if lv >= int(b[1]) and lv <= int(b[2]):
			return b
	return BANDS[0]

static func band_row(band_id: String) -> Array:
	for b: Array in BANDS:
		if str(b[0]) == band_id:
			return b
	return []

## "mastery:dark" → "mastery"; plain ids unchanged.
static func stat_kind(stat_id: String) -> String:
	return stat_id.get_slice(":", 0)

static func slot_of(w: _WeaponData) -> String:
	return w.slot if w.slot != "" else "weapon"

static func budget(item_level: int, slot: String, rarity: String = "common") -> float:
	return float(SLOT_WEIGHT.get(slot, 0.5)) * (BUDGET_BASE + BUDGET_PER_ILVL * float(item_level)) \
			* float(RARITY_BUDGET.get(rarity, 1.0))

## Budget points `stats` ({stat id: rating}) cost.
static func cost(stats: Dictionary) -> float:
	var total: float = 0.0
	for k: Variant in stats:
		total += float(STAT_COST.get(stat_kind(str(k)), 1.0)) * float(stats[k])
	return total

## Problems with an authored item (empty = on the curve).
static func validate(w: _WeaponData) -> Array[String]:
	var out: Array[String] = []
	var band: Array = band_row(w.band)
	if band.is_empty():
		return ["%s: unknown band '%s'" % [w.id, w.band]]
	if w.item_level < int(band[1]) or w.item_level > int(band[2]):
		out.append("%s: item level %d outside band %s (%d-%d)" % [w.id, w.item_level, w.band, band[1], band[2]])
	if w.level_req < 1 or w.level_req > w.item_level:
		out.append("%s: level_req %d not in 1..item level %d" % [w.id, w.level_req, w.item_level])
	if not RARITY_BUDGET.has(w.rarity):
		out.append("%s: unknown rarity '%s'" % [w.id, w.rarity])
	var primaries: int = 0
	var secondaries: int = 0
	for k: Variant in w.stats:
		var id: String = str(k)
		var kind: String = stat_kind(id)
		if not _GearStats.is_stat(id):
			out.append("%s: unknown stat '%s'" % [w.id, id])
		elif PRIMARY.has(kind):
			primaries += 1
		elif SECONDARY.has(kind) or (ADVANCED.has(kind) and bool(band[4])):
			secondaries += 1
		else:
			out.append("%s: %s not allowed in band %s" % [w.id, id, w.band])
	var mechanic: bool = MECHANIC_EFFECTS.has(w.battle_effect_type)
	if not w.stats.is_empty() and primaries != 1:
		out.append("%s: needs exactly one primary stat (has %d)" % [w.id, primaries])
	if secondaries > int(band[3]):
		out.append("%s: %d secondary stats, band %s allows %d" % [w.id, secondaries, w.band, band[3]])
	if w.stats.is_empty() and not mechanic:
		out.append("%s: no stats and no weapon mechanic" % w.id)
	var b: float = budget(w.item_level, slot_of(w), w.rarity)
	var c: float = cost(w.stats)
	if c > b * (1.0 + BUDGET_TOLERANCE) + 0.001:
		out.append("%s: stats cost %.1f over budget %.1f" % [w.id, c, b])
	if not mechanic and c < b * (1.0 - BUDGET_TOLERANCE) - 0.001:
		out.append("%s: stats cost %.1f under budget %.1f" % [w.id, c, b])
	return out
