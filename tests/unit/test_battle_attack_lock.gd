## Regression tests for the attack input lock and lunge settle (multi-hit bug).
##
## BattleScene can't run headlessly, so the lock is guarded at source level:
## every attack goes through `_attempt_attack`, which must refuse while a
## prior action animates (`_action_busy` folds into `_can_local_act`).
extends "res://tests/framework/test_case.gd"

const BattleFx = preload("res://scenes/battle/BattleFx.gd")

func _src(path: String) -> String:
	return FileAccess.get_file_as_string(path)

func _func_body(src: String, sig: String) -> String:
	var start: int = src.find(sig)
	if start == -1:
		return ""
	var end: int = src.find("\nfunc ", start + sig.length())
	return src.substr(start, (end if end != -1 else src.length()) - start)

func test_can_local_act_respects_action_busy() -> void:
	var body: String = _func_body(_src("res://scenes/battle/BattleScene.gd"), "func _can_local_act()")
	assert_true(body.contains("_action_busy"), "_can_local_act must block input while an action animates")

func test_attempt_attack_checks_lock_and_attack_budget() -> void:
	var body: String = _func_body(_src("res://scenes/battle/modules/BattleInput.gd"), "func _attempt_attack(")
	assert_true(body.contains("_can_local_act()"), "_attempt_attack must refuse while busy")
	assert_true(body.contains("can_attack()"), "_attempt_attack must refuse a spent attacker")

func test_execute_attack_sets_and_clears_busy() -> void:
	var body: String = _func_body(_src("res://scenes/battle/modules/BattleInput.gd"), "func _execute_attack(")
	assert_true(body.contains("_action_busy = true"))
	assert_true(body.contains("_action_busy = false"))

func test_settle_panel_restores_lunge_home() -> void:
	var fx := BattleFx.new()
	var box := HBoxContainer.new()
	var panel := PanelContainer.new()
	box.add_child(panel)
	panel.set_meta("lunge_home", Vector2(10, 0))
	panel.position = Vector2(80, -40)
	panel.z_index = 10
	fx.settle_panel(panel)
	assert_eq(panel.position, Vector2(10, 0))
	assert_eq(panel.z_index, 0)
	assert_false(panel.has_meta("lunge_home"))
	box.free()
