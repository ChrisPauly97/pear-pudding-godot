## BattleEffectsOverlay: renders one titled row per active battle modifier and
## closes cleanly, so faded banners (battlefield, weather, gambit) stay readable.
extends "res://tests/framework/test_case.gd"

const BattleEffectsOverlay = preload("res://scenes/battle/BattleEffectsOverlay.gd")

func _all_label_text(n: Node) -> String:
	var out: String = ""
	if n is Label:
		out += (n as Label).text + "\n"
	for c in n.get_children():
		out += _all_label_text(c)
	return out

func test_overlay_lists_every_entry_title_and_desc() -> void:
	var host := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var entries: Array[Dictionary] = [
		{"title": "Gambit: Iron Veil", "desc": "Enemy hero starts with 5 armor.", "color": Color.YELLOW},
		{"title": "Hero Power: Shatterwave", "desc": "Deal 3 damage to all enemies.", "color": Color.WHITE},
	]
	var closed_hits: Array[int] = [0]
	var ov: BattleEffectsOverlay = BattleEffectsOverlay.new()
	ov.present(host, entries, func() -> void: closed_hits[0] += 1)
	var text: String = _all_label_text(ov)
	assert_true(text.contains("Gambit: Iron Veil"))
	assert_true(text.contains("Enemy hero starts with 5 armor."))
	assert_true(text.contains("Hero Power: Shatterwave"))
	ov._close()
	assert_eq(closed_hits[0], 1)
	host.free()

func test_overlay_empty_state_message() -> void:
	var host := Control.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	var ov: BattleEffectsOverlay = BattleEffectsOverlay.new()
	var none: Array[Dictionary] = []
	ov.present(host, none, func() -> void: pass)
	assert_true(_all_label_text(ov).contains("No special effects"))
	host.free()
