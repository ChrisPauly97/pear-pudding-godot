## Unit tests for the magic type registry (GID-127).
##
## MagicTypes is the single source of truth for four types, eight branches, their
## colours and the cross-magic currency economy. Nothing at runtime fails loudly
## when those tables drift — a branch listed under a type but missing a colour
## renders white, and a skill whose magic_branch matches no branch simply never
## appears in any tab. These tests are what makes that drift visible.
extends "res://tests/framework/test_case.gd"

const MagicTypes    = preload("res://game_logic/MagicTypes.gd")
const SkillRegistry = preload("res://autoloads/SkillRegistry.gd")
const SkillData     = preload("res://data/SkillData.gd")
const CardRegistry  = preload("res://autoloads/CardRegistry.gd")

const _CURRENCIES: Array[String] = ["corruption", "redemption"]

# ---------------------------------------------------------------------------
# 1. Table shape
# ---------------------------------------------------------------------------

func test_four_magic_types_declared() -> void:
	assert_eq(MagicTypes.all_types().size(), 4)

func test_every_type_is_fully_populated() -> void:
	for mt: String in MagicTypes.all_types():
		assert_true(MagicTypes.display_name(mt) != "", "%s has no display name" % mt)
		assert_true(MagicTypes.tagline(mt) != "", "%s has no tagline" % mt)
		assert_eq(MagicTypes.branches_for(mt).size(), 2, "%s does not have 2 branches" % mt)
		assert_true(_CURRENCIES.has(MagicTypes.cross_currency(mt)),
			"%s has an unknown cross currency" % mt)

func test_is_valid_type_rejects_unknown() -> void:
	assert_true(MagicTypes.is_valid_type("verdant"))
	assert_false(MagicTypes.is_valid_type(""))
	assert_false(MagicTypes.is_valid_type("catalyst"))

# ---------------------------------------------------------------------------
# 2. Branch / colour drift — checked in both directions
# ---------------------------------------------------------------------------

func test_every_branch_has_a_ui_and_rune_colour() -> void:
	for mt: String in MagicTypes.all_types():
		for b: String in MagicTypes.branches_for(mt):
			assert_true(MagicTypes.BRANCH_COLORS.has(b), "branch %s has no BRANCH_COLORS entry" % b)
			assert_true(MagicTypes.RUNE_COLORS.has(b), "branch %s has no RUNE_COLORS entry" % b)

func test_every_colour_entry_belongs_to_a_type() -> void:
	for b in MagicTypes.BRANCH_COLORS.keys():
		assert_true(MagicTypes.type_for_branch(str(b)) != "",
			"BRANCH_COLORS has %s, which no type claims" % b)
	for b in MagicTypes.RUNE_COLORS.keys():
		assert_true(MagicTypes.type_for_branch(str(b)) != "",
			"RUNE_COLORS has %s, which no type claims" % b)

func test_branches_are_not_shared_between_types() -> void:
	var seen: Dictionary = {}
	for mt: String in MagicTypes.all_types():
		for b: String in MagicTypes.branches_for(mt):
			assert_false(seen.has(b), "branch %s is claimed by two types" % b)
			seen[b] = mt

func test_type_for_branch_round_trips() -> void:
	for mt: String in MagicTypes.all_types():
		for b: String in MagicTypes.branches_for(mt):
			assert_eq(MagicTypes.type_for_branch(b), mt)

func test_type_for_branch_returns_empty_for_unknown() -> void:
	assert_eq(MagicTypes.type_for_branch("catalyst"), "")
	assert_eq(MagicTypes.type_for_branch(""), "")

# ---------------------------------------------------------------------------
# 3. Cross-magic currency economy
# ---------------------------------------------------------------------------

func test_each_type_has_exactly_one_signature_branch() -> void:
	for mt: String in MagicTypes.all_types():
		var signature: int = 0
		for b: String in MagicTypes.branches_for(mt):
			if MagicTypes.CURRENCY_BRANCHES.has(b):
				signature += 1
		assert_eq(signature, 1, "%s does not have exactly 1 signature branch" % mt)

func test_signature_branch_earns_its_own_types_currency() -> void:
	for b: String in MagicTypes.CURRENCY_BRANCHES:
		var mt: String = MagicTypes.type_for_branch(b)
		assert_eq(MagicTypes.currency_for_branch(b), MagicTypes.cross_currency(mt))

func test_non_signature_branch_earns_nothing() -> void:
	assert_eq(MagicTypes.currency_for_branch("ember"), "")
	assert_eq(MagicTypes.currency_for_branch("thorn"), "")
	assert_eq(MagicTypes.currency_for_branch("catalyst"), "")

func test_cross_currency_falls_back_for_unset_type() -> void:
	# A save with magic_type == "" must still price the skill tree coherently.
	assert_true(_CURRENCIES.has(MagicTypes.cross_currency("")))

# ---------------------------------------------------------------------------
# 4. Light / Dark regression — GID-127 must not change existing saves
# ---------------------------------------------------------------------------

func test_light_and_dark_are_unchanged() -> void:
	assert_eq(MagicTypes.branches_for("light"), ["ember", "dawn"] as Array[String])
	assert_eq(MagicTypes.branches_for("dark"), ["dusk", "ash"] as Array[String])
	assert_eq(MagicTypes.cross_currency("light"), "corruption")
	assert_eq(MagicTypes.cross_currency("dark"), "redemption")
	assert_eq(MagicTypes.currency_for_branch("dawn"), "corruption")
	assert_eq(MagicTypes.currency_for_branch("dusk"), "redemption")

# ---------------------------------------------------------------------------
# 5. Skill coverage — every branch must be playable
# ---------------------------------------------------------------------------

func test_every_branch_has_skills() -> void:
	for mt: String in MagicTypes.all_types():
		for b: String in MagicTypes.branches_for(mt):
			assert_true(SkillRegistry.get_by_branch(b).size() > 0,
				"branch %s has no skills — its tab would render empty" % b)

func test_every_branch_has_a_cross_purchasable_skill() -> void:
	# The Cross-Magic tab shows every non-home type. A branch with no alt_cost
	# skill contributes nothing to it.
	for mt: String in MagicTypes.all_types():
		for b: String in MagicTypes.branches_for(mt):
			var cross: int = 0
			for sid: String in SkillRegistry.get_by_branch(b):
				var sk: SkillData = SkillRegistry.get_skill(sid)
				if sk != null and sk.alt_cost > 0:
					cross += 1
			assert_true(cross > 0, "branch %s has no cross-purchasable skill" % b)

func test_every_skill_belongs_to_a_known_branch() -> void:
	for sid: String in SkillRegistry.get_all_ids():
		var sk: SkillData = SkillRegistry.get_skill(sid)
		assert_true(MagicTypes.type_for_branch(sk.magic_branch) != "",
			"skill %s has unknown magic_branch '%s'" % [sid, sk.magic_branch])

func test_skill_prerequisites_stay_within_their_branch() -> void:
	for sid: String in SkillRegistry.get_all_ids():
		var sk: SkillData = SkillRegistry.get_skill(sid)
		for prereq_id: String in sk.prerequisites:
			var prereq: SkillData = SkillRegistry.get_skill(prereq_id)
			assert_true(prereq != null, "skill %s requires unknown %s" % [sid, prereq_id])
			if prereq != null:
				assert_eq(prereq.magic_branch, sk.magic_branch,
					"skill %s requires %s from another branch" % [sid, prereq_id])

# ---------------------------------------------------------------------------
# 6. Card coverage — a card's branch and type must agree
# ---------------------------------------------------------------------------

func test_every_card_branch_is_known_and_matches_its_type() -> void:
	for cid: String in CardRegistry.get_all_ids():
		var tmpl: Dictionary = CardRegistry.get_template(cid)
		var branch: String = str(tmpl.get("magic_branch", ""))
		if branch == "":
			continue
		var owner_type: String = MagicTypes.type_for_branch(branch)
		assert_true(owner_type != "", "card %s has unknown magic_branch '%s'" % [cid, branch])
		# Dual-face cards carry the Light face here and a dark_magic_type on the
		# other face, so only assert on the face the template returned.
		var declared: String = str(tmpl.get("magic_type", ""))
		if owner_type != "" and declared != "" and not bool(tmpl.get("dual_card_id", "") != ""):
			assert_eq(declared, owner_type,
				"card %s is branch %s (%s) but declares magic_type %s" % [cid, branch, owner_type, declared])

func get_suite_name() -> String:
	return "MagicTypes"
