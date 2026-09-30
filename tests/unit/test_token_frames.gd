## Enemy combat frames (GID-152 / TID-646): coverage, alignment, and the
## token picture's attack / flinch / death playback.
extends "res://tests/framework/test_case.gd"

const SR = preload("res://game_logic/SpriteRegistry.gd")
const CF = preload("res://game_logic/CombatFrames.gd")
const TokenFrames = preload("res://scenes/battle/modules/TokenFrames.gd")


func test_every_enemy_sprite_has_combat_frames() -> void:
	var etypes: Array[String] = ["undead_basic", "undead_horde", "undead_elite", "ghoul_pack", "martarquas_raider_1",
			"martarquas_warleader", "duelist_novice", "rival_isfig_1", "mimic", "roaming_terror", "spectre_wisp",
			"cactus_worm", "imbued_stag", "wolf_pack", "bog_hag", "martarquas_scout", "scarab_swarm",
			"ember_cultist", "frost_wendigo", "rift_echo"]
	for etype: String in etypes:
		var idle: Texture2D = SR.enemy_texture(etype)
		var f: Dictionary = CF.for_idle(idle)
		assert_false(f.is_empty(), "%s has combat frames" % etype)
		if f.is_empty():
			continue
		var all: Array[Texture2D] = []
		all.assign(f["attack"] as Array)
		all.append(f["hit"] as Texture2D)
		all.append_array(f["death"] as Array)
		assert_eq(all.size(), 7)
		for t: Texture2D in all:
			assert_eq(t.get_height(), idle.get_height(), "%s frames keep the idle height" % etype)
			assert_eq(t.get_width() - idle.get_width(), all[0].get_width() - idle.get_width(),
					"%s frames share one width" % etype)


func test_register_ignores_sprites_without_frames() -> void:
	var tf: TokenFrames = TokenFrames.new()
	var pic := TextureRect.new()
	pic.texture = SR.mount_texture()
	tf.register(1, pic)
	tf.attack(1)  # no frames: a no-op, no error
	assert_eq(pic.texture, SR.mount_texture())
	pic.free()
