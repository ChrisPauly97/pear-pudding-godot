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

const _CHEST_CLOSED       := preload("res://assets/textures/props/chest_closed.png")
const _CHEST_OPEN         := preload("res://assets/textures/props/chest_open.png")
const _DOOR               := preload("res://assets/textures/props/door.png")

const _WAYSTONE_DORMANT   := preload("res://assets/textures/props/waystone_dormant.png")
const _WAYSTONE_ACTIVE    := preload("res://assets/textures/props/waystone_active.png")
const _MANA_WELL          := preload("res://assets/textures/props/mana_well.png")
const _PUZZLE_SHRINE      := preload("res://assets/textures/props/puzzle_shrine.png")
const _BURIAL_MOUND       := preload("res://assets/textures/props/burial_mound.png")
const _BLIGHT_HEART       := preload("res://assets/textures/props/blight_heart.png")

## World pixel size for character sprites. The 0x72 pack's humanoids are
## 16-36 px tall (vs the old fixed 32 px silhouettes); 0.05 keeps mid-size
## sprites at roughly the old world height while preserving the pack's
## intentional size hierarchy (small skeletons, big ogres).
const CHAR_PIXEL_SIZE: float = 0.05

## Small lift so billboard sprites never clip below y=0 (CLAUDE.md rule).
const FEET_MARGIN: float = 0.05

## Target world heights (units) so every entity is proportional to the
## player (elf_m hero, 28 px at 0.05 = 1.4 units). A flat pixel size made
## 16 px pack sprites render at half the player's height — scale by target
## height instead, keeping an intentional hierarchy: chest-sized mimics,
## person-sized enemies/NPCs, towering bosses.
const PLAYER_HEIGHT: float = 1.4
const HEIGHT_SMALL_UNDEAD: float = 1.15   # skeletons, ghouls (16 px sources)
const HEIGHT_SPECTRE: float = 1.05        # floaty night-hunt ghosts
const HEIGHT_MIMIC: float = 0.85          # disguised as a chest (chest = 0.8)
const HEIGHT_SOLDIER: float = 1.25        # raiders, duelists (23 px sources)
const HEIGHT_RIVAL: float = 1.4           # rival duelist — mirrors the player
const HEIGHT_BOSS: float = 1.9            # warleader/terror, before node scale
const HEIGHT_NPC: float = 1.4             # townsfolk, Maiteln
const HEIGHT_MERCHANT: float = 1.3

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

## Target world height for an enemy sprite, matching enemy_texture()'s
## archetype routing. Keeps every enemy proportional to the player
## regardless of the source sprite's pixel height.
static func enemy_world_height(etype: String, is_roaming_boss: bool = false, is_boss: bool = false) -> float:
	if is_roaming_boss:
		return HEIGHT_BOSS
	match etype:
		"undead_basic", "undead_horde", "undead_elite", "ghoul_pack":
			return HEIGHT_SMALL_UNDEAD
		"martarquas_raider_1", "martarquas_raider_2", "martarquas_raider_3":
			return HEIGHT_SOLDIER
		"duelist_novice", "duelist_adept", "duelist_champion":
			return HEIGHT_SOLDIER
		"rival_isfig_1", "rival_isfig_2", "rival_isfig_3":
			return HEIGHT_RIVAL
		"mimic":
			return HEIGHT_MIMIC
		"martarquas_warleader", "roaming_terror":
			return HEIGHT_BOSS
		"spectre_wisp", "spectre_haunt", "spectre_dread":
			return HEIGHT_SPECTRE
	if is_boss:
		return HEIGHT_BOSS
	return HEIGHT_SOLDIER

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

## Closed-chest sprite (with lock) — Chest.gd's unopened / default pose.
static func chest_closed_texture() -> Texture2D:
	return _CHEST_CLOSED

## Open-chest sprite (revealing contents) — Chest.gd's opened pose.
static func chest_open_texture() -> Texture2D:
	return _CHEST_OPEN

## Door portal sprite (Door.gd) — used for every map-transition door
## (player home, guildhall, shops, dungeon/ruin entries). The spire door's
## purple tint is applied as a Sprite3D modulate by the caller, not baked
## into a separate texture.
static func door_texture() -> Texture2D:
	return _DOOR

## Dormant (cool stone) / active (gold runes) fast-travel obelisk sprites.
static func waystone_texture(active: bool) -> Texture2D:
	return _WAYSTONE_ACTIVE if active else _WAYSTONE_DORMANT

static func mana_well_texture() -> Texture2D:
	return _MANA_WELL

static func puzzle_shrine_texture() -> Texture2D:
	return _PUZZLE_SHRINE

static func burial_mound_texture() -> Texture2D:
	return _BURIAL_MOUND

static func blight_heart_texture() -> Texture2D:
	return _BLIGHT_HEART

## The floating name tag every world NPC carries above its sprite.
static func make_name_label(text: String, tint: Color) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 32
	lbl.pixel_size = 0.025
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = Vector3(0.0, 2.0, 0.0)
	lbl.modulate = tint
	return lbl

## Builds a world-entity billboard: the registry texture scaled to `world_height`
## when one exists, otherwise `fallback_tex` at the legacy generated-art size.
## Applies the billboard/alpha/filter settings every world sprite shares.
static func make_billboard(tex: Texture2D, fallback_tex: Texture2D, world_height: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	if tex != null:
		setup_sprite_height(sprite, tex, world_height)
	else:
		sprite.texture = fallback_tex
		sprite.pixel_size = 0.04
		sprite.position = Vector3(0.0, 0.69, 0.0)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return sprite

## Applies a registry texture to a Sprite3D: texture, pixel size, and the
## feet-at-y=0 position computed from the real texture height (never assume
## a fixed 32 px — pack sprites range 16-36 px).
static func setup_sprite(sprite: Sprite3D, tex: Texture2D, pixel_size: float = CHAR_PIXEL_SIZE) -> void:
	sprite.texture = tex
	sprite.pixel_size = pixel_size
	sprite.position = Vector3(0.0, float(tex.get_height()) * pixel_size * 0.5 + FEET_MARGIN, 0.0)

## Like setup_sprite, but scales the sprite to a target world height
## instead of a fixed pixel size — source sprites range 16-48 px, so a
## flat pixel size breaks proportions between them.
static func setup_sprite_height(sprite: Sprite3D, tex: Texture2D, world_height: float) -> void:
	setup_sprite(sprite, tex, world_height / float(tex.get_height()))
