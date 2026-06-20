# Static helpers for veteran card rank math and display names.
# No class_name — callers preload this file directly (CLAUDE.md: don't rely on class_name scan).

const IsoConst = preload("res://autoloads/IsoConst.gd")

## Returns veterancy rank (0–3) for the given kill and survival counters.
## Rank is OR-based: earned when kills >= kills_threshold OR battles_survived >= battles_threshold.
static func rank_for(kills: int, battles_survived: int) -> int:
	var ranks: Array = IsoConst.VETERANCY_RANKS
	var result: int = 0
	for i: int in range(ranks.size()):
		var entry: Dictionary = ranks[i]
		var kt: int = int(entry.get("kills_threshold", 999))
		var bt: int = int(entry.get("battles_threshold", 999))
		if kills >= kt or battles_survived >= bt:
			result = i + 1
	return result

## Returns the title string for the given rank (empty string for rank 0).
static func title_for(rank: int) -> String:
	if rank <= 0 or rank > IsoConst.VETERANCY_RANKS.size():
		return ""
	var entry: Dictionary = IsoConst.VETERANCY_RANKS[rank - 1]
	return str(entry.get("title", ""))

## Returns the total HP bonus granted at the given rank.
static func hp_bonus_for(rank: int) -> int:
	if rank <= 0 or rank > IsoConst.VETERANCY_RANKS.size():
		return 0
	var entry: Dictionary = IsoConst.VETERANCY_RANKS[rank - 1]
	return int(entry.get("hp_bonus", 0))

## Returns the total ATK bonus granted at the given rank.
static func atk_bonus_for(rank: int) -> int:
	if rank <= 0 or rank > IsoConst.VETERANCY_RANKS.size():
		return 0
	var entry: Dictionary = IsoConst.VETERANCY_RANKS[rank - 1]
	return int(entry.get("atk_bonus", 0))

## Resolves the display name for a card instance.
## Precedence: custom_name > "base_name the Title" (rank >= 1) > base_name.
static func display_name(inst: Dictionary, base_name: String) -> String:
	var custom: String = str(inst.get("custom_name", ""))
	if custom != "":
		return custom
	var kills: int = int(inst.get("kills", 0))
	var survived: int = int(inst.get("battles_survived", 0))
	var rank: int = rank_for(kills, survived)
	if rank >= 1:
		return base_name + " " + title_for(rank)
	return base_name

## Returns a chevron string for a given rank (empty string for rank 0).
static func rank_chevrons(rank: int) -> String:
	if rank <= 0:
		return ""
	var s: String = ""
	for _i: int in range(rank):
		s += "▲"
	return s
