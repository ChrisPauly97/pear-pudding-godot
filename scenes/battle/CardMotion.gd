## Card motion (GID-151): the tweens that move whole cards around the battle
## screen: dealing a drawn card into the hand, the arced hand→board play, the
## enemy's face-down play that flips over on its slot, and the dissolve used for
## spells and deaths. All work on ghost copies in the battle's float layer, so
## the real, container-laid-out panels never leave their slots. Durations are
## multiplied by the battle's speed scale (BattleFx.scaled_duration).
extends RefCounted

const CardFace = preload("res://scenes/ui/CardFace.gd")

const DRAW_TIME := 0.26
const DRAW_STAGGER := 0.07
const FLIP_TIME := 0.08
const PLAY_TIME := 0.24
const PLAY_ARC := 0.35   # arc height as a share of the travel distance

# Hand cards already dealt, by instance id (instance state; see deal_new_hand_cards).
var _seen_hand: Dictionary = {}

## Deals in every card in `cards` (the local hand, same order as the children
## of `hand_view`) that was not there at the previous call. Cards fly from the
## right end of the hand row, where the draw pile would sit.
func deal_new_hand_cards(layer: CanvasLayer, hand_view: Control, cards: Array, speed_scale: float) -> void:
	var now: Dictionary = {}
	var order: int = 0
	var kids: Array[Control] = []
	for n: Node in hand_view.get_children():
		if not n.is_queued_for_deletion() and n is Control:
			kids.append(n as Control)
	var rect: Rect2 = hand_view.get_global_rect()
	var from := Vector2(rect.end.x, rect.get_center().y)
	for i: int in range(cards.size()):
		var id: String = str((cards[i] as Object).get("instance_id"))
		now[id] = true
		if _seen_hand.has(id) or i >= kids.size():
			continue
		deal_in(layer, kids[i], from, order, speed_scale)
		order += 1
	_seen_hand = now

static func _dur(base: float, speed_scale: float) -> float:
	return maxf(0.01, base * speed_scale)

## A face-down card of `size` for the float layer.
static func make_back(size: Vector2) -> PanelContainer:
	var back := PanelContainer.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.custom_minimum_size = size
	back.size = size
	back.pivot_offset = size * 0.5
	CardFace.apply_back(back, size.y)
	return back

## Deals `panel` (a freshly drawn hand card) in: a card back flies from `from`
## (global) to the panel's slot, turns edge-on, and the real face flips out.
## `order` staggers several cards drawn at once. Safe if anything is freed.
static func deal_in(layer: CanvasLayer, panel: Control, from: Vector2, order: int, speed_scale: float) -> void:
	if panel == null or not is_instance_valid(panel) or layer == null or not is_instance_valid(layer):
		return
	panel.modulate.a = 0.0
	await panel.get_tree().process_frame  # let the hand row lay the new panel out
	if not is_instance_valid(panel) or not is_instance_valid(layer):
		return
	var rect: Rect2 = panel.get_global_rect()
	if rect.size == Vector2.ZERO:
		panel.modulate.a = 1.0
		return
	var ghost: PanelContainer = make_back(rect.size)
	ghost.position = from - rect.size * 0.5
	ghost.scale = Vector2(0.6, 0.6)
	ghost.rotation = deg_to_rad(-14.0)
	ghost.modulate.a = 0.0
	layer.add_child(ghost)
	var delay: float = _dur(DRAW_STAGGER * order, speed_scale)
	var dur: float = _dur(DRAW_TIME, speed_scale)
	var tw: Tween = ghost.create_tween().set_parallel(true)
	tw.tween_property(ghost, "modulate:a", 1.0, dur * 0.3).set_delay(delay)
	tw.tween_property(ghost, "position", rect.position, dur).set_delay(delay) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost, "scale", Vector2.ONE, dur).set_delay(delay)
	tw.tween_property(ghost, "rotation", 0.0, dur).set_delay(delay)
	tw.chain().tween_property(ghost, "scale:x", 0.0, _dur(FLIP_TIME, speed_scale))
	await tw.finished
	if is_instance_valid(ghost):
		ghost.queue_free()
	if not is_instance_valid(panel):
		return
	flip_out(panel, speed_scale)

## Second half of a flip: `panel` grows from edge-on back to full width.
static func flip_out(panel: Control, speed_scale: float) -> void:
	panel.pivot_offset = panel.size * 0.5
	panel.scale = Vector2(0.0, 1.0)
	panel.modulate.a = 1.0
	var tw: Tween = panel.create_tween()
	tw.tween_property(panel, "scale:x", 1.0, _dur(FLIP_TIME, speed_scale)) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
