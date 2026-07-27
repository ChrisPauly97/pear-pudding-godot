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
const _WorldScene = preload("res://scenes/world/WorldScene.gd")

## The order both chains must follow, read from WorldScene.INTERACT_PRIORITY at
## runtime so the constant is the single source of truth rather than a copy.

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


## Both chains must follow WorldScene.INTERACT_PRIORITY exactly. Before this was
## enforced they had silently drifted apart, so an enemy and a door in range gave
## an "ATTACK" prompt but a door on press.
func test_prompt_label_follows_the_priority_constant() -> void:
	var want: Array[String] = []
	want.assign(_WorldScene.INTERACT_PRIORITY)
	assert_eq(_probe_order("_interact_prompt_label"), want,
		"_interact_prompt_label no longer probes in WorldScene.INTERACT_PRIORITY order")


func test_handle_interact_follows_the_priority_constant() -> void:
	var want: Array[String] = []
	want.assign(_WorldScene.INTERACT_PRIORITY)
	var simple: Array[String] = _probe_order("_try_simple_interaction")
	assert_eq(_probe_order("_handle_interact", {"_try_simple_interaction": simple}), want,
		"_handle_interact no longer probes in WorldScene.INTERACT_PRIORITY order")


## Neither chain may gain or lose an interactable without the other.
## Hostile entities must stay at the bottom: the gameplay rule is that anything
## peaceful in reach beats a fight.
func test_hostile_interactables_are_probed_last() -> void:
	var hostile: Array[String] = ["enemy", "scout_ambush", "blight_heart"]
	var order: Array[String] = []
	order.assign(_WorldScene.INTERACT_PRIORITY)
	var first_hostile: int = order.size()
	for i in range(order.size()):
		if hostile.has(order[i]):
			first_hostile = i
			break
	for i in range(first_hostile, order.size()):
		assert_true(hostile.has(order[i]),
			"'%s' is peaceful but is probed after a hostile entity — everything "
			% order[i] + "peaceful must outrank every hostile one")
