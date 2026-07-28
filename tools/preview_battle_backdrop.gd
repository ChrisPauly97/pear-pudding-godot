## Renders one PNG per battle backdrop variant so the art can be eyeballed
## without launching a battle.
##
##   godot --path . --rendering-driver opengl3 \
##       -s tools/preview_battle_backdrop.gd -- --out=/tmp/backdrops
##
## Needs a real (or virtual, e.g. xvfb-run) display — the headless driver has
## no rasteriser, so the shader would never execute. Frames are captured with
## `anim = 0` so repeated runs are byte-identical.
extends SceneTree

const _BattleBackdrop = preload("res://scenes/battle/BattleBackdrop.gd")
const _BiomeDef = preload("res://game_logic/world/BiomeDef.gd")

const _SIZE := Vector2i(1280, 720)


func _initialize() -> void:
	var out_dir := "/tmp/backdrops"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out_dir)

	var names: Array[String] = ["grasslands", "forest", "desert", "scorched", "mountains"]
	var variants: Array = []
	for biome in range(_BiomeDef.COUNT):
		variants.append([names[biome] + "_day", biome, false])
		variants.append([names[biome] + "_night", biome, true])
	variants.append(["neutral_vault", _BattleBackdrop.NEUTRAL, false])

	get_root().content_scale_size = _SIZE

	for v in variants:
		var label: String = v[0]
		var biome: int = v[1]
		var night: bool = v[2]

		var rect := ColorRect.new()
		rect.size = Vector2(_SIZE)
		rect.color = Color(0.1, 0.1, 0.15)
		_BattleBackdrop.apply(rect, biome, night, false)
		get_root().add_child(rect)

		# Two frames: one to submit the draw, one to be sure it landed.
		for _i in range(2):
			await process_frame
		await RenderingServer.frame_post_draw

		var img := get_root().get_texture().get_image()
		var path := out_dir.path_join(label + ".png")
		if img.save_png(path) == OK:
			print("wrote ", path)
		else:
			push_error("failed to write " + path)
		rect.queue_free()
		await process_frame

	quit(0)
