## Unit tests for night point lights (GID-129 / TID-489).
##
## The glow only shows on screen, so pin the rules (NightLightMath) and the
## tier caps the NightLights module applies.
extends "res://tests/framework/test_case.gd"

const NLM = preload("res://game_logic/NightLightMath.gd")
const GQ = preload("res://game_logic/GraphicsQuality.gd")
const DNC = preload("res://scenes/world/DayNightCycle.gd")

const NOON := 0.5
const MIDNIGHT := 0.0


func _sun_h(tod: float) -> float:
	return DNC.sun_direction(tod).y


func test_lights_follow_the_night() -> void:
	assert_almost_eq(NLM.night_factor(_sun_h(NOON)), 0.0, 0.0001, "off at noon")
	assert_almost_eq(NLM.night_factor(_sun_h(MIDNIGHT)), 1.0, 0.0001, "full at midnight")
	var dusk: float = NLM.night_factor(0.05)
	assert_true(dusk > 0.0 and dusk < 1.0, "warming at dusk while the sun is still up")
	assert_gt(NLM.night_factor(0.0), NLM.night_factor(0.1), "brighter as the sun sinks")


func test_flicker_stays_in_band() -> void:
	for style: String in NLM.STYLES:
		var st: Dictionary = NLM.STYLES[style]
		var amount: float = st["flicker"]
		var lo: float = 2.0
		var hi: float = -1.0
		var t: float = 0.0
		while t < 20.0:
			var f: float = NLM.flicker(t, 1.3, amount, float(st["speed"]))
			lo = minf(lo, f)
			hi = maxf(hi, f)
			t += 0.037
		assert_true(lo >= 1.0 - amount - 0.0001 and hi <= 1.0001, "%s in band" % style)
		if amount > 0.0:
			assert_gt(hi - lo, amount * 0.3, "%s visibly flickers" % style)
	assert_almost_eq(NLM.flicker(3.0, 0.5, 0.0, 1.0), 1.0, 0.0001, "zero amount is steady")


func test_campfire_flickers_more_than_waystone() -> void:
	var fire: Dictionary = NLM.STYLES["campfire"]
	var stone: Dictionary = NLM.STYLES["waystone"]
	assert_gt(float(fire["flicker"]), float(stone["flicker"]))


func test_styles_share_keys() -> void:
	var keys: Array = (NLM.STYLES["lantern"] as Dictionary).keys()
	keys.sort()
	for style: String in NLM.STYLES:
		var k: Array = (NLM.STYLES[style] as Dictionary).keys()
		k.sort()
		assert_eq(k, keys, "%s keys" % style)


func test_nearest_caps_orders_and_ranges() -> void:
	var src: Array[Dictionary] = []
	for i: int in 12:
		src.append({"pos": Vector3(float(i) * 3.0, 5.0, 0.0), "style": "lantern"})
	var got: Array[Dictionary] = NLM.nearest(src, Vector3(0.0, 0.0, 0.0), 4, 100.0)
	assert_eq(got.size(), 4, "capped")
	assert_almost_eq((got[0]["pos"] as Vector3).x, 0.0, 0.0001, "nearest first")
	assert_almost_eq((got[3]["pos"] as Vector3).x, 9.0, 0.0001, "ordered")
	assert_eq(NLM.nearest(src, Vector3.ZERO, 8, 10.0).size(), 4, "range limits (0,3,6,9)")
	assert_eq(NLM.nearest(src, Vector3.ZERO, 0, 100.0).size(), 0, "zero cap")
	assert_false(src[0].has("d2"), "input untouched")


func test_phase_is_stable_per_position() -> void:
	var a: float = NLM.phase_for(Vector3(4.0, 0.0, 7.0))
	assert_almost_eq(a, NLM.phase_for(Vector3(4.0, 3.0, 7.0)), 0.0001)
	assert_true(a >= 0.0 and a < TAU)


func test_tier_caps() -> void:
	assert_eq(int(GQ.TIERS[GQ.LOW]["max_night_lights"]), 0, "Low draws no pools")
	assert_true(int(GQ.TIERS[GQ.MEDIUM]["max_night_lights"]) <= 8, "Mobile per-mesh light limit")
	assert_true(int(GQ.TIERS[GQ.HIGH]["max_night_lights"]) <= 8, "rig pool size")
