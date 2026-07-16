## Registry mapping enemy/NPC types to real sprite textures (GID-118).
##
## Replaces TextureGen's procedural humanoid silhouettes with licensed
## pixel art (see docs/agent/art-sprites.md for sources and licenses).
## Accessors return null for unknown types — callers MUST fall back to
## the matching TextureGen call so the game still runs if a type is
## missing here (same philosophy as AudioManager's no-op on missing SFX).
##
## All textures are literal const preloads — Android export packs only
## statically referenced resources (CLAUDE.md Android rule).
##
## Callers: preload("res://game_logic/SpriteRegistry.gd")
extends RefCounted

const _ENEMY_UNDEAD       := preload("res://assets/textures/characters/enemy_undead.png")
const _ENEMY_UNDEAD_ELITE := preload("res://assets/textures/characters/enemy_undead_elite.png")
const _ENEMY_GHOUL        := preload("res://assets/textures/characters/enemy_ghoul.png")
const _ENEMY_RAIDER       := preload("res://assets/textures/characters/enemy_raider.png")
const _ENEMY_WARLEADER    := preload("res://assets/textures/characters/enemy_warleader.png")
const _ENEMY_DUELIST      := preload("res://assets/textures/characters/enemy_duelist.png")
const _ENEMY_RIVAL        := preload("res://assets/textures/characters/enemy_rival.png")
const _ENEMY_TERROR       := preload("res://assets/textures/characters/enemy_terror.png")
const _ENEMY_MIMIC        := preload("res://assets/textures/characters/enemy_mimic.png")
const _ENEMY_SPECTRE      := preload("res://assets/textures/characters/enemy_spectre.png")

const _NPC_TOWNSPERSON    := preload("res://assets/textures/characters/npc_townsperson.png")
const _NPC_TOWNSPERSON_2  := preload("res://assets/textures/characters/npc_townsperson_2.png")
const _NPC_TOWNSPERSON_3  := preload("res://assets/textures/characters/npc_townsperson_3.png")
const _NPC_MERCHANT       := preload("res://assets/textures/characters/npc_merchant.png")
const _NPC_MERCHANT_TRAV  := preload("res://assets/textures/characters/npc_merchant_traveling.png")
const _NPC_MAITELN        := preload("res://assets/textures/characters/npc_maiteln.png")

## World pixel size for character sprites. The 0x72 pack's humanoids are
## 16-36 px tall (vs the old fixed 32 px silhouettes); 0.05 keeps mid-size
## sprites at roughly the old world height while preserving the pack's
## intentional size hierarchy (small skeletons, big ogres).
const CHAR_PIXEL_SIZE: float = 0.05

## Small lift so billboard sprites never clip below y=0 (CLAUDE.md rule).
const FEET_MARGIN: float = 0.05

## Maps an EnemyRegistry type id to its archetype texture.
## Returns null for unknown/empty ids — caller falls back to TextureGen.enemy().
static func enemy_texture(etype: String, is_roaming_boss: bool = false, is_boss: bool = false) -> Texture2D:
	if is_roaming_boss:
		return _ENEMY_TERROR
	match etype:
		"undead_basic", "undead_horde":
			return _ENEMY_UNDEAD
		"undead_elite":
			return _ENEMY_UNDEAD_ELITE
		"ghoul_pack":
			return _ENEMY_GHOUL
		"martarquas_raider_1", "martarquas_raider_2", "martarquas_raider_3":
			return _ENEMY_RAIDER
		"martarquas_warleader":
			return _ENEMY_WARLEADER
		"duelist_novice", "duelist_adept", "duelist_champion":
			return _ENEMY_DUELIST
		"rival_isfig_1", "rival_isfig_2", "rival_isfig_3":
			return _ENEMY_RIVAL
		"mimic":
			return _ENEMY_MIMIC
		"roaming_terror":
			return _ENEMY_TERROR
		"spectre_wisp", "spectre_haunt", "spectre_dread":
			return _ENEMY_SPECTRE
	if is_boss:
		return _ENEMY_WARLEADER
	return null

## Stable townsperson variant: same seed always yields the same look.
static func townsperson_texture(variant_seed: int) -> Texture2D:
	match absi(variant_seed) % 3:
		1: return _NPC_TOWNSPERSON_2
		2: return _NPC_TOWNSPERSON_3
	return _NPC_TOWNSPERSON

static func merchant_texture(is_traveling: bool) -> Texture2D:
	return _NPC_MERCHANT_TRAV if is_traveling else _NPC_MERCHANT

static func maiteln_texture() -> Texture2D:
	return _NPC_MAITELN

## Martarquas scout sprite for ScoutAmbush (raider archetype).
static func raider_texture() -> Texture2D:
	return _ENEMY_RAIDER

## Applies a registry texture to a Sprite3D: texture, pixel size, and the
## feet-at-y=0 position computed from the real texture height (never assume
## a fixed 32 px — pack sprites range 16-36 px).
static func setup_sprite(sprite: Sprite3D, tex: Texture2D, pixel_size: float = CHAR_PIXEL_SIZE) -> void:
	sprite.texture = tex
	sprite.pixel_size = pixel_size
	sprite.position = Vector3(0.0, float(tex.get_height()) * pixel_size * 0.5 + FEET_MARGIN, 0.0)
