## GID-135: the real-time diagonal arena's two front lines sit close but never overlap.
extends "res://tests/framework/test_case.gd"

const _RealtimeVisuals = preload("res://scenes/battle/modules/RealtimeVisuals.gd")
const RealtimeCombat = preload("res://game_logic/battle/RealtimeCombat.gd")

func _rects(origin: Vector2, step: Vector2, card: Vector2, n: int) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for i in range(n):
		out.append(Rect2(origin + step * float(i), card))
	return out

func _check(vp: Vector2) -> void:
	var vh: float = vp.y
	var card := Vector2(vh * 0.135, vh * 0.24)
	var step := Vector2(card.x * 0.95, card.y * 0.30)
	var arena := Vector2(vp.x * 0.86, vh * 0.73)
	var rows: Dictionary = _RealtimeVisuals.row_origins(arena, card, step)
	var mine: Array[Rect2] = _rects(rows["player"], step, card, RealtimeCombat.MAX_ALLIES)
	var theirs: Array[Rect2] = _rects(rows["enemy"], step, card, RealtimeCombat.MAX_ENEMY_MINIONS)
	for a: Rect2 in mine:
		for b: Rect2 in theirs:
			assert_false(a.intersects(b), "rows overlap at %s" % str(vp))
	var all_rects: Array[Rect2] = mine + theirs
	for r: Rect2 in all_rects:
		assert_true(Rect2(Vector2.ZERO, arena).encloses(r), "slot outside the arena at %s" % str(vp))
	# Close: the enemy row's first slot sits within a card height (+ gap) above yours.
	var gap_y: float = (rows["player"] as Vector2).y - ((rows["enemy"] as Vector2).y + card.y)
	assert_true(gap_y >= 0.0 and gap_y <= card.y * 0.1, "rows not close together (gap %.1f)" % gap_y)

func test_rows_close_and_clear_16x9() -> void:
	_check(Vector2(1280, 720))

func test_rows_close_and_clear_phone_20x9() -> void:
	_check(Vector2(2400, 1080))
