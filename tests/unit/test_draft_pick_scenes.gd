## Guards the DraftPickBase hooks that SpireDraftScene and DraftDuelPickScene
## override.
##
## Both scenes share their whole card-tile layout with DraftPickBase and differ
## only in `_tier_for` (where the tier badge comes from) and `_pick_disabled`
## (co-op turn gating). GDScript resolves overrides at runtime, so a renamed or
## mistyped hook does not fail the parse check — the base's stub silently wins
## and every card renders as tier 0 "Basic" with an always-enabled Pick button.
## Nothing else in the suite instantiates these overlays, so this is the only
## place that would notice.
extends "res://tests/framework/test_case.gd"

const _SpireDraftScene = preload("res://scenes/ui/SpireDraftScene.gd")
const _DraftDuelPickScene = preload("res://scenes/ui/DraftDuelPickScene.gd")
const _SpireDraft = preload("res://game_logic/spire/SpireDraft.gd")
const _DraftDuelGen = preload("res://game_logic/net/DraftDuelGen.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")

var _spawned: Array[Node] = []


func after_each() -> void:
	for n in _spawned:
		if is_instance_valid(n):
			n.free()
	_spawned.clear()


## Parents `node` under the scene root and registers it for teardown.
##
## The unit runner is synchronous, so nothing added here actually enters the tree
## and _ready() never fires — viewport metrics stay 0 and no backdrop is built.
## That is fine for these scenes: both build their cards from setup()/setup_coop(),
## and the labels and buttons this suite inspects are created regardless of size.
func _mount(node: Node) -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	tree.root.add_child(node)
	_spawned.append(node)
	return node


## Every Label in `root`'s subtree, depth-first.
func _labels(root: Node, out: Array[Label] = []) -> Array[Label]:
	for c in root.get_children():
		if c is Label:
			out.append(c as Label)
		_labels(c, out)
	return out


func _buttons(root: Node, out: Array[Button] = []) -> Array[Button]:
	for c in root.get_children():
		if c is Button:
			out.append(c as Button)
		_buttons(c, out)
	return out


## Two card ids with different tiers, so a badge assertion can't pass vacuously.
## Returns {} when the registry is empty (never in a correctly imported project —
## test_card_registry guards the 105-card count).
func _two_tiers() -> Dictionary:
	var logic := _SpireDraft.new()
	var by_tier: Dictionary = {}
	for id: String in CardRegistry.get_all_ids():
		by_tier[logic.card_tier(id)] = id
	var tiers: Array = by_tier.keys()
	tiers.sort()
	if tiers.size() < 2:
		return {}
	return {"low": by_tier[tiers[0]], "high": by_tier[tiers[-1]],
			"low_tier": tiers[0], "high_tier": tiers[-1]}


func test_spire_draft_badges_come_from_spire_tiers() -> void:
	var picks := _two_tiers()
	assert_true(not picks.is_empty(), "card registry must expose at least two tiers")
	var scene: Node = _mount(_SpireDraftScene.new())
	scene.setup_coop(1, [str(picks["low"]), str(picks["high"])] as Array[String], true, "Ally")

	var texts: Array[String] = []
	for lbl in _labels(scene):
		texts.append(lbl.text)
	# The base stub returns 0 for every card; if the override were not wired both
	# badges would read "Basic" and the high-tier assertion below would fail.
	assert_true(texts.has(_SpireDraftScene._tier_label(int(picks["low_tier"]))),
		"low-tier badge missing from %s" % [texts])
	assert_true(texts.has(_SpireDraftScene._tier_label(int(picks["high_tier"]))),
		"high-tier badge missing from %s" % [texts])
	assert_ne(int(picks["high_tier"]), 0, "high tier must be non-zero for this to be meaningful")


func test_spire_draft_disables_picks_when_not_your_turn() -> void:
	var picks := _two_tiers()
	assert_true(not picks.is_empty(), "card registry must expose at least two tiers")
	var ids: Array[String] = [str(picks["low"]), str(picks["high"])]

	var mine: Node = _mount(_SpireDraftScene.new())
	mine.setup_coop(1, ids, true, "Ally")
	var my_buttons := _buttons(mine)
	assert_gt(my_buttons.size(), 0, "active picker should get Pick buttons")
	for b in my_buttons:
		assert_false(b.disabled, "active picker's Pick buttons must be enabled")

	var theirs: Node = _mount(_SpireDraftScene.new())
	theirs.setup_coop(1, ids, false, "Ally")
	var their_buttons := _buttons(theirs)
	assert_eq(their_buttons.size(), my_buttons.size(), "both peers render the same cards")
	for b in their_buttons:
		assert_true(b.disabled, "waiting peer's Pick buttons must be disabled")


func test_draft_duel_renders_a_round_and_finishes() -> void:
	var scene: Node = _mount(_DraftDuelPickScene.new())
	var finished: Array = []
	scene.draft_finished.connect(func(deck: Array) -> void: finished.append(deck))
	scene.setup(12345, "tok")

	var rounds: Array = _DraftDuelGen.generate_rounds(12345, _pool())
	assert_gt(rounds.size(), 0, "seeded draft should produce rounds")
	var first: Array = rounds[0]
	assert_eq(_buttons(scene).size(), first.size(), "one Pick button per option")

	# Badges must reflect DraftDuelGen tiers, not the base stub's 0.
	var texts: Array[String] = []
	for lbl in _labels(scene):
		texts.append(lbl.text)
	for cid in first:
		var tier: int = _DraftDuelGen.tier_for_template(CardRegistry.get_template(str(cid)))
		assert_true(texts.has(_DraftDuelPickScene._tier_label(tier)),
			"badge for %s (tier %d) missing from %s" % [cid, tier, texts])

	# Drive every round; the last pick must emit the assembled deck.
	for i in range(rounds.size()):
		var btns := _buttons(scene)
		assert_gt(btns.size(), 0, "round %d should still offer picks" % i)
		btns[0].pressed.emit()
	assert_eq(finished.size(), 1, "draft_finished should fire exactly once")
	assert_eq((finished[0] as Array).size(), rounds.size(), "one drafted card per round")


func _pool() -> Dictionary:
	var pool: Dictionary = {}
	for id: String in CardRegistry.get_all_ids():
		pool[id] = CardRegistry.get_template(id)
	return pool
