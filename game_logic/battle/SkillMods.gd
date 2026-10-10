## Skill-tree card modifiers (GID-179 / TID-733): what the player's unlocked
## nodes do to each card in a real-time fight — recycle, cost, cast time,
## power, crit chance and on-crit triggers. Pure, built once per fight from the
## unlocked skill ids and held on `PlayerState.skill_mods` (null in turn-based
## fights). Vocabulary and node table: combat-model.md → "Skill tree modifies cards".
extends RefCounted

const SkillData = preload("res://data/SkillData.gd")
const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const TechniqueDefs = preload("res://game_logic/battle/TechniqueDefs.gd")

const DAMAGE_EFFECTS: Array[String] = [
	"deal_damage_single", "smite_draw", "deal_damage_all", "deal_damage_all_full", "deal_damage_random",
	"deal_damage_hero", "drain_hero", "lifesteal_hit", "mana_tap",
]
const HEAL_EFFECTS: Array[String] = ["heal_hero", "heal_single", "heal_all"]

## [{type, value, filter}] for every modifier node (grant_technique nodes skipped).
var _mods: Array[Dictionary] = []

## Adds every modifier node among `skill_ids` (SkillRegistry ids).
func add_skills(skill_ids: Array) -> void:
	for v: Variant in skill_ids:
		var sk: SkillData = SkillRegistry.get_skill(str(v))
		if sk != null and (sk.effect_type.begins_with("mod_") or sk.effect_type.begins_with("on_crit_")):
			add(sk.effect_type, sk.effect_value, sk.filter)

func add(effect_type: String, value: int, filter: String) -> void:
	_mods.append({"type": effect_type, "value": value, "filter": filter})

func is_empty() -> bool:
	return _mods.is_empty()

## Does `card` fall under `filter` (a branch, spell / technique / ally / damage /
## heal / any, or a card id)?
static func matches(card: CardInstance, filter: String) -> bool:
	match filter:
		"", "any":
			return true
		"spell":
			return card.card_class == "spell"
		"technique":
			return TechniqueDefs.is_technique(card.template_id)
		"ally":
			return card.card_class != "spell"
		"damage":
			return card.card_class == "spell" and DAMAGE_EFFECTS.has(card.spell_effect)
		"heal":
			return card.card_class == "spell" and HEAL_EFFECTS.has(card.spell_effect)
	return card.magic_branch == filter or card.template_id == filter

## Summed `value` of every `effect_type` node that matches `card`.
func total(effect_type: String, card: CardInstance) -> int:
	var sum: int = 0
	for m: Dictionary in _mods:
		if str(m["type"]) == effect_type and matches(card, str(m["filter"])):
			sum += int(m["value"])
	return sum

func recycle_mult(card: CardInstance) -> float:
	return maxf(0.2, 1.0 - float(total("mod_recycle", card)) / 100.0)

func cast_mult(card: CardInstance) -> float:
	return maxf(0.0, 1.0 - float(total("mod_cast", card)) / 100.0)

## The card's cost in mana units after `mod_cost` nodes: never below 1 unless
## it was printed at 0.
func cost_for(card: CardInstance) -> int:
	var cut: int = total("mod_cost", card)
	if cut <= 0:
		return card.cost
	return maxi(mini(card.cost, 1), card.cost - cut)

## `power` after `mod_power` nodes, rounded (no +1 floor: on Strike's 2 that
## would turn +15% into +50%).
func power_for(card: CardInstance, power: int) -> int:
	var pct: int = total("mod_power", card)
	if pct <= 0 or power <= 0:
		return power
	return roundi(float(power) * (1.0 + float(pct) / 100.0))

## Extra crit chance (0..1) from `mod_crit` nodes.
func crit_bonus(card: CardInstance) -> float:
	return float(total("mod_crit", card)) / 100.0

## A card that crit: does it make the next card instant?
func instant_on_crit(card: CardInstance) -> bool:
	for m: Dictionary in _mods:
		if str(m["type"]) == "on_crit_instant" and matches(card, str(m["filter"])):
			return true
	return false

## A card that crit: mana units refunded.
func refund_on_crit(card: CardInstance) -> int:
	return total("on_crit_refund", card)

## GID-181 / TID-754: summed `school_power` / `school_resist` node values per school. A node's
## filter is the school and its value a percent. These are not card mods (`add_skills` skips
## them), and they apply in turn-based fights too, so they are read from the unlocked ids.
static func school_nodes(skill_ids: Array, effect_type: String) -> Dictionary:
	var out: Dictionary = {}
	for v: Variant in skill_ids:
		var sk: SkillData = SkillRegistry.get_skill(str(v))
		if sk != null and sk.effect_type == effect_type:
			out[sk.filter] = int(out.get(sk.filter, 0)) + sk.effect_value
	return out

## Can `card` crit at all (a damage or heal spell)?
static func can_crit(card: CardInstance) -> bool:
	return card.card_class == "spell" and (DAMAGE_EFFECTS.has(card.spell_effect)
			or HEAL_EFFECTS.has(card.spell_effect))
