## Real-time battle board row (GID-135): attached to a board HBoxContainer at
## runtime by `RealtimeVisuals`, it re-places the visible slot panels on a
## diagonal — each slot one `step` down-right of the previous, from `origin`.
##
## BoxContainer sorts natively first; a script's NOTIFICATION_SORT_CHILDREN
## handler runs after it, so this overrides the horizontal layout while the
## node keeps its HBoxContainer type (BattleScene's typed @onready refs stay valid).
extends HBoxContainer

## Top-left of the first visible slot, in this container's local space.
var origin: Vector2 = Vector2.ZERO
## Offset between consecutive visible slots.
var step: Vector2 = Vector2.ZERO

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN or step == Vector2.ZERO:
		return
	var i: int = 0
	for child in get_children():
		var c := child as Control
		if c == null or not c.visible:
			continue
		var sz: Vector2 = c.get_combined_minimum_size()
		fit_child_in_rect(c, Rect2(origin + step * float(i), sz))
		c.set_meta("lunge_home", c.position)
		i += 1
