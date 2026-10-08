## GID-178 / TID-726: auto-attack wind-up and impact helpers.
extends "res://tests/framework/test_case.gd"

const SwingFx = preload("res://scenes/battle/modules/SwingFx.gd")

func test_wind_up_only_at_the_end_of_the_swing() -> void:
	var tok := Control.new()
	tok.size = Vector2(100, 100)
	SwingFx.wind_up(tok, 0.3, true)
	assert_eq(tok.scale, Vector2.ONE, "early in the swing: at rest")
	SwingFx.wind_up(tok, 1.0, true)
	assert_almost_eq(tok.scale.x, 1.0 + SwingFx.SWELL, 0.001, "full swell at the hit")
	assert_lt(tok.rotation, 0.0, "the player leans back (left)")
	SwingFx.wind_up(tok, 1.0, false)
	assert_gt(tok.rotation, 0.0, "enemies lean right")
	SwingFx.wind_up(tok, 0.0, false)
	assert_eq(tok.rotation, 0.0, "resets after the swing")
	tok.free()

func test_wind_up_skips_a_lunging_token() -> void:
	var tok := Control.new()
	tok.set_meta("lunging", true)
	SwingFx.wind_up(tok, 1.0, true)
	assert_eq(tok.scale, Vector2.ONE)
	tok.free()

func test_impact_spawns_slash_and_sparks() -> void:
	var layer := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(layer)
	SwingFx.impact(layer, Vector2(50, 50), 720.0, true)
	assert_eq(layer.get_child_count(), 1 + SwingFx.SPARKS)
	assert_true(layer.get_child(0) is Line2D, "slash first")
	layer.free()

func test_crit_impact_is_bigger() -> void:
	var layer := Node2D.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(layer)
	SwingFx.impact(layer, Vector2(50, 50), 720.0, true, 0.12, true)
	assert_eq(layer.get_child_count(), 1 + SwingFx.SPARKS * 2, "twice the sparks")
	layer.free()
