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
const _NPC_MAITELN_WALK_1 := preload("res://assets/textures/characters/npc_maiteln_walk_1.png")
const _NPC_MAITELN_WALK_2 := preload("res://assets/textures/characters/npc_maiteln_walk_2.png")
const _NPC_MAITELN_WALK_3 := preload("res://assets/textures/characters/npc_maiteln_walk_3.png")
const _NPC_MAITELN_WALK_4 := preload("res://assets/textures/characters/npc_maiteln_walk_4.png")

const _MOUNT_HORSE        := preload("res://assets/textures/characters/mount_horse.png")

const _PROP_ROCK          := preload("res://assets/textures/props/prop_rock.png")
const _PROP_FLOWER        := preload("res://assets/textures/props/prop_flower.png")
const _PROP_MUSHROOM      := preload("res://assets/textures/props/prop_mushroom.png")
const _PROP_FERN          := preload("res://assets/textures/props/prop_fern.png")
const _PROP_CACTUS        := preload("res://assets/textures/props/prop_cactus.png")
const _PROP_THORN         := preload("res://assets/textures/props/prop_thorn.png")
const _PROP_ASH_PILE      := preload("res://assets/textures/props/prop_ash_pile.png")
const _PROP_EMBER         := preload("res://assets/textures/props/prop_ember.png")
const _PROP_BOULDER       := preload("res://assets/textures/props/prop_boulder.png")
const _PROP_LICHEN        := preload("res://assets/textures/props/prop_lichen.png")

const _CARD_GHOST         := preload("res://assets/textures/cards/card_ghost.png")
const _CARD_SKELETON      := preload("res://assets/textures/cards/card_skeleton.png")
const _CARD_ZOMBIE        := preload("res://assets/textures/cards/card_zombie.png")
const _CARD_GHOUL         := preload("res://assets/textures/cards/card_ghoul.png")
const _RUNE_DAWN          := preload("res://assets/textures/cards/rune_dawn.png")
const _RUNE_DUSK          := preload("res://assets/textures/cards/rune_dusk.png")
const _RUNE_EMBER         := preload("res://assets/textures/cards/rune_ember.png")
const _RUNE_ASH           := preload("res://assets/textures/cards/rune_ash.png")

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

## 4-frame walk cycle for Maiteln's AnimatedSprite3D (BID-051). Empty if the
## walk PNGs are ever removed — caller checks size before building animation
## frames and falls back to a static Sprite3D.
static func maiteln_walk_frames() -> Array[Texture2D]:
	return [_NPC_MAITELN_WALK_1, _NPC_MAITELN_WALK_2, _NPC_MAITELN_WALK_3, _NPC_MAITELN_WALK_4]

## Martarquas scout sprite for ScoutAmbush (raider archetype).
static func raider_texture() -> Texture2D:
	return _ENEMY_RAIDER

static func mount_texture() -> Texture2D:
	return _MOUNT_HORSE

## Maps a BiomeDef.PROP_SETS key to its texture. Returns null for unknown keys
## (caller falls back to TextureGen.prop()). Key strings must match PROP_SETS/
## TextureGen exactly — the biome props use "ash_pile", not "ash".
static func prop_texture(key: String) -> Texture2D:
	match key:
		"rock":     return _PROP_ROCK
		"flower":   return _PROP_FLOWER
		"mushroom": return _PROP_MUSHROOM
		"fern":     return _PROP_FERN
		"cactus":   return _PROP_CACTUS
		"thorn":    return _PROP_THORN
		"ash_pile": return _PROP_ASH_PILE
		"ember":    return _PROP_EMBER
		"boulder":  return _PROP_BOULDER
		"lichen":   return _PROP_LICHEN
	return null

## Maps a card illustration key + magic branch to its texture.
## illus_key is "ghost"/"skeleton"/"zombie"/"ghoul" for minions, or "spell"
## (any non-creature key) for spell cards, which route by magic_branch
## instead. Returns null for an unrecognized key/branch combination —
## caller falls back to TextureGen.card_illustration().
static func card_illustration_texture(illus_key: String, magic_branch: String) -> Texture2D:
	match illus_key:
		"ghost":    return _CARD_GHOST
		"skeleton": return _CARD_SKELETON
		"zombie":   return _CARD_ZOMBIE
		"ghoul":    return _CARD_GHOUL
	match magic_branch:
		"dawn":  return _RUNE_DAWN
		"dusk":  return _RUNE_DUSK
		"ember": return _RUNE_EMBER
		"ash":   return _RUNE_ASH
	return null

## Applies a registry texture to a Sprite3D: texture, pixel size, and the
## feet-at-y=0 position computed from the real texture height (never assume
## a fixed 32 px — pack sprites range 16-36 px).
static func setup_sprite(sprite: Sprite3D, tex: Texture2D, pixel_size: float = CHAR_PIXEL_SIZE) -> void:
	sprite.texture = tex
	sprite.pixel_size = pixel_size
	sprite.position = Vector3(0.0, float(tex.get_height()) * pixel_size * 0.5 + FEET_MARGIN, 0.0)
