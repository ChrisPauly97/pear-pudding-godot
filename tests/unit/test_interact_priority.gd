## Pins the two interaction priority orders in WorldScene.
##
## `_interact_prompt_label()` decides the verb the HUD shows; `_handle_interact()`
## decides what pressing the button actually does. They are separate probe chains,
## and they are NOT currently in the same order — e.g. with both an enemy and a
## door in range the HUD reads "ATTACK" while the button enters the door. That
## predates the co-op split and is recorded here rather than silently "fixed",
## because changing either order is a gameplay decision.
##
## The point of this test is that the orders can no longer drift unnoticed: adding
## an interactable to one chain and not the other, or inserting it at a different
## position, fails here with both lists printed.
##
## Static source scan for the same reason test_hud_registry_guardrail is one —
## WorldScene has heavy autoload/tree dependencies unsuited to a unit test.
extends "res://tests/framework/test_case.gd"

const _WORLD_SCENE_PATH := "res://scenes/world/WorldScene.gd"

## Order in which _interact_prompt_label() probes, first hit wins.
const _LABEL_ORDER: Array[String] = [
	"downed_peer", "enemy", "chest", "door", "wilderness_camp", "scout_ambush",
	"maiteln", "npc", "scroll", "shrine", "digspot", "waystone", "mailbox",
	"garden_plot", "burial_mound", "blight_heart", "mana_well",
]

## Order in which _handle_interact() (plus _try_simple_interaction, which it
## delegates the uniform "call one method" cases to) probes, first hit wins.
const _HANDLER_ORDER: Array[String] = [
	"downed_peer", "door", "enemy", "chest", "npc",
	# _try_simple_interaction's eight, spliced in at its call site:
	"scroll", "wilderness_camp", "scout_ambush", "maiteln", "shrine", "digspot",
	"burial_mound", "blight_heart",
	"mana_well", "waystone", "mailbox", "garden_plot",
]

var _src: String = ""


func before_all() -> void:
	var f := FileAccess.open(_WORLD_SCENE_PATH, FileAccess.READ)
	if f != null:
		_src = f.get_as_text()
		f.close()


## Probe names in the order one function actually reaches them at runtime. A
## call to a delegate (_try_simple_interaction) splices that delegate's probes in
## at the call site, which is not where it happens to be defined in the file.
func _probe_order(fn_name: String, delegates: Dictionary = {}) -> Array[String]:
	var out: Array[String] = []
	var re := RegEx.new()
	re.compile("_find_nearby_(\\w+)")
	var in_fn: bool = false
	for line: String in _src.split("\n"):
		if line.begins_with("func "):
			in_fn = line.begins_with("func %s(" % fn_name)
		if not in_fn:
			continue
		var code: String = line.split("#")[0]
		for d: String in delegates:
			if code.contains(d + "("):
				out.append_array(delegates[d] as Array[String])
		for m in re.search_all(code):
			out.append(m.get_string(1))
	return out


func test_source_readable() -> void:
	assert_false(_src.is_empty(), "could not read " + _WORLD_SCENE_PATH)


func test_prompt_label_probe_order_is_unchanged() -> void:
	assert_eq(_probe_order("_interact_prompt_label"), _LABEL_ORDER,
		"_interact_prompt_label's probe order changed — update _LABEL_ORDER here and "
		+ "check whether _handle_interact needs the same change")


func test_handle_interact_probe_order_is_unchanged() -> void:
	var simple: Array[String] = _probe_order("_try_simple_interaction")
	assert_eq(_probe_order("_handle_interact", {"_try_simple_interaction": simple}), _HANDLER_ORDER,
		"_handle_interact's probe order changed — update _HANDLER_ORDER here and "
		+ "check whether _interact_prompt_label needs the same change")


## Neither chain may gain or lose an interactable without the other.
func test_both_chains_cover_the_same_interactables() -> void:
	var only_label: Array[String] = []
	for n: String in _LABEL_ORDER:
		if not _HANDLER_ORDER.has(n):
			only_label.append(n)
	var only_handler: Array[String] = []
	for n: String in _HANDLER_ORDER:
		if not _LABEL_ORDER.has(n):
			only_handler.append(n)
	assert_true(only_label.is_empty(),
		"interactables the HUD prompts for but the button never handles: %s" % [only_label])
	assert_true(only_handler.is_empty(),
		"interactables the button handles but the HUD never prompts for: %s" % [only_handler])
