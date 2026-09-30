## Enemy walk frames (GID-152 / TID-645) and the horse's trot (TID-651): one preload per file (Android packs
## only what is preloaded) and the idle texture -> four walk frames table that
## SpriteRegistry.walk_frames() reads. Regenerate the PNGs with
## tools/generate_characters.py and scripts/gen_creature_sprites.py.
extends RefCounted

const _BARROW_KING := preload("res://assets/textures/characters/enemy_barrow_king.png")
const _BARROW_KING_1 := preload("res://assets/textures/characters/enemy_barrow_king_walk_1.png")
const _BARROW_KING_2 := preload("res://assets/textures/characters/enemy_barrow_king_walk_2.png")
const _BARROW_KING_3 := preload("res://assets/textures/characters/enemy_barrow_king_walk_3.png")
const _BARROW_KING_4 := preload("res://assets/textures/characters/enemy_barrow_king_walk_4.png")
const _BOG_HAG := preload("res://assets/textures/characters/enemy_bog_hag.png")
const _BOG_HAG_1 := preload("res://assets/textures/characters/enemy_bog_hag_walk_1.png")
const _BOG_HAG_2 := preload("res://assets/textures/characters/enemy_bog_hag_walk_2.png")
const _BOG_HAG_3 := preload("res://assets/textures/characters/enemy_bog_hag_walk_3.png")
const _BOG_HAG_4 := preload("res://assets/textures/characters/enemy_bog_hag_walk_4.png")
const _CACTUS_WORM := preload("res://assets/textures/characters/enemy_cactus_worm.png")
const _CACTUS_WORM_1 := preload("res://assets/textures/characters/enemy_cactus_worm_walk_1.png")
const _CACTUS_WORM_2 := preload("res://assets/textures/characters/enemy_cactus_worm_walk_2.png")
const _CACTUS_WORM_3 := preload("res://assets/textures/characters/enemy_cactus_worm_walk_3.png")
const _CACTUS_WORM_4 := preload("res://assets/textures/characters/enemy_cactus_worm_walk_4.png")
const _DUELIST := preload("res://assets/textures/characters/enemy_duelist.png")
const _DUELIST_1 := preload("res://assets/textures/characters/enemy_duelist_walk_1.png")
const _DUELIST_2 := preload("res://assets/textures/characters/enemy_duelist_walk_2.png")
const _DUELIST_3 := preload("res://assets/textures/characters/enemy_duelist_walk_3.png")
const _DUELIST_4 := preload("res://assets/textures/characters/enemy_duelist_walk_4.png")
const _EMBER_CULTIST := preload("res://assets/textures/characters/enemy_ember_cultist.png")
const _EMBER_CULTIST_1 := preload("res://assets/textures/characters/enemy_ember_cultist_walk_1.png")
const _EMBER_CULTIST_2 := preload("res://assets/textures/characters/enemy_ember_cultist_walk_2.png")
const _EMBER_CULTIST_3 := preload("res://assets/textures/characters/enemy_ember_cultist_walk_3.png")
const _EMBER_CULTIST_4 := preload("res://assets/textures/characters/enemy_ember_cultist_walk_4.png")
const _FROST_WENDIGO := preload("res://assets/textures/characters/enemy_frost_wendigo.png")
const _FROST_WENDIGO_1 := preload("res://assets/textures/characters/enemy_frost_wendigo_walk_1.png")
const _FROST_WENDIGO_2 := preload("res://assets/textures/characters/enemy_frost_wendigo_walk_2.png")
const _FROST_WENDIGO_3 := preload("res://assets/textures/characters/enemy_frost_wendigo_walk_3.png")
const _FROST_WENDIGO_4 := preload("res://assets/textures/characters/enemy_frost_wendigo_walk_4.png")
const _GHOUL := preload("res://assets/textures/characters/enemy_ghoul.png")
const _GHOUL_1 := preload("res://assets/textures/characters/enemy_ghoul_walk_1.png")
const _GHOUL_2 := preload("res://assets/textures/characters/enemy_ghoul_walk_2.png")
const _GHOUL_3 := preload("res://assets/textures/characters/enemy_ghoul_walk_3.png")
const _GHOUL_4 := preload("res://assets/textures/characters/enemy_ghoul_walk_4.png")
const _IMBUED_STAG := preload("res://assets/textures/characters/enemy_imbued_stag.png")
const _IMBUED_STAG_1 := preload("res://assets/textures/characters/enemy_imbued_stag_walk_1.png")
const _IMBUED_STAG_2 := preload("res://assets/textures/characters/enemy_imbued_stag_walk_2.png")
const _IMBUED_STAG_3 := preload("res://assets/textures/characters/enemy_imbued_stag_walk_3.png")
const _IMBUED_STAG_4 := preload("res://assets/textures/characters/enemy_imbued_stag_walk_4.png")
const _MARTARQUAS_SCOUT := preload("res://assets/textures/characters/enemy_martarquas_scout.png")
const _MARTARQUAS_SCOUT_1 := preload("res://assets/textures/characters/enemy_martarquas_scout_walk_1.png")
const _MARTARQUAS_SCOUT_2 := preload("res://assets/textures/characters/enemy_martarquas_scout_walk_2.png")
const _MARTARQUAS_SCOUT_3 := preload("res://assets/textures/characters/enemy_martarquas_scout_walk_3.png")
const _MARTARQUAS_SCOUT_4 := preload("res://assets/textures/characters/enemy_martarquas_scout_walk_4.png")
const _RAIDER := preload("res://assets/textures/characters/enemy_raider.png")
const _RAIDER_1 := preload("res://assets/textures/characters/enemy_raider_walk_1.png")
const _RAIDER_2 := preload("res://assets/textures/characters/enemy_raider_walk_2.png")
const _RAIDER_3 := preload("res://assets/textures/characters/enemy_raider_walk_3.png")
const _RAIDER_4 := preload("res://assets/textures/characters/enemy_raider_walk_4.png")
const _RIFT_ECHO := preload("res://assets/textures/characters/enemy_rift_echo.png")
const _RIFT_ECHO_1 := preload("res://assets/textures/characters/enemy_rift_echo_walk_1.png")
const _RIFT_ECHO_2 := preload("res://assets/textures/characters/enemy_rift_echo_walk_2.png")
const _RIFT_ECHO_3 := preload("res://assets/textures/characters/enemy_rift_echo_walk_3.png")
const _RIFT_ECHO_4 := preload("res://assets/textures/characters/enemy_rift_echo_walk_4.png")
const _RIVAL := preload("res://assets/textures/characters/enemy_rival.png")
const _RIVAL_1 := preload("res://assets/textures/characters/enemy_rival_walk_1.png")
const _RIVAL_2 := preload("res://assets/textures/characters/enemy_rival_walk_2.png")
const _RIVAL_3 := preload("res://assets/textures/characters/enemy_rival_walk_3.png")
const _RIVAL_4 := preload("res://assets/textures/characters/enemy_rival_walk_4.png")
const _SCARAB := preload("res://assets/textures/characters/enemy_scarab.png")
const _SCARAB_1 := preload("res://assets/textures/characters/enemy_scarab_walk_1.png")
const _SCARAB_2 := preload("res://assets/textures/characters/enemy_scarab_walk_2.png")
const _SCARAB_3 := preload("res://assets/textures/characters/enemy_scarab_walk_3.png")
const _SCARAB_4 := preload("res://assets/textures/characters/enemy_scarab_walk_4.png")
const _SCARAB_SWARM := preload("res://assets/textures/characters/enemy_scarab_swarm.png")
const _SCARAB_SWARM_1 := preload("res://assets/textures/characters/enemy_scarab_swarm_walk_1.png")
const _SCARAB_SWARM_2 := preload("res://assets/textures/characters/enemy_scarab_swarm_walk_2.png")
const _SCARAB_SWARM_3 := preload("res://assets/textures/characters/enemy_scarab_swarm_walk_3.png")
const _SCARAB_SWARM_4 := preload("res://assets/textures/characters/enemy_scarab_swarm_walk_4.png")
const _SKELETON := preload("res://assets/textures/characters/enemy_skeleton.png")
const _SKELETON_1 := preload("res://assets/textures/characters/enemy_skeleton_walk_1.png")
const _SKELETON_2 := preload("res://assets/textures/characters/enemy_skeleton_walk_2.png")
const _SKELETON_3 := preload("res://assets/textures/characters/enemy_skeleton_walk_3.png")
const _SKELETON_4 := preload("res://assets/textures/characters/enemy_skeleton_walk_4.png")
const _SPECTRE := preload("res://assets/textures/characters/enemy_spectre.png")
const _SPECTRE_1 := preload("res://assets/textures/characters/enemy_spectre_walk_1.png")
const _SPECTRE_2 := preload("res://assets/textures/characters/enemy_spectre_walk_2.png")
const _SPECTRE_3 := preload("res://assets/textures/characters/enemy_spectre_walk_3.png")
const _SPECTRE_4 := preload("res://assets/textures/characters/enemy_spectre_walk_4.png")
const _TERROR := preload("res://assets/textures/characters/enemy_terror.png")
const _TERROR_1 := preload("res://assets/textures/characters/enemy_terror_walk_1.png")
const _TERROR_2 := preload("res://assets/textures/characters/enemy_terror_walk_2.png")
const _TERROR_3 := preload("res://assets/textures/characters/enemy_terror_walk_3.png")
const _TERROR_4 := preload("res://assets/textures/characters/enemy_terror_walk_4.png")
const _UNDEAD_ELITE := preload("res://assets/textures/characters/enemy_undead_elite.png")
const _UNDEAD_ELITE_1 := preload("res://assets/textures/characters/enemy_undead_elite_walk_1.png")
const _UNDEAD_ELITE_2 := preload("res://assets/textures/characters/enemy_undead_elite_walk_2.png")
const _UNDEAD_ELITE_3 := preload("res://assets/textures/characters/enemy_undead_elite_walk_3.png")
const _UNDEAD_ELITE_4 := preload("res://assets/textures/characters/enemy_undead_elite_walk_4.png")
const _WARLEADER := preload("res://assets/textures/characters/enemy_warleader.png")
const _WARLEADER_1 := preload("res://assets/textures/characters/enemy_warleader_walk_1.png")
const _WARLEADER_2 := preload("res://assets/textures/characters/enemy_warleader_walk_2.png")
const _WARLEADER_3 := preload("res://assets/textures/characters/enemy_warleader_walk_3.png")
const _WARLEADER_4 := preload("res://assets/textures/characters/enemy_warleader_walk_4.png")
const _WOLF := preload("res://assets/textures/characters/enemy_wolf.png")
const _WOLF_1 := preload("res://assets/textures/characters/enemy_wolf_walk_1.png")
const _WOLF_2 := preload("res://assets/textures/characters/enemy_wolf_walk_2.png")
const _WOLF_3 := preload("res://assets/textures/characters/enemy_wolf_walk_3.png")
const _WOLF_4 := preload("res://assets/textures/characters/enemy_wolf_walk_4.png")
const _WOLF_PACK := preload("res://assets/textures/characters/enemy_wolf_pack.png")
const _WOLF_PACK_1 := preload("res://assets/textures/characters/enemy_wolf_pack_walk_1.png")
const _WOLF_PACK_2 := preload("res://assets/textures/characters/enemy_wolf_pack_walk_2.png")
const _WOLF_PACK_3 := preload("res://assets/textures/characters/enemy_wolf_pack_walk_3.png")
const _WOLF_PACK_4 := preload("res://assets/textures/characters/enemy_wolf_pack_walk_4.png")
const _ZOMBIE := preload("res://assets/textures/characters/enemy_zombie.png")
const _ZOMBIE_1 := preload("res://assets/textures/characters/enemy_zombie_walk_1.png")
const _ZOMBIE_2 := preload("res://assets/textures/characters/enemy_zombie_walk_2.png")
const _ZOMBIE_3 := preload("res://assets/textures/characters/enemy_zombie_walk_3.png")
const _ZOMBIE_4 := preload("res://assets/textures/characters/enemy_zombie_walk_4.png")
const _MOUNT_HORSE := preload("res://assets/textures/characters/mount_horse.png")
const _MOUNT_HORSE_1 := preload("res://assets/textures/characters/mount_horse_walk_1.png")
const _MOUNT_HORSE_2 := preload("res://assets/textures/characters/mount_horse_walk_2.png")
const _MOUNT_HORSE_3 := preload("res://assets/textures/characters/mount_horse_walk_3.png")
const _MOUNT_HORSE_4 := preload("res://assets/textures/characters/mount_horse_walk_4.png")

const _TABLE: Dictionary = {
	_MOUNT_HORSE: [_MOUNT_HORSE_1, _MOUNT_HORSE_2, _MOUNT_HORSE_3, _MOUNT_HORSE_4],
	_BARROW_KING: [_BARROW_KING_1, _BARROW_KING_2, _BARROW_KING_3, _BARROW_KING_4],
	_BOG_HAG: [_BOG_HAG_1, _BOG_HAG_2, _BOG_HAG_3, _BOG_HAG_4],
	_CACTUS_WORM: [_CACTUS_WORM_1, _CACTUS_WORM_2, _CACTUS_WORM_3, _CACTUS_WORM_4],
	_DUELIST: [_DUELIST_1, _DUELIST_2, _DUELIST_3, _DUELIST_4],
	_EMBER_CULTIST: [_EMBER_CULTIST_1, _EMBER_CULTIST_2, _EMBER_CULTIST_3, _EMBER_CULTIST_4],
	_FROST_WENDIGO: [_FROST_WENDIGO_1, _FROST_WENDIGO_2, _FROST_WENDIGO_3, _FROST_WENDIGO_4],
	_GHOUL: [_GHOUL_1, _GHOUL_2, _GHOUL_3, _GHOUL_4],
	_IMBUED_STAG: [_IMBUED_STAG_1, _IMBUED_STAG_2, _IMBUED_STAG_3, _IMBUED_STAG_4],
	_MARTARQUAS_SCOUT: [_MARTARQUAS_SCOUT_1, _MARTARQUAS_SCOUT_2, _MARTARQUAS_SCOUT_3, _MARTARQUAS_SCOUT_4],
	_RAIDER: [_RAIDER_1, _RAIDER_2, _RAIDER_3, _RAIDER_4],
	_RIFT_ECHO: [_RIFT_ECHO_1, _RIFT_ECHO_2, _RIFT_ECHO_3, _RIFT_ECHO_4],
	_RIVAL: [_RIVAL_1, _RIVAL_2, _RIVAL_3, _RIVAL_4],
	_SCARAB: [_SCARAB_1, _SCARAB_2, _SCARAB_3, _SCARAB_4],
	_SCARAB_SWARM: [_SCARAB_SWARM_1, _SCARAB_SWARM_2, _SCARAB_SWARM_3, _SCARAB_SWARM_4],
	_SKELETON: [_SKELETON_1, _SKELETON_2, _SKELETON_3, _SKELETON_4],
	_SPECTRE: [_SPECTRE_1, _SPECTRE_2, _SPECTRE_3, _SPECTRE_4],
	_TERROR: [_TERROR_1, _TERROR_2, _TERROR_3, _TERROR_4],
	_UNDEAD_ELITE: [_UNDEAD_ELITE_1, _UNDEAD_ELITE_2, _UNDEAD_ELITE_3, _UNDEAD_ELITE_4],
	_WARLEADER: [_WARLEADER_1, _WARLEADER_2, _WARLEADER_3, _WARLEADER_4],
	_WOLF: [_WOLF_1, _WOLF_2, _WOLF_3, _WOLF_4],
	_WOLF_PACK: [_WOLF_PACK_1, _WOLF_PACK_2, _WOLF_PACK_3, _WOLF_PACK_4],
	_ZOMBIE: [_ZOMBIE_1, _ZOMBIE_2, _ZOMBIE_3, _ZOMBIE_4],
}


## The four walk frames for an idle enemy (or horse) texture ([] when it has none).
static func for_idle(idle: Texture2D) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	out.assign(_TABLE.get(idle, []) as Array)
	return out
