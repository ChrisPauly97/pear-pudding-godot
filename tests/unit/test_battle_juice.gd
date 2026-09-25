## Unit tests for battle juice (GID-132 / TID-512).
extends "res://tests/framework/test_case.gd"

const BJ = preload("res://scenes/battle/BattleJuice.gd")


func test_label_scale_grows_and_caps() -> void:
	assert_almost_eq(BJ.label_scale(1), 1.0)
	assert_gt(BJ.label_scale(6), BJ.label_scale(2))
	assert_almost_eq(BJ.label_scale(-50), 1.8, 0.0001, "capped, sign-agnostic")

func test_reduce_flashing_softens_flash_and_skips_sparks() -> void:
	var sm := SaveManager
	var prev: Variant = sm.get_setting("reduce_flashing", false)
	sm.set_setting("reduce_flashing", false)
	var strong: Color = BJ.flash_color(false)
	sm.set_setting("reduce_flashing", true)
	var soft: Color = BJ.flash_color(false)
	assert_gt(soft.g, strong.g, "milder red with Reduce Flashing")
	var layer := Node.new()
	BJ.sparks(layer, Vector2.ZERO, Color.RED, 5)
	assert_eq(layer.get_child_count(), 0, "no sparks with Reduce Flashing")
	sm.set_setting("reduce_flashing", false)
	BJ.sparks(layer, Vector2.ZERO, Color.RED, 5)
	assert_eq(layer.get_child_count(), 1)
	var p: CPUParticles2D = layer.get_child(0) as CPUParticles2D
	assert_between(p.amount, BJ.SPARK_BASE, BJ.SPARK_MAX)
	layer.free()
	sm.set_setting("reduce_flashing", prev)

func test_punch_and_pop_in_are_safe_on_null() -> void:
	BJ.punch(null, true)
	BJ.pop_in(null)
	var c := Control.new()
	BJ.pop_in(c)
	assert_almost_eq(c.scale.x, 0.6, 0.0001, "starts small")
	c.free()
