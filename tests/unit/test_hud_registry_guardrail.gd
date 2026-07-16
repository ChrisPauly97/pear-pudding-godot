## Anti-clutter regression guard (GID-107 / TID-398).
##
## WorldScene.gd historically grew ~39 individually-positioned HUD Button.new()
## call sites (see GID-107 goal.md) because there was no shared placement
## primitive — every multiplayer/social task since GID-081 added one more button
## with a hand-picked Vector2. TID-394-397 built WorldHUD's zone/action-registry
## API and migrated the always-on and proximity-gated buttons onto it. This test
## is the guardrail that keeps a future feature from silently reintroducing the
## same clutter: any Button added directly to WorldScene's `_hud` CanvasLayer
## (bypassing the registry) must be an already-reviewed, explicitly allow-listed
## exception.
##
## Static source-text scan, not live scene-tree introspection — WorldScene has
## heavy autoload/tree dependencies unsuited to headless unit instantiation, so
## this mirrors test_card_registry.gd's precedent: a simple, reliable text-level
## assertion rather than a full parse.
extends "res://tests/framework/test_case.gd"

const _WORLD_SCENE_PATH := "res://scenes/world/WorldScene.gd"
const _WORLD_HUD_PATH := "res://scenes/world/WorldHUD.gd"

## Button-typed instance vars still added directly to `_hud` rather than through
## WorldHUD.register_action() / get_zone_container(). Each entry here is a
## reviewed, pre-existing exception (see docs/agent/ui-and-scene-management.md
## "HUD Action Registry & Party Panel" and the backlog items below) — adding a
## NEW entry to silence this test is a signal to first check whether the new
## button should go through the registry instead.
const _ALLOWED_DIRECT_HUD_CHILDREN: Array[String] = [
	"_auction_btn",       # GID-102/TID-378; predates GID-107's scope — see BID-042
	"_chat_send_btn",     # TID-397 deliberately left in place: separate free-text
	                       # row, not one of the three social-strip trigger buttons
	"_ranked_toggle_btn", # defensive fallback only; primary path is zone-registered
	                       # (needs `.toggled`, not `.pressed` — see _ensure_challenge_button)
	"_ping_btn",           # defensive fallback only; primary path is zone-registered
	                       # (needs `.toggled`, not `.pressed` — see _ensure_social_buttons)
]
# GID-115 / TID-433: _siege_btn and _tournament_btn were removed entirely (their
# triggers moved to the Party panel — see WorldScene._open_party_panel and
# PartyPanel.gd's show_siege/show_tournament); _draft_duel_btn now goes through
# WorldHUD.register_action() like _challenge_btn. None are direct _hud children
# anymore, so none belong in the allow-list above.

var _world_scene_src: String = ""
var _world_hud_src: String = ""


func before_all() -> void:
	_world_scene_src = _read_file(_WORLD_SCENE_PATH)
	_world_hud_src = _read_file(_WORLD_HUD_PATH)


func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var text: String = f.get_as_text()
	f.close()
	return text


func test_source_files_readable() -> void:
	assert_false(_world_scene_src.is_empty(), "could not read " + _WORLD_SCENE_PATH)
	assert_false(_world_hud_src.is_empty(), "could not read " + _WORLD_HUD_PATH)


func test_world_hud_exposes_registry_api() -> void:
	assert_has(_world_hud_src, "func register_action(")
	assert_has(_world_hud_src, "func unregister_action(")
	assert_has(_world_hud_src, "func get_zone_container(")


## Every `var _foo: Button` declaration in WorldScene.gd, so the next check can
## tell a Button-typed instance var apart from a Label/Panel/LineEdit one (only
## buttons are the HUD-clutter concern this guardrail exists for).
func _button_var_names(src: String) -> Array[String]:
	var re := RegEx.new()
	re.compile("var (_\\w+)\\s*:\\s*Button\\b")
	var names: Array[String] = []
	for m in re.search_all(src):
		var n: String = m.get_string(1)
		if not names.has(n):
			names.append(n)
	return names


func test_no_unreviewed_direct_hud_button_children() -> void:
	if _world_scene_src.is_empty():
		return  # already reported by test_source_files_readable
	var button_vars: Array[String] = _button_var_names(_world_scene_src)
	assert_gt(button_vars.size(), 0, "expected to find at least one 'var _x: Button' declaration")

	var re := RegEx.new()
	re.compile("_hud\\.add_child\\((_\\w+)\\)")
	var offenders: Array[String] = []
	for m in re.search_all(_world_scene_src):
		var ident: String = m.get_string(1)
		if not button_vars.has(ident):
			continue  # not a Button (e.g. a Label banner, or a locally-scoped overlay/panel)
		if _ALLOWED_DIRECT_HUD_CHILDREN.has(ident):
			continue
		if not offenders.has(ident):
			offenders.append(ident)

	assert_true(offenders.is_empty(),
		"New unreviewed _hud.add_child(<Button>) call(s): %s — route new HUD buttons through WorldHUD.register_action() (see docs/agent/ui-and-scene-management.md 'HUD Action Registry & Party Panel'), or add a reviewed entry to _ALLOWED_DIRECT_HUD_CHILDREN in this test if it's a legitimate exception." % [offenders])
