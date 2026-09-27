## Floating reward toast (GID-135 / TID-531): "+N Coins" / "+N XP" / a card
## name rising and fading above the spot where an in-world fight was won,
## instead of the blocking result card. Self-frees once the animation ends.
##
## Instantiate, `add_child` it into the live WorldScene at the fight location,
## then call `play(lines)`. `lines` is `Array[{"text": String, "color": Color}]`,
## one stacked row per line, first line on top.
extends Node3D

const BASE_HEIGHT: float = 1.6
const LINE_GAP: float = 0.34
const RISE_DISTANCE: float = 1.4
const DURATION: float = 1.6

func play(lines: Array[Dictionary]) -> void:
	var labels: Array[Label3D] = []
	for i in range(lines.size()):
		var line: Dictionary = lines[i]
		var lbl := Label3D.new()
		lbl.text = str(line.get("text", ""))
		var col: Variant = line.get("color", Color.WHITE)
		lbl.modulate = col if col is Color else Color.WHITE
		lbl.font_size = 40
		lbl.pixel_size = 0.01
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.outline_size = 10
		lbl.position = Vector3(0.0, BASE_HEIGHT + i * LINE_GAP, 0.0)
		add_child(lbl)
		labels.append(lbl)
	var rise_tw: Tween = create_tween()
	rise_tw.tween_property(self, "position:y", position.y + RISE_DISTANCE, DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for lbl: Label3D in labels:
		var fade_tw: Tween = create_tween()
		fade_tw.tween_interval(DURATION * 0.5)
		fade_tw.tween_property(lbl, "modulate:a", 0.0, DURATION * 0.5)
	if is_inside_tree():
		get_tree().create_timer(DURATION + 0.05, false).timeout.connect(_self_free)

func _self_free() -> void:
	if is_instance_valid(self):
		queue_free()
