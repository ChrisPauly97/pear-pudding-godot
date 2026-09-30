## Enemy combat frames (GID-152 / TID-646), derived by
## tools/derive_combat_frames.py: attack (wind-up, strike, recover), a hit
## flinch and a three-step death. One preload per file (Android packs only what
## is preloaded); the idle texture keys the table.
extends RefCounted

const _BARROW_KING := preload("res://assets/textures/characters/enemy_barrow_king.png")
const _BARROW_KING_A1 := preload("res://assets/textures/characters/enemy_barrow_king_attack_1.png")
const _BARROW_KING_A2 := preload("res://assets/textures/characters/enemy_barrow_king_attack_2.png")
const _BARROW_KING_A3 := preload("res://assets/textures/characters/enemy_barrow_king_attack_3.png")
const _BARROW_KING_H := preload("res://assets/textures/characters/enemy_barrow_king_hit.png")
const _BARROW_KING_D1 := preload("res://assets/textures/characters/enemy_barrow_king_death_1.png")
const _BARROW_KING_D2 := preload("res://assets/textures/characters/enemy_barrow_king_death_2.png")
const _BARROW_KING_D3 := preload("res://assets/textures/characters/enemy_barrow_king_death_3.png")
const _BOG_HAG := preload("res://assets/textures/characters/enemy_bog_hag.png")
const _BOG_HAG_A1 := preload("res://assets/textures/characters/enemy_bog_hag_attack_1.png")
const _BOG_HAG_A2 := preload("res://assets/textures/characters/enemy_bog_hag_attack_2.png")
const _BOG_HAG_A3 := preload("res://assets/textures/characters/enemy_bog_hag_attack_3.png")
const _BOG_HAG_H := preload("res://assets/textures/characters/enemy_bog_hag_hit.png")
const _BOG_HAG_D1 := preload("res://assets/textures/characters/enemy_bog_hag_death_1.png")
const _BOG_HAG_D2 := preload("res://assets/textures/characters/enemy_bog_hag_death_2.png")
const _BOG_HAG_D3 := preload("res://assets/textures/characters/enemy_bog_hag_death_3.png")
const _CACTUS_WORM := preload("res://assets/textures/characters/enemy_cactus_worm.png")
const _CACTUS_WORM_A1 := preload("res://assets/textures/characters/enemy_cactus_worm_attack_1.png")
const _CACTUS_WORM_A2 := preload("res://assets/textures/characters/enemy_cactus_worm_attack_2.png")
const _CACTUS_WORM_A3 := preload("res://assets/textures/characters/enemy_cactus_worm_attack_3.png")
const _CACTUS_WORM_H := preload("res://assets/textures/characters/enemy_cactus_worm_hit.png")
const _CACTUS_WORM_D1 := preload("res://assets/textures/characters/enemy_cactus_worm_death_1.png")
const _CACTUS_WORM_D2 := preload("res://assets/textures/characters/enemy_cactus_worm_death_2.png")
const _CACTUS_WORM_D3 := preload("res://assets/textures/characters/enemy_cactus_worm_death_3.png")
const _DUELIST := preload("res://assets/textures/characters/enemy_duelist.png")
const _DUELIST_A1 := preload("res://assets/textures/characters/enemy_duelist_attack_1.png")
const _DUELIST_A2 := preload("res://assets/textures/characters/enemy_duelist_attack_2.png")
const _DUELIST_A3 := preload("res://assets/textures/characters/enemy_duelist_attack_3.png")
const _DUELIST_H := preload("res://assets/textures/characters/enemy_duelist_hit.png")
const _DUELIST_D1 := preload("res://assets/textures/characters/enemy_duelist_death_1.png")
const _DUELIST_D2 := preload("res://assets/textures/characters/enemy_duelist_death_2.png")
const _DUELIST_D3 := preload("res://assets/textures/characters/enemy_duelist_death_3.png")
const _EMBER_CULTIST := preload("res://assets/textures/characters/enemy_ember_cultist.png")
const _EMBER_CULTIST_A1 := preload("res://assets/textures/characters/enemy_ember_cultist_attack_1.png")
const _EMBER_CULTIST_A2 := preload("res://assets/textures/characters/enemy_ember_cultist_attack_2.png")
const _EMBER_CULTIST_A3 := preload("res://assets/textures/characters/enemy_ember_cultist_attack_3.png")
const _EMBER_CULTIST_H := preload("res://assets/textures/characters/enemy_ember_cultist_hit.png")
const _EMBER_CULTIST_D1 := preload("res://assets/textures/characters/enemy_ember_cultist_death_1.png")
const _EMBER_CULTIST_D2 := preload("res://assets/textures/characters/enemy_ember_cultist_death_2.png")
const _EMBER_CULTIST_D3 := preload("res://assets/textures/characters/enemy_ember_cultist_death_3.png")
const _FROST_WENDIGO := preload("res://assets/textures/characters/enemy_frost_wendigo.png")
const _FROST_WENDIGO_A1 := preload("res://assets/textures/characters/enemy_frost_wendigo_attack_1.png")
const _FROST_WENDIGO_A2 := preload("res://assets/textures/characters/enemy_frost_wendigo_attack_2.png")
const _FROST_WENDIGO_A3 := preload("res://assets/textures/characters/enemy_frost_wendigo_attack_3.png")
const _FROST_WENDIGO_H := preload("res://assets/textures/characters/enemy_frost_wendigo_hit.png")
const _FROST_WENDIGO_D1 := preload("res://assets/textures/characters/enemy_frost_wendigo_death_1.png")
const _FROST_WENDIGO_D2 := preload("res://assets/textures/characters/enemy_frost_wendigo_death_2.png")
const _FROST_WENDIGO_D3 := preload("res://assets/textures/characters/enemy_frost_wendigo_death_3.png")
const _GHOUL := preload("res://assets/textures/characters/enemy_ghoul.png")
const _GHOUL_A1 := preload("res://assets/textures/characters/enemy_ghoul_attack_1.png")
const _GHOUL_A2 := preload("res://assets/textures/characters/enemy_ghoul_attack_2.png")
const _GHOUL_A3 := preload("res://assets/textures/characters/enemy_ghoul_attack_3.png")
const _GHOUL_H := preload("res://assets/textures/characters/enemy_ghoul_hit.png")
const _GHOUL_D1 := preload("res://assets/textures/characters/enemy_ghoul_death_1.png")
const _GHOUL_D2 := preload("res://assets/textures/characters/enemy_ghoul_death_2.png")
const _GHOUL_D3 := preload("res://assets/textures/characters/enemy_ghoul_death_3.png")
const _IMBUED_STAG := preload("res://assets/textures/characters/enemy_imbued_stag.png")
const _IMBUED_STAG_A1 := preload("res://assets/textures/characters/enemy_imbued_stag_attack_1.png")
const _IMBUED_STAG_A2 := preload("res://assets/textures/characters/enemy_imbued_stag_attack_2.png")
const _IMBUED_STAG_A3 := preload("res://assets/textures/characters/enemy_imbued_stag_attack_3.png")
const _IMBUED_STAG_H := preload("res://assets/textures/characters/enemy_imbued_stag_hit.png")
const _IMBUED_STAG_D1 := preload("res://assets/textures/characters/enemy_imbued_stag_death_1.png")
const _IMBUED_STAG_D2 := preload("res://assets/textures/characters/enemy_imbued_stag_death_2.png")
const _IMBUED_STAG_D3 := preload("res://assets/textures/characters/enemy_imbued_stag_death_3.png")
const _MARTARQUAS_SCOUT := preload("res://assets/textures/characters/enemy_martarquas_scout.png")
const _MARTARQUAS_SCOUT_A1 := preload("res://assets/textures/characters/enemy_martarquas_scout_attack_1.png")
const _MARTARQUAS_SCOUT_A2 := preload("res://assets/textures/characters/enemy_martarquas_scout_attack_2.png")
const _MARTARQUAS_SCOUT_A3 := preload("res://assets/textures/characters/enemy_martarquas_scout_attack_3.png")
const _MARTARQUAS_SCOUT_H := preload("res://assets/textures/characters/enemy_martarquas_scout_hit.png")
const _MARTARQUAS_SCOUT_D1 := preload("res://assets/textures/characters/enemy_martarquas_scout_death_1.png")
const _MARTARQUAS_SCOUT_D2 := preload("res://assets/textures/characters/enemy_martarquas_scout_death_2.png")
const _MARTARQUAS_SCOUT_D3 := preload("res://assets/textures/characters/enemy_martarquas_scout_death_3.png")
const _MIMIC := preload("res://assets/textures/characters/enemy_mimic.png")
const _MIMIC_A1 := preload("res://assets/textures/characters/enemy_mimic_attack_1.png")
const _MIMIC_A2 := preload("res://assets/textures/characters/enemy_mimic_attack_2.png")
const _MIMIC_A3 := preload("res://assets/textures/characters/enemy_mimic_attack_3.png")
const _MIMIC_H := preload("res://assets/textures/characters/enemy_mimic_hit.png")
const _MIMIC_D1 := preload("res://assets/textures/characters/enemy_mimic_death_1.png")
const _MIMIC_D2 := preload("res://assets/textures/characters/enemy_mimic_death_2.png")
const _MIMIC_D3 := preload("res://assets/textures/characters/enemy_mimic_death_3.png")
const _RAIDER := preload("res://assets/textures/characters/enemy_raider.png")
const _RAIDER_A1 := preload("res://assets/textures/characters/enemy_raider_attack_1.png")
const _RAIDER_A2 := preload("res://assets/textures/characters/enemy_raider_attack_2.png")
const _RAIDER_A3 := preload("res://assets/textures/characters/enemy_raider_attack_3.png")
const _RAIDER_H := preload("res://assets/textures/characters/enemy_raider_hit.png")
const _RAIDER_D1 := preload("res://assets/textures/characters/enemy_raider_death_1.png")
const _RAIDER_D2 := preload("res://assets/textures/characters/enemy_raider_death_2.png")
const _RAIDER_D3 := preload("res://assets/textures/characters/enemy_raider_death_3.png")
const _RIFT_ECHO := preload("res://assets/textures/characters/enemy_rift_echo.png")
const _RIFT_ECHO_A1 := preload("res://assets/textures/characters/enemy_rift_echo_attack_1.png")
const _RIFT_ECHO_A2 := preload("res://assets/textures/characters/enemy_rift_echo_attack_2.png")
const _RIFT_ECHO_A3 := preload("res://assets/textures/characters/enemy_rift_echo_attack_3.png")
const _RIFT_ECHO_H := preload("res://assets/textures/characters/enemy_rift_echo_hit.png")
const _RIFT_ECHO_D1 := preload("res://assets/textures/characters/enemy_rift_echo_death_1.png")
const _RIFT_ECHO_D2 := preload("res://assets/textures/characters/enemy_rift_echo_death_2.png")
const _RIFT_ECHO_D3 := preload("res://assets/textures/characters/enemy_rift_echo_death_3.png")
const _RIVAL := preload("res://assets/textures/characters/enemy_rival.png")
const _RIVAL_A1 := preload("res://assets/textures/characters/enemy_rival_attack_1.png")
const _RIVAL_A2 := preload("res://assets/textures/characters/enemy_rival_attack_2.png")
const _RIVAL_A3 := preload("res://assets/textures/characters/enemy_rival_attack_3.png")
const _RIVAL_H := preload("res://assets/textures/characters/enemy_rival_hit.png")
const _RIVAL_D1 := preload("res://assets/textures/characters/enemy_rival_death_1.png")
const _RIVAL_D2 := preload("res://assets/textures/characters/enemy_rival_death_2.png")
const _RIVAL_D3 := preload("res://assets/textures/characters/enemy_rival_death_3.png")
const _SCARAB := preload("res://assets/textures/characters/enemy_scarab.png")
const _SCARAB_A1 := preload("res://assets/textures/characters/enemy_scarab_attack_1.png")
const _SCARAB_A2 := preload("res://assets/textures/characters/enemy_scarab_attack_2.png")
const _SCARAB_A3 := preload("res://assets/textures/characters/enemy_scarab_attack_3.png")
const _SCARAB_H := preload("res://assets/textures/characters/enemy_scarab_hit.png")
const _SCARAB_D1 := preload("res://assets/textures/characters/enemy_scarab_death_1.png")
const _SCARAB_D2 := preload("res://assets/textures/characters/enemy_scarab_death_2.png")
const _SCARAB_D3 := preload("res://assets/textures/characters/enemy_scarab_death_3.png")
const _SCARAB_SWARM := preload("res://assets/textures/characters/enemy_scarab_swarm.png")
const _SCARAB_SWARM_A1 := preload("res://assets/textures/characters/enemy_scarab_swarm_attack_1.png")
const _SCARAB_SWARM_A2 := preload("res://assets/textures/characters/enemy_scarab_swarm_attack_2.png")
const _SCARAB_SWARM_A3 := preload("res://assets/textures/characters/enemy_scarab_swarm_attack_3.png")
const _SCARAB_SWARM_H := preload("res://assets/textures/characters/enemy_scarab_swarm_hit.png")
const _SCARAB_SWARM_D1 := preload("res://assets/textures/characters/enemy_scarab_swarm_death_1.png")
const _SCARAB_SWARM_D2 := preload("res://assets/textures/characters/enemy_scarab_swarm_death_2.png")
const _SCARAB_SWARM_D3 := preload("res://assets/textures/characters/enemy_scarab_swarm_death_3.png")
const _SKELETON := preload("res://assets/textures/characters/enemy_skeleton.png")
const _SKELETON_A1 := preload("res://assets/textures/characters/enemy_skeleton_attack_1.png")
const _SKELETON_A2 := preload("res://assets/textures/characters/enemy_skeleton_attack_2.png")
const _SKELETON_A3 := preload("res://assets/textures/characters/enemy_skeleton_attack_3.png")
const _SKELETON_H := preload("res://assets/textures/characters/enemy_skeleton_hit.png")
const _SKELETON_D1 := preload("res://assets/textures/characters/enemy_skeleton_death_1.png")
const _SKELETON_D2 := preload("res://assets/textures/characters/enemy_skeleton_death_2.png")
const _SKELETON_D3 := preload("res://assets/textures/characters/enemy_skeleton_death_3.png")
const _SPECTRE := preload("res://assets/textures/characters/enemy_spectre.png")
const _SPECTRE_A1 := preload("res://assets/textures/characters/enemy_spectre_attack_1.png")
const _SPECTRE_A2 := preload("res://assets/textures/characters/enemy_spectre_attack_2.png")
const _SPECTRE_A3 := preload("res://assets/textures/characters/enemy_spectre_attack_3.png")
const _SPECTRE_H := preload("res://assets/textures/characters/enemy_spectre_hit.png")
const _SPECTRE_D1 := preload("res://assets/textures/characters/enemy_spectre_death_1.png")
const _SPECTRE_D2 := preload("res://assets/textures/characters/enemy_spectre_death_2.png")
const _SPECTRE_D3 := preload("res://assets/textures/characters/enemy_spectre_death_3.png")
const _TERROR := preload("res://assets/textures/characters/enemy_terror.png")
const _TERROR_A1 := preload("res://assets/textures/characters/enemy_terror_attack_1.png")
const _TERROR_A2 := preload("res://assets/textures/characters/enemy_terror_attack_2.png")
const _TERROR_A3 := preload("res://assets/textures/characters/enemy_terror_attack_3.png")
const _TERROR_H := preload("res://assets/textures/characters/enemy_terror_hit.png")
const _TERROR_D1 := preload("res://assets/textures/characters/enemy_terror_death_1.png")
const _TERROR_D2 := preload("res://assets/textures/characters/enemy_terror_death_2.png")
const _TERROR_D3 := preload("res://assets/textures/characters/enemy_terror_death_3.png")
const _UNDEAD_ELITE := preload("res://assets/textures/characters/enemy_undead_elite.png")
const _UNDEAD_ELITE_A1 := preload("res://assets/textures/characters/enemy_undead_elite_attack_1.png")
const _UNDEAD_ELITE_A2 := preload("res://assets/textures/characters/enemy_undead_elite_attack_2.png")
const _UNDEAD_ELITE_A3 := preload("res://assets/textures/characters/enemy_undead_elite_attack_3.png")
const _UNDEAD_ELITE_H := preload("res://assets/textures/characters/enemy_undead_elite_hit.png")
const _UNDEAD_ELITE_D1 := preload("res://assets/textures/characters/enemy_undead_elite_death_1.png")
const _UNDEAD_ELITE_D2 := preload("res://assets/textures/characters/enemy_undead_elite_death_2.png")
const _UNDEAD_ELITE_D3 := preload("res://assets/textures/characters/enemy_undead_elite_death_3.png")
const _WARLEADER := preload("res://assets/textures/characters/enemy_warleader.png")
const _WARLEADER_A1 := preload("res://assets/textures/characters/enemy_warleader_attack_1.png")
const _WARLEADER_A2 := preload("res://assets/textures/characters/enemy_warleader_attack_2.png")
const _WARLEADER_A3 := preload("res://assets/textures/characters/enemy_warleader_attack_3.png")
const _WARLEADER_H := preload("res://assets/textures/characters/enemy_warleader_hit.png")
const _WARLEADER_D1 := preload("res://assets/textures/characters/enemy_warleader_death_1.png")
const _WARLEADER_D2 := preload("res://assets/textures/characters/enemy_warleader_death_2.png")
const _WARLEADER_D3 := preload("res://assets/textures/characters/enemy_warleader_death_3.png")
const _WOLF := preload("res://assets/textures/characters/enemy_wolf.png")
const _WOLF_A1 := preload("res://assets/textures/characters/enemy_wolf_attack_1.png")
const _WOLF_A2 := preload("res://assets/textures/characters/enemy_wolf_attack_2.png")
const _WOLF_A3 := preload("res://assets/textures/characters/enemy_wolf_attack_3.png")
const _WOLF_H := preload("res://assets/textures/characters/enemy_wolf_hit.png")
const _WOLF_D1 := preload("res://assets/textures/characters/enemy_wolf_death_1.png")
const _WOLF_D2 := preload("res://assets/textures/characters/enemy_wolf_death_2.png")
const _WOLF_D3 := preload("res://assets/textures/characters/enemy_wolf_death_3.png")
const _WOLF_PACK := preload("res://assets/textures/characters/enemy_wolf_pack.png")
const _WOLF_PACK_A1 := preload("res://assets/textures/characters/enemy_wolf_pack_attack_1.png")
const _WOLF_PACK_A2 := preload("res://assets/textures/characters/enemy_wolf_pack_attack_2.png")
const _WOLF_PACK_A3 := preload("res://assets/textures/characters/enemy_wolf_pack_attack_3.png")
const _WOLF_PACK_H := preload("res://assets/textures/characters/enemy_wolf_pack_hit.png")
const _WOLF_PACK_D1 := preload("res://assets/textures/characters/enemy_wolf_pack_death_1.png")
const _WOLF_PACK_D2 := preload("res://assets/textures/characters/enemy_wolf_pack_death_2.png")
const _WOLF_PACK_D3 := preload("res://assets/textures/characters/enemy_wolf_pack_death_3.png")
const _ZOMBIE := preload("res://assets/textures/characters/enemy_zombie.png")
const _ZOMBIE_A1 := preload("res://assets/textures/characters/enemy_zombie_attack_1.png")
const _ZOMBIE_A2 := preload("res://assets/textures/characters/enemy_zombie_attack_2.png")
const _ZOMBIE_A3 := preload("res://assets/textures/characters/enemy_zombie_attack_3.png")
const _ZOMBIE_H := preload("res://assets/textures/characters/enemy_zombie_hit.png")
const _ZOMBIE_D1 := preload("res://assets/textures/characters/enemy_zombie_death_1.png")
const _ZOMBIE_D2 := preload("res://assets/textures/characters/enemy_zombie_death_2.png")
const _ZOMBIE_D3 := preload("res://assets/textures/characters/enemy_zombie_death_3.png")

## idle -> [attack frames, hit frame, death frames]
const _TABLE: Dictionary = {
	_BARROW_KING: [
		[_BARROW_KING_A1, _BARROW_KING_A2, _BARROW_KING_A3], _BARROW_KING_H,
		[_BARROW_KING_D1, _BARROW_KING_D2, _BARROW_KING_D3],
	],
	_BOG_HAG: [
		[_BOG_HAG_A1, _BOG_HAG_A2, _BOG_HAG_A3], _BOG_HAG_H,
		[_BOG_HAG_D1, _BOG_HAG_D2, _BOG_HAG_D3],
	],
	_CACTUS_WORM: [
		[_CACTUS_WORM_A1, _CACTUS_WORM_A2, _CACTUS_WORM_A3], _CACTUS_WORM_H,
		[_CACTUS_WORM_D1, _CACTUS_WORM_D2, _CACTUS_WORM_D3],
	],
	_DUELIST: [
		[_DUELIST_A1, _DUELIST_A2, _DUELIST_A3], _DUELIST_H,
		[_DUELIST_D1, _DUELIST_D2, _DUELIST_D3],
	],
	_EMBER_CULTIST: [
		[_EMBER_CULTIST_A1, _EMBER_CULTIST_A2, _EMBER_CULTIST_A3], _EMBER_CULTIST_H,
		[_EMBER_CULTIST_D1, _EMBER_CULTIST_D2, _EMBER_CULTIST_D3],
	],
	_FROST_WENDIGO: [
		[_FROST_WENDIGO_A1, _FROST_WENDIGO_A2, _FROST_WENDIGO_A3], _FROST_WENDIGO_H,
		[_FROST_WENDIGO_D1, _FROST_WENDIGO_D2, _FROST_WENDIGO_D3],
	],
	_GHOUL: [
		[_GHOUL_A1, _GHOUL_A2, _GHOUL_A3], _GHOUL_H,
		[_GHOUL_D1, _GHOUL_D2, _GHOUL_D3],
	],
	_IMBUED_STAG: [
		[_IMBUED_STAG_A1, _IMBUED_STAG_A2, _IMBUED_STAG_A3], _IMBUED_STAG_H,
		[_IMBUED_STAG_D1, _IMBUED_STAG_D2, _IMBUED_STAG_D3],
	],
	_MARTARQUAS_SCOUT: [
		[_MARTARQUAS_SCOUT_A1, _MARTARQUAS_SCOUT_A2, _MARTARQUAS_SCOUT_A3], _MARTARQUAS_SCOUT_H,
		[_MARTARQUAS_SCOUT_D1, _MARTARQUAS_SCOUT_D2, _MARTARQUAS_SCOUT_D3],
	],
	_MIMIC: [
		[_MIMIC_A1, _MIMIC_A2, _MIMIC_A3], _MIMIC_H,
		[_MIMIC_D1, _MIMIC_D2, _MIMIC_D3],
	],
	_RAIDER: [
		[_RAIDER_A1, _RAIDER_A2, _RAIDER_A3], _RAIDER_H,
		[_RAIDER_D1, _RAIDER_D2, _RAIDER_D3],
	],
	_RIFT_ECHO: [
		[_RIFT_ECHO_A1, _RIFT_ECHO_A2, _RIFT_ECHO_A3], _RIFT_ECHO_H,
		[_RIFT_ECHO_D1, _RIFT_ECHO_D2, _RIFT_ECHO_D3],
	],
	_RIVAL: [
		[_RIVAL_A1, _RIVAL_A2, _RIVAL_A3], _RIVAL_H,
		[_RIVAL_D1, _RIVAL_D2, _RIVAL_D3],
	],
	_SCARAB: [
		[_SCARAB_A1, _SCARAB_A2, _SCARAB_A3], _SCARAB_H,
		[_SCARAB_D1, _SCARAB_D2, _SCARAB_D3],
	],
	_SCARAB_SWARM: [
		[_SCARAB_SWARM_A1, _SCARAB_SWARM_A2, _SCARAB_SWARM_A3], _SCARAB_SWARM_H,
		[_SCARAB_SWARM_D1, _SCARAB_SWARM_D2, _SCARAB_SWARM_D3],
	],
	_SKELETON: [
		[_SKELETON_A1, _SKELETON_A2, _SKELETON_A3], _SKELETON_H,
		[_SKELETON_D1, _SKELETON_D2, _SKELETON_D3],
	],
	_SPECTRE: [
		[_SPECTRE_A1, _SPECTRE_A2, _SPECTRE_A3], _SPECTRE_H,
		[_SPECTRE_D1, _SPECTRE_D2, _SPECTRE_D3],
	],
	_TERROR: [
		[_TERROR_A1, _TERROR_A2, _TERROR_A3], _TERROR_H,
		[_TERROR_D1, _TERROR_D2, _TERROR_D3],
	],
	_UNDEAD_ELITE: [
		[_UNDEAD_ELITE_A1, _UNDEAD_ELITE_A2, _UNDEAD_ELITE_A3], _UNDEAD_ELITE_H,
		[_UNDEAD_ELITE_D1, _UNDEAD_ELITE_D2, _UNDEAD_ELITE_D3],
	],
	_WARLEADER: [
		[_WARLEADER_A1, _WARLEADER_A2, _WARLEADER_A3], _WARLEADER_H,
		[_WARLEADER_D1, _WARLEADER_D2, _WARLEADER_D3],
	],
	_WOLF: [
		[_WOLF_A1, _WOLF_A2, _WOLF_A3], _WOLF_H,
		[_WOLF_D1, _WOLF_D2, _WOLF_D3],
	],
	_WOLF_PACK: [
		[_WOLF_PACK_A1, _WOLF_PACK_A2, _WOLF_PACK_A3], _WOLF_PACK_H,
		[_WOLF_PACK_D1, _WOLF_PACK_D2, _WOLF_PACK_D3],
	],
	_ZOMBIE: [
		[_ZOMBIE_A1, _ZOMBIE_A2, _ZOMBIE_A3], _ZOMBIE_H,
		[_ZOMBIE_D1, _ZOMBIE_D2, _ZOMBIE_D3],
	],
}


## {"attack": [3], "hit": Texture2D, "death": [3]} for an idle enemy texture ({} when none).
static func for_idle(idle: Texture2D) -> Dictionary:
	var row: Array = _TABLE.get(idle, []) as Array
	if row.is_empty():
		return {}
	var attack: Array[Texture2D] = []
	attack.assign(row[0] as Array)
	var death: Array[Texture2D] = []
	death.assign(row[2] as Array)
	return {"attack": attack, "hit": row[1] as Texture2D, "death": death}
