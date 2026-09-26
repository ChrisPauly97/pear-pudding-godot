## GID-135: the real-time diagonal arena — each front line hugs its own hero,
## with open ground between the two lines, and nothing overlaps.
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
	var arena := Vector2(vp.x, vh * 0.73)
	var tok := Vector2(vh * 0.24, vh * 0.27)
	var lay: Dictionary = _RealtimeVisuals.arena_layout(arena, card, step, tok, tok, vh * 0.015)
	var mine: Array[Rect2] = _rects(lay["player"], step, card, RealtimeCombat.MAX_ALLIES)
	var theirs: Array[Rect2] = _rects(lay["enemy"], step, card, RealtimeCombat.MAX_ENEMY_MINIONS)
	var p_tok := Rect2(lay["player_token"], tok)
	var e_tok := Rect2(lay["enemy_token"], tok)
	# Slots within one line fan over each other by design; compare across groups only.
	var groups: Array = [mine, theirs, [p_tok] as Array[Rect2], [e_tok] as Array[Rect2]]
	for gi in range(groups.size()):
		var g: Array[Rect2] = groups[gi]
		for r: Rect2 in g:
			assert_true(Rect2(Vector2.ZERO, arena).encloses(r), "outside the arena at %s" % str(vp))
		for gj in range(gi + 1, groups.size()):
			var h: Array[Rect2] = groups[gj]
			for a: Rect2 in g:
				for b: Rect2 in h:
					assert_false(a.intersects(b), "groups %d/%d overlap at %s" % [gi, gj, str(vp)])
	# Attached: each line starts within a small gap of its own hero token.
	assert_true(mine[0].position.x - p_tok.end.x <= card.x * 0.2, "Ally line not attached to your hero")
	assert_true(e_tok.position.x - theirs[theirs.size() - 1].end.x <= card.x * 0.2,
			"enemy line not attached to the enemy hero")
	# Wide gap: open ground of at least a card width between the two lines.
	assert_true(theirs[0].position.x - mine[mine.size() - 1].end.x >= card.x,
			"lines too close at %s" % str(vp))

func test_layout_16x9() -> void:
	_check(Vector2(1280, 720))

func test_layout_phone_20x9() -> void:
	_check(Vector2(2400, 1080))
