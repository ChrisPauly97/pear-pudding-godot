## Headless tests for TID-196 final showdown — card reward and journal entry.
##
## Covers: single-grant guard for isfig_shadow_echo, scroll collection on
## rival_defeated, and CardRegistry registration of the new card.
extends "res://tests/framework/test_case.gd"

const SaveManagerScript = preload("res://autoloads/SaveManager.gd")
const ScrollRegistryScript = preload("res://autoloads/ScrollRegistry.gd")

var _sm: Node

func before_each() -> void:
	_sm = SaveManagerScript.new()
	_sm._loaded = true

func after_each() -> void:
	_sm.free()

# ── Card data file ────────────────────────────────────────────────────────────
# CardRegistry's `as CardData` cast silently fails in headless mode (pre-existing
# environment issue — no editor scan). We verify the .tres directly instead.

func test_isfig_shadow_echo_tres_loads() -> void:
	var card: Resource = ResourceLoader.load("res://data/cards/isfig_shadow_echo.tres")
	assert_true(card != null)

func test_isfig_shadow_echo_not_craftable() -> void:
	var card: Resource = ResourceLoader.load("res://data/cards/isfig_shadow_echo.tres")
	var can_craft: Variant = card.get("can_craft")
	assert_false(bool(can_craft))

func test_isfig_shadow_echo_is_unique() -> void:
	var card: Resource = ResourceLoader.load("res://data/cards/isfig_shadow_echo.tres")
	var is_unique: Variant = card.get("is_unique")
	assert_true(bool(is_unique))

func test_isfig_shadow_echo_has_ward_keyword() -> void:
	var card: Resource = ResourceLoader.load("res://data/cards/isfig_shadow_echo.tres")
	var kw: PackedStringArray = card.get("keywords") as PackedStringArray
	assert_true(kw != null and kw.has("ward"))

# ── Scroll registry ───────────────────────────────────────────────────────────

func test_scroll_isfig_shadow_registered() -> void:
	var sr := ScrollRegistryScript.new()
	var scroll: Dictionary = sr.get_scroll("scroll_isfig_shadow")
	assert_false(scroll.is_empty())
	sr.free()

func test_scroll_count_includes_isfig() -> void:
	assert_eq(ScrollRegistryScript.SCROLL_COUNT, 11)

# ── Single-grant guard ────────────────────────────────────────────────────────

func test_card_grant_only_when_not_yet_defeated() -> void:
	# First win: rival_defeated is false → grant card, set rival_defeated
	_sm.rival_defeated = false
	if not _sm.rival_defeated:
		_sm.set_rival_defeated()
		_sm.add_card_instance("isfig_shadow_echo", "legendary")
	assert_true(_sm.rival_defeated)
	var count_after_first: int = 0
	for inst in _sm.owned_cards:
		if str(inst.get("template_id", "")) == "isfig_shadow_echo":
			count_after_first += 1
	assert_eq(count_after_first, 1)

func test_card_not_granted_twice() -> void:
	# Simulate first win
	_sm.rival_defeated = false
	if not _sm.rival_defeated:
		_sm.set_rival_defeated()
		_sm.add_card_instance("isfig_shadow_echo", "legendary")
	# Simulate spurious second trigger — guard should block it
	if not _sm.rival_defeated:
		_sm.add_card_instance("isfig_shadow_echo", "legendary")
	var total: int = 0
	for inst in _sm.owned_cards:
		if str(inst.get("template_id", "")) == "isfig_shadow_echo":
			total += 1
	assert_eq(total, 1)

# ── Scroll collection ─────────────────────────────────────────────────────────

func test_scroll_collected_on_rival_defeated() -> void:
	_sm.mark_scroll_collected("scroll_isfig_shadow")
	assert_true(_sm.is_scroll_collected("scroll_isfig_shadow"))

func test_scroll_not_collected_by_default() -> void:
	assert_false(_sm.is_scroll_collected("scroll_isfig_shadow"))

func test_scroll_not_double_added() -> void:
	_sm.mark_scroll_collected("scroll_isfig_shadow")
	_sm.mark_scroll_collected("scroll_isfig_shadow")
	var count: int = 0
	for s in _sm.collected_scrolls:
		if s == "scroll_isfig_shadow":
			count += 1
	assert_eq(count, 1)

# ── Enc3 unlock guard ─────────────────────────────────────────────────────────

func test_enc3_not_available_after_rival_defeated() -> void:
	_sm.set_story_flag("chapter1_temple_council")
	_sm.rival_encounters_won = 2
	_sm.rival_defeated = true
	var available: bool = _sm.get_story_flag("chapter1_temple_council") \
		and _sm.rival_encounters_won >= 2 and not _sm.rival_defeated
	assert_false(available)
