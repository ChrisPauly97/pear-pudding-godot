## Gear tooltip text (GID-187 / TID-792): pure formatting of an item's stat lines, band, level
## requirement and comparison deltas for CharacterScene (details, compare, character sheet) and
## BlacksmithScene.
##
## A stat line shows the rating and what it gives at the wearer's level: "+12 Haste (3.1 %)" for a
## percent stat (`GearStats.pct`), "+6 Stamina (+6 max HP)" for a flat one. Deltas are in the same
## display units (% points for percent stats, points for flat ones) so a colour can be picked from
## the sign. Callers colour the lines (rarity, red when the level requirement is not met).
##
## Pure: no autoloads, no scene tree.
extends RefCounted

const _GearStats = preload("res://game_logic/items/GearStats.gd")
const _UpgradeDefs = preload("res://game_logic/UpgradeDefs.gd")
const _WeaponData = preload("res://data/WeaponData.gd")
const _CombatTuning = preload("res://game_logic/battle/CombatTuning.gd")

## What one point of a flat stat does on the hero.
const FLAT_EFFECT: Dictionary = {"stamina": "max HP", "armor": "armor", "intellect": "max mana"}

## Display label for a stat id, school stats with the school in brackets ("Mastery (Dark)").
static func stat_label(stat_id: String) -> String:
	var kind: String = stat_id.get_slice(":", 0)
	var label: String = str(_GearStats.LABELS.get(kind, kind))
	if stat_id.contains(":"):
		label += " (%s)" % stat_id.get_slice(":", 1).capitalize()
	return label

## What `rating` of a stat is worth at `player_level`: points for a flat stat, % (0..100) for a
## percent stat (capped by `GearStats.pct`).
static func value_at(stat_id: String, rating: float, player_level: int, tune: _CombatTuning = null) -> float:
	if _GearStats.FLAT.has(stat_id):
		return rating
	return _GearStats.pct(rating, player_level, tune) * 100.0

## One stat line: "+12 Haste (3.1 %)", "+6 Stamina (+6 max HP)".
static func stat_line(stat_id: String, rating: float, player_level: int, tune: _CombatTuning = null) -> String:
	var r: int = roundi(rating)
	if _GearStats.FLAT.has(stat_id):
		return "+%d %s (+%d %s)" % [r, stat_label(stat_id), r, str(FLAT_EFFECT.get(stat_id, "points"))]
	return "+%d %s (%.1f %%)" % [r, stat_label(stat_id), value_at(stat_id, rating, player_level, tune)]

## Stat ids in display order: flat stats, then percent stats, then anything else alphabetically.
static func ordered_ids(d: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in _GearStats.FLAT:
		if d.has(id):
			out.append(id)
	for id: String in _GearStats.PERCENT:
		if d.has(id):
			out.append(id)
	var rest: Array[String] = []
	for k: Variant in d.keys():
		if not out.has(str(k)):
			rest.append(str(k))
	rest.sort()
	out.append_array(rest)
	return out

## Everything a tooltip shows for `w` at `upgrade_level`, worn by a `player_level` hero.
## `rarity` overrides the authored rarity (a rolled instance); `mult` is the roll multiplier for the
## legacy battle effect. Keys: name, rarity, band_line, level_req, level_ok, requires_line,
## stat_lines (Array[String]), stats (stat → rating), mechanic_line, lines (every line in order).
static func build(w: _WeaponData, upgrade_level: int, player_level: int, rarity: String = "",
		mult: float = 1.0, tune: _CombatTuning = null) -> Dictionary:
	var out: Dictionary = {}
	if w == null:
		return out
	var lvl: int = maxi(0, upgrade_level)
	var item_name: String = w.display_name + (" +%d" % lvl if lvl > 0 else "")
	var band_line: String = "%s · item level %d" % [w.band.capitalize(), w.item_level]
	var req: int = w.level_req
	var ok: bool = player_level >= req
	var requires_line: String = "Requires level %d" % req
	if not ok:
		requires_line = "Requires level %d (you are level %d)" % [req, player_level]

	var ratings: Dictionary = _UpgradeDefs.scaled_stats(w, lvl)
	var stats: Dictionary = {}
	var stat_lines: Array[String] = []
	for id: String in ordered_ids(ratings):
		var r: float = float(ratings[id])
		if r <= 0.0:
			continue
		stats[id] = r
		stat_lines.append(stat_line(id, r, player_level, tune))

	var mechanic_line: String = ""
	if w.battle_effect_type != "":
		mechanic_line = _UpgradeDefs.get_display_string(w, lvl, mult)

	var lines: Array[String] = [band_line, requires_line]
	lines.append_array(stat_lines)
	if mechanic_line != "":
		lines.append(mechanic_line)

	out["name"] = item_name
	out["rarity"] = rarity if rarity != "" else w.rarity
	out["band_line"] = band_line
	out["level_req"] = req
	out["level_ok"] = ok
	out["requires_line"] = requires_line
	out["stat_lines"] = stat_lines
	out["stats"] = stats
	out["mechanic_line"] = mechanic_line
	out["lines"] = lines
	return out

## One-line stat summary for compact rows: "+12 Stamina (+12 max HP), +3 Haste (0.9 %)", with the
## legacy mechanic line after it when the item has one.
static func summary(w: _WeaponData, upgrade_level: int, player_level: int, mult: float = 1.0) -> String:
	var tip: Dictionary = build(w, upgrade_level, player_level, "", mult)
	if tip.is_empty():
		return ""
	var parts: PackedStringArray = []
	for line: String in tip["stat_lines"]:
		parts.append(line)
	if str(tip["mechanic_line"]) != "":
		parts.append(str(tip["mechanic_line"]))
	return ", ".join(parts)

## Display values of an item's stats at `level` (points for flat, % points for percent).
static func values(w: _WeaponData, upgrade_level: int, player_level: int, tune: _CombatTuning = null) -> Dictionary:
	var out: Dictionary = {}
	if w == null:
		return out
	var ratings: Dictionary = _UpgradeDefs.scaled_stats(w, upgrade_level)
	for id: String in ordered_ids(ratings):
		var r: float = float(ratings[id])
		if r > 0.0:
			out[id] = value_at(id, r, player_level, tune)
	return out

## Per-stat change from `equipped` to `candidate` at `player_level`, in display units (positive = better).
## Zero changes are left out. Either item may be null (an empty slot): then every stat is a gain.
static func compare(candidate: _WeaponData, cand_lvl: int, equipped: _WeaponData, eq_lvl: int,
		player_level: int, tune: _CombatTuning = null) -> Dictionary:
	var a: Dictionary = values(candidate, cand_lvl, player_level, tune)
	var b: Dictionary = values(equipped, eq_lvl, player_level, tune)
	var out: Dictionary = {}
	var ids: Array[String] = ordered_ids(a)
	for id: String in ordered_ids(b):
		if not ids.has(id):
			ids.append(id)
	for id: String in ids:
		var d: float = float(a.get(id, 0.0)) - float(b.get(id, 0.0))
		if absf(d) > 0.0001:
			out[id] = d
	return out

## Delta rows for a `compare` result: {"text": "+3.1 % Haste" / "-6 Stamina", "gain": bool}.
static func delta_rows(deltas: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in ordered_ids(deltas):
		var d: float = float(deltas[id])
		var text: String
		if _GearStats.FLAT.has(id):
			text = "%+d %s" % [roundi(d), stat_label(id)]
		else:
			text = "%+.1f %% %s" % [d, stat_label(id)]
		out.append({"text": text, "gain": d > 0.0})
	return out

## Character-sheet totals: every stat summed across `entries` ({"weapon": WeaponData, "level": int}
## per equipped item) at `player_level`. One stat line per stat; the % is taken of the summed rating,
## so the per-stat cap applies to the total.
static func sheet_lines(entries: Array[Dictionary], player_level: int, tune: _CombatTuning = null) -> Array[String]:
	var totals: Dictionary = {}
	for e: Dictionary in entries:
		var wd: _WeaponData = e.get("weapon", null) as _WeaponData
		if wd == null:
			continue
		var ratings: Dictionary = _UpgradeDefs.scaled_stats(wd, int(e.get("level", 0)))
		for id: String in ordered_ids(ratings):
			totals[id] = float(totals.get(id, 0.0)) + float(ratings[id])
	var out: Array[String] = []
	for id: String in ordered_ids(totals):
		var r: float = float(totals[id])
		if r > 0.0:
			out.append(stat_line(id, r, player_level, tune))
	return out
