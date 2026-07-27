## Guards the shared spell/Emergence wording table.
##
## CardViewBuilder and CardInspectOverlay used to keep private copies of these
## tables behind a "keep both in sync" comment, and had drifted on
## deal_damage_single. Now both read SpellEffectLabels, so the remaining failure
## mode is a card shipping an effect id the table has no entry for: the lookup
## falls back to the raw id and the player sees "apply_poison_all" on the card
## face instead of a sentence. Nothing would otherwise catch that.
extends "res://tests/framework/test_case.gd"

const SpellEffectLabels = preload("res://game_logic/battle/SpellEffectLabels.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")


func test_every_card_spell_effect_has_a_label() -> void:
	var missing: Array[String] = []
	var seen: int = 0
	for id: String in CardRegistry.get_all_ids():
		var tmpl: Dictionary = CardRegistry.get_template(id)
		var effect: String = str(tmpl.get("spell_effect", ""))
		if effect == "":
			continue
		seen += 1
		if not SpellEffectLabels.SPELL.has(effect) and not missing.has(effect):
			missing.append(effect)
	assert_gt(seen, 0, "the registry should contain spell cards for this to check")
	assert_eq(missing, [] as Array[String],
		"spell effects used by cards but missing from SpellEffectLabels.SPELL")


func test_every_card_emergence_effect_has_a_label() -> void:
	var missing: Array[String] = []
	var seen: int = 0
	for id: String in CardRegistry.get_all_ids():
		var tmpl: Dictionary = CardRegistry.get_template(id)
		var effect: String = str(tmpl.get("emergence_effect", ""))
		if effect == "":
			continue
		seen += 1
		if not SpellEffectLabels.EMERGENCE.has(effect) and not missing.has(effect):
			missing.append(effect)
	assert_gt(seen, 0, "the registry should contain Emergence cards for this to check")
	assert_eq(missing, [] as Array[String],
		"Emergence effects used by cards but missing from SpellEffectLabels.EMERGENCE")


func test_power_placeholder_is_substituted() -> void:
	assert_eq(SpellEffectLabels.spell("draw_card", 2), "Draw 2 card(s)")
	assert_eq(SpellEffectLabels.emergence("emergence_draw", 3), "Emergence: Draw 3 card(s)")


func test_unknown_effect_falls_back_to_its_id() -> void:
	# Visible-but-ugly beats blank: a missing label should be obvious in play.
	assert_eq(SpellEffectLabels.spell("not_a_real_effect", 1), "not_a_real_effect")
	assert_eq(SpellEffectLabels.emergence("not_a_real_effect", 1), "not_a_real_effect")


func test_no_label_leaves_an_unsubstituted_placeholder() -> void:
	# A "[power]" surviving into displayed text means the entry used the wrong
	# placeholder spelling.
	for effect: String in SpellEffectLabels.SPELL:
		assert_false(SpellEffectLabels.spell(effect, 7).contains("[power]"),
			"SPELL[%s] still shows a placeholder after substitution" % effect)
	for effect: String in SpellEffectLabels.EMERGENCE:
		assert_false(SpellEffectLabels.emergence(effect, 7).contains("[power]"),
			"EMERGENCE[%s] still shows a placeholder after substitution" % effect)
