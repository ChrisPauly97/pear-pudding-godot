const WeaponData = preload("res://data/WeaponData.gd")
const RegistryUtil = preload("res://game_logic/RegistryUtil.gd")

const _W_ARCANE_FOCUS   := preload("res://data/weapons/arcane_focus.tres")
const _W_BERSERKER_AXE  := preload("res://data/weapons/berserker_axe.tres")
const _W_BONE_CHARM     := preload("res://data/weapons/bone_charm.tres")
const _W_BUCKLER        := preload("res://data/weapons/buckler.tres")
const _W_CHAINMAIL      := preload("res://data/weapons/chainmail.tres")
const _W_DAWN_STAFF     := preload("res://data/weapons/dawn_staff.tres")
const _W_DUSK_BLADE     := preload("res://data/weapons/dusk_blade.tres")
const _W_EMBER_FLASK    := preload("res://data/weapons/ember_flask.tres")
const _W_EMBER_WAND     := preload("res://data/weapons/ember_wand.tres")
const _W_IRON_SHIELD    := preload("res://data/weapons/iron_shield.tres")
const _W_LEATHER_VEST   := preload("res://data/weapons/leather_vest.tres")
const _W_LEATHER_PAULDRONS := preload("res://data/weapons/leather_pauldrons.tres")
const _W_IRON_PAULDRONS := preload("res://data/weapons/iron_pauldrons.tres")
const _W_SPIKED_SPAULDERS := preload("res://data/weapons/spiked_spaulders.tres")
const _W_LEATHER_CAP    := preload("res://data/weapons/leather_cap.tres")
const _W_IRON_HELM      := preload("res://data/weapons/iron_helm.tres")
const _W_HOODED_COWL    := preload("res://data/weapons/hooded_cowl.tres")
const _W_TRAVEL_BOOTS   := preload("res://data/weapons/travel_boots.tres")
const _W_IRON_GREAVES   := preload("res://data/weapons/iron_greaves.tres")
const _W_SPURRED_BOOTS  := preload("res://data/weapons/spurred_boots.tres")
const _W_LUCKY_COIN     := preload("res://data/weapons/lucky_coin.tres")
const _W_MANA_CRYSTAL   := preload("res://data/weapons/mana_crystal.tres")
const _W_OBSIDIAN_LOOP  := preload("res://data/weapons/obsidian_loop.tres")
const _W_PARRYING_DAGGER := preload("res://data/weapons/parrying_dagger.tres")
const _W_RING_OF_FOCUS  := preload("res://data/weapons/ring_of_focus.tres")
const _W_RUSTY_DAGGER   := preload("res://data/weapons/rusty_dagger.tres")
const _W_SCHOLAR_BAND   := preload("res://data/weapons/scholar_band.tres")
const _W_WARDED_CLOAK   := preload("res://data/weapons/warded_cloak.tres")
const _W_PADDED_JERKIN := preload("res://data/weapons/padded_jerkin.tres")
const _W_SCALE_BIB := preload("res://data/weapons/scale_bib.tres")
const _W_FELT_CAP := preload("res://data/weapons/felt_cap.tres")
const _W_PLAIN_BASCINET := preload("res://data/weapons/plain_bascinet.tres")
const _W_WICKER_PADS := preload("res://data/weapons/wicker_pads.tres")
const _W_TANNED_MANTLE := preload("res://data/weapons/tanned_mantle.tres")
const _W_ROAD_SHOES := preload("res://data/weapons/road_shoes.tres")
const _W_IRON_CLOGS := preload("res://data/weapons/iron_clogs.tres")
const _W_OAK_BOARD := preload("res://data/weapons/oak_board.tres")
const _W_SIGIL_TILE := preload("res://data/weapons/sigil_tile.tres")
const _W_COPPER_BAND := preload("res://data/weapons/copper_band.tres")
const _W_TALLOW_SIGNET := preload("res://data/weapons/tallow_signet.tres")
const _W_BRASS_KNUCKLE_CHARM := preload("res://data/weapons/brass_knuckle_charm.tres")
const _W_RIVER_PEBBLE := preload("res://data/weapons/river_pebble.tres")
const _W_SHARPENED_SHIV := preload("res://data/weapons/sharpened_shiv.tres")
const _W_APPRENTICE_WAND := preload("res://data/weapons/apprentice_wand.tres")
const _W_MILITIA_SHORTSWORD := preload("res://data/weapons/militia_shortsword.tres")
const _W_WALKING_STAFF := preload("res://data/weapons/walking_staff.tres")
const _W_HAND_HATCHET := preload("res://data/weapons/hand_hatchet.tres")
const _W_QUILTED_GAMBESON := preload("res://data/weapons/quilted_gambeson.tres")
const _W_SCHOLARS_JERKIN := preload("res://data/weapons/scholars_jerkin.tres")
const _W_KETTLE_HAT := preload("res://data/weapons/kettle_hat.tres")
const _W_SILVER_CIRCLET := preload("res://data/weapons/silver_circlet.tres")
const _W_REINFORCED_PAULDRONS := preload("res://data/weapons/reinforced_pauldrons.tres")
const _W_DUELISTS_SPAULDERS := preload("res://data/weapons/duelists_spaulders.tres")
const _W_MARSH_BOOTS := preload("res://data/weapons/marsh_boots.tres")
const _W_WINDRUNNER_BOOTS := preload("res://data/weapons/windrunner_boots.tres")
const _W_OAK_KITE_SHIELD := preload("res://data/weapons/oak_kite_shield.tres")
const _W_WARDING_TOME := preload("res://data/weapons/warding_tome.tres")
const _W_GARNET_RING := preload("res://data/weapons/garnet_ring.tres")
const _W_RING_OF_SPARKS := preload("res://data/weapons/ring_of_sparks.tres")
const _W_BRONZE_COMPASS := preload("res://data/weapons/bronze_compass.tres")
const _W_AMBER_PENDANT := preload("res://data/weapons/amber_pendant.tres")
const _W_FERROUS_DAGGER := preload("res://data/weapons/ferrous_dagger.tres")
const _W_ASH_WAND := preload("res://data/weapons/ash_wand.tres")
const _W_HUNTERS_BLADE := preload("res://data/weapons/hunters_blade.tres")
const _W_LANTERN_STAFF := preload("res://data/weapons/lantern_staff.tres")
const _W_WOODSMANS_AXE := preload("res://data/weapons/woodsmans_axe.tres")
const _W_IRONBOUND_HAUBERK := preload("res://data/weapons/ironbound_hauberk.tres")
const _W_STARWEAVE_ROBE := preload("res://data/weapons/starweave_robe.tres")
const _W_WARDED_GREATHELM := preload("res://data/weapons/warded_greathelm.tres")
const _W_LIGHTBOUND_CIRCLET := preload("res://data/weapons/lightbound_circlet.tres")
const _W_STONEBARK_PAULDRONS := preload("res://data/weapons/stonebark_pauldrons.tres")
const _W_RAZORWIND_SPAULDERS := preload("res://data/weapons/razorwind_spaulders.tres")
const _W_STONEHEEL_BOOTS := preload("res://data/weapons/stoneheel_boots.tres")
const _W_EMBERSTEP_BOOTS := preload("res://data/weapons/emberstep_boots.tres")
const _W_LARIK_BULWARK := preload("res://data/weapons/larik_bulwark.tres")
const _W_WARDING_CODEX := preload("res://data/weapons/warding_codex.tres")
const _W_GREYJADE_RING := preload("res://data/weapons/greyjade_ring.tres")
const _W_DUSKGLASS_RING := preload("res://data/weapons/duskglass_ring.tres")
const _W_HUNTERS_TOTEM := preload("res://data/weapons/hunters_totem.tres")
const _W_VERDANT_LOCKET := preload("res://data/weapons/verdant_locket.tres")
const _W_TEMPERED_DIRK := preload("res://data/weapons/tempered_dirk.tres")
const _W_SAPPHIRE_WAND := preload("res://data/weapons/sapphire_wand.tres")
const _W_VEILSTEEL_BLADE := preload("res://data/weapons/veilsteel_blade.tres")
const _W_VERDANT_STAFF := preload("res://data/weapons/verdant_staff.tres")
const _W_RIVERFALL_AXE := preload("res://data/weapons/riverfall_axe.tres")
const _W_BULWARK_PLATE := preload("res://data/weapons/bulwark_plate.tres")
const _W_ARCHMAGES_VESTMENT := preload("res://data/weapons/archmages_vestment.tres")
const _W_TOWER_GREATHELM := preload("res://data/weapons/tower_greathelm.tres")
const _W_STARCROWN_CIRCLET := preload("res://data/weapons/starcrown_circlet.tres")
const _W_AEGIS_PAULDRONS := preload("res://data/weapons/aegis_pauldrons.tres")
const _W_WRAITHWING_SPAULDERS := preload("res://data/weapons/wraithwing_spaulders.tres")
const _W_GREATWARDEN_BOOTS := preload("res://data/weapons/greatwarden_boots.tres")
const _W_WINDRUNNER_GREAVES := preload("res://data/weapons/windrunner_greaves.tres")
const _W_BASTION_SHIELD := preload("res://data/weapons/bastion_shield.tres")
const _W_WARDING_LEXICON := preload("res://data/weapons/warding_lexicon.tres")
const _W_SIGNET_OF_STEADFASTNESS := preload("res://data/weapons/signet_of_steadfastness.tres")
const _W_RING_OF_VERDANT_SPARKS := preload("res://data/weapons/ring_of_verdant_sparks.tres")
const _W_BEHEMOTH_FANG := preload("res://data/weapons/behemoth_fang.tres")
const _W_RIFT_PRISM := preload("res://data/weapons/rift_prism.tres")
const _W_DAWNSTEEL_DIRK := preload("res://data/weapons/dawnsteel_dirk.tres")
const _W_STORMGLASS_WAND := preload("res://data/weapons/stormglass_wand.tres")
const _W_LIONHEART_BLADE := preload("res://data/weapons/lionheart_blade.tres")
const _W_TIDEWARDEN_STAFF := preload("res://data/weapons/tidewarden_staff.tres")
const _W_IRONFALL_AXE := preload("res://data/weapons/ironfall_axe.tres")
const _W_OATHKEEPERS_CUIRASS := preload("res://data/weapons/oathkeepers_cuirass.tres")
const _W_MANTLE_OF_THE_TELLERS := preload("res://data/weapons/mantle_of_the_tellers.tres")
const _W_ELDARS_CROWN_OF_ASH := preload("res://data/weapons/eldars_crown_of_ash.tres")
const _W_MAITELN_SEEING_CROWN := preload("res://data/weapons/maiteln_seeing_crown.tres")
const _W_MADRIAN_BASTION_PAULDRONS := preload("res://data/weapons/madrian_bastion_pauldrons.tres")
const _W_FARSYTHS_DUELLING_MANTLE := preload("res://data/weapons/farsyths_duelling_mantle.tres")
const _W_GREAVES_OF_THE_LONG_ROAD := preload("res://data/weapons/greaves_of_the_long_road.tres")
const _W_STORMSTEP_BOOTS := preload("res://data/weapons/stormstep_boots.tres")
const _W_AEGIS_OF_BLANCOGOV := preload("res://data/weapons/aegis_of_blancogov.tres")
const _W_TOME_OF_SAIMTAR := preload("res://data/weapons/tome_of_saimtar.tres")
const _W_LARIK_OATH_RING := preload("res://data/weapons/larik_oath_ring.tres")
const _W_STARFALL_BAND := preload("res://data/weapons/starfall_band.tres")
const _W_MADRIAN_RELIQUARY := preload("res://data/weapons/madrian_reliquary.tres")
const _W_RIFT_SHARD_PENDANT := preload("res://data/weapons/rift_shard_pendant.tres")
const _W_SAIMTARS_LAST_WORD := preload("res://data/weapons/saimtars_last_word.tres")
const _W_MAITELN_LANTERN_ROD := preload("res://data/weapons/maiteln_lantern_rod.tres")
const _W_ELDARS_SUNDERBLADE := preload("res://data/weapons/eldars_sunderblade.tres")
const _W_LARIK_STARLIGHT_STAFF := preload("res://data/weapons/larik_starlight_staff.tres")
const _W_BLANCOGOV_THUNDERBRAND := preload("res://data/weapons/blancogov_thunderbrand.tres")
# GID-187 / TID-793: fill-in tiers so every slot has an item within ~4 levels of the curve.
const _W_RIVETED_HAUBERK := preload("res://data/weapons/riveted_hauberk.tres")
const _W_STEELBOUND_HAUBERK := preload("res://data/weapons/steelbound_hauberk.tres")
const _W_WARDWOVEN_HAUBERK := preload("res://data/weapons/wardwoven_hauberk.tres")
const _W_RUNECUT_HAUBERK := preload("res://data/weapons/runecut_hauberk.tres")
const _W_WARDENGUARD_HAUBERK := preload("res://data/weapons/wardenguard_hauberk.tres")
const _W_STARFORGED_HAUBERK := preload("res://data/weapons/starforged_hauberk.tres")
const _W_RIVETED_HELM := preload("res://data/weapons/riveted_helm.tres")
const _W_STEELBOUND_HELM := preload("res://data/weapons/steelbound_helm.tres")
const _W_WARDWOVEN_HELM := preload("res://data/weapons/wardwoven_helm.tres")
const _W_RUNECUT_HELM := preload("res://data/weapons/runecut_helm.tres")
const _W_WARDENGUARD_HELM := preload("res://data/weapons/wardenguard_helm.tres")
const _W_STARFORGED_HELM := preload("res://data/weapons/starforged_helm.tres")
const _W_RIVETED_PAULDRONS := preload("res://data/weapons/riveted_pauldrons.tres")
const _W_STEELBOUND_PAULDRONS := preload("res://data/weapons/steelbound_pauldrons.tres")
const _W_WARDWOVEN_PAULDRONS := preload("res://data/weapons/wardwoven_pauldrons.tres")
const _W_RUNECUT_PAULDRONS := preload("res://data/weapons/runecut_pauldrons.tres")
const _W_WARDENGUARD_PAULDRONS := preload("res://data/weapons/wardenguard_pauldrons.tres")
const _W_STARFORGED_PAULDRONS := preload("res://data/weapons/starforged_pauldrons.tres")
const _W_RIVETED_BOOTS := preload("res://data/weapons/riveted_boots.tres")
const _W_STEELBOUND_BOOTS := preload("res://data/weapons/steelbound_boots.tres")
const _W_WARDWOVEN_BOOTS := preload("res://data/weapons/wardwoven_boots.tres")
const _W_RUNECUT_BOOTS := preload("res://data/weapons/runecut_boots.tres")
const _W_WARDENGUARD_BOOTS := preload("res://data/weapons/wardenguard_boots.tres")
const _W_STARFORGED_BOOTS := preload("res://data/weapons/starforged_boots.tres")
const _W_RIVETED_SHIELD := preload("res://data/weapons/riveted_shield.tres")
const _W_STEELBOUND_SHIELD := preload("res://data/weapons/steelbound_shield.tres")
const _W_WARDWOVEN_SHIELD := preload("res://data/weapons/wardwoven_shield.tres")
const _W_RUNECUT_SHIELD := preload("res://data/weapons/runecut_shield.tres")
const _W_WARDENGUARD_SHIELD := preload("res://data/weapons/wardenguard_shield.tres")
const _W_STARFORGED_SHIELD := preload("res://data/weapons/starforged_shield.tres")
const _W_RIVETED_RING := preload("res://data/weapons/riveted_ring.tres")
const _W_STEELBOUND_RING := preload("res://data/weapons/steelbound_ring.tres")
const _W_WARDWOVEN_RING := preload("res://data/weapons/wardwoven_ring.tres")
const _W_RUNECUT_RING := preload("res://data/weapons/runecut_ring.tres")
const _W_WARDENGUARD_RING := preload("res://data/weapons/wardenguard_ring.tres")
const _W_STARFORGED_RING := preload("res://data/weapons/starforged_ring.tres")
const _W_RIVETED_CHARM := preload("res://data/weapons/riveted_charm.tres")
const _W_STEELBOUND_CHARM := preload("res://data/weapons/steelbound_charm.tres")
const _W_WARDWOVEN_CHARM := preload("res://data/weapons/wardwoven_charm.tres")
const _W_RUNECUT_CHARM := preload("res://data/weapons/runecut_charm.tres")
const _W_WARDENGUARD_CHARM := preload("res://data/weapons/wardenguard_charm.tres")
const _W_STARFORGED_CHARM := preload("res://data/weapons/starforged_charm.tres")

static var _weapons: Dictionary = {}  # id -> WeaponData
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_weapons = RegistryUtil.build_id_dict([
		_W_ARCANE_FOCUS, _W_BERSERKER_AXE, _W_BONE_CHARM, _W_BUCKLER, _W_CHAINMAIL,
		_W_DAWN_STAFF, _W_DUSK_BLADE, _W_EMBER_FLASK, _W_EMBER_WAND, _W_IRON_SHIELD,
		_W_LEATHER_VEST, _W_LUCKY_COIN, _W_MANA_CRYSTAL, _W_OBSIDIAN_LOOP,
		_W_PARRYING_DAGGER, _W_RING_OF_FOCUS, _W_RUSTY_DAGGER,
		_W_SCHOLAR_BAND, _W_WARDED_CLOAK,
		_W_LEATHER_PAULDRONS, _W_IRON_PAULDRONS, _W_SPIKED_SPAULDERS,
		_W_LEATHER_CAP, _W_IRON_HELM, _W_HOODED_COWL,
		_W_TRAVEL_BOOTS, _W_IRON_GREAVES, _W_SPURRED_BOOTS,
		_W_PADDED_JERKIN, _W_SCALE_BIB, _W_FELT_CAP, _W_PLAIN_BASCINET,
		_W_WICKER_PADS, _W_TANNED_MANTLE, _W_ROAD_SHOES, _W_IRON_CLOGS,
		_W_OAK_BOARD, _W_SIGIL_TILE, _W_COPPER_BAND, _W_TALLOW_SIGNET,
		_W_BRASS_KNUCKLE_CHARM, _W_RIVER_PEBBLE, _W_SHARPENED_SHIV, _W_APPRENTICE_WAND,
		_W_MILITIA_SHORTSWORD, _W_WALKING_STAFF, _W_HAND_HATCHET, _W_QUILTED_GAMBESON,
		_W_SCHOLARS_JERKIN, _W_KETTLE_HAT, _W_SILVER_CIRCLET, _W_REINFORCED_PAULDRONS,
		_W_DUELISTS_SPAULDERS, _W_MARSH_BOOTS, _W_WINDRUNNER_BOOTS, _W_OAK_KITE_SHIELD,
		_W_WARDING_TOME, _W_GARNET_RING, _W_RING_OF_SPARKS, _W_BRONZE_COMPASS,
		_W_AMBER_PENDANT, _W_FERROUS_DAGGER, _W_ASH_WAND, _W_HUNTERS_BLADE,
		_W_LANTERN_STAFF, _W_WOODSMANS_AXE, _W_IRONBOUND_HAUBERK, _W_STARWEAVE_ROBE,
		_W_WARDED_GREATHELM, _W_LIGHTBOUND_CIRCLET, _W_STONEBARK_PAULDRONS, _W_RAZORWIND_SPAULDERS,
		_W_STONEHEEL_BOOTS, _W_EMBERSTEP_BOOTS, _W_LARIK_BULWARK, _W_WARDING_CODEX,
		_W_GREYJADE_RING, _W_DUSKGLASS_RING, _W_HUNTERS_TOTEM, _W_VERDANT_LOCKET,
		_W_TEMPERED_DIRK, _W_SAPPHIRE_WAND, _W_VEILSTEEL_BLADE, _W_VERDANT_STAFF,
		_W_RIVERFALL_AXE, _W_BULWARK_PLATE, _W_ARCHMAGES_VESTMENT, _W_TOWER_GREATHELM,
		_W_STARCROWN_CIRCLET, _W_AEGIS_PAULDRONS, _W_WRAITHWING_SPAULDERS, _W_GREATWARDEN_BOOTS,
		_W_WINDRUNNER_GREAVES, _W_BASTION_SHIELD, _W_WARDING_LEXICON, _W_SIGNET_OF_STEADFASTNESS,
		_W_RING_OF_VERDANT_SPARKS, _W_BEHEMOTH_FANG, _W_RIFT_PRISM, _W_DAWNSTEEL_DIRK,
		_W_STORMGLASS_WAND, _W_LIONHEART_BLADE, _W_TIDEWARDEN_STAFF, _W_IRONFALL_AXE,
		_W_OATHKEEPERS_CUIRASS, _W_MANTLE_OF_THE_TELLERS, _W_ELDARS_CROWN_OF_ASH, _W_MAITELN_SEEING_CROWN,
		_W_MADRIAN_BASTION_PAULDRONS, _W_FARSYTHS_DUELLING_MANTLE, _W_GREAVES_OF_THE_LONG_ROAD, _W_STORMSTEP_BOOTS,
		_W_AEGIS_OF_BLANCOGOV, _W_TOME_OF_SAIMTAR, _W_LARIK_OATH_RING, _W_STARFALL_BAND,
		_W_MADRIAN_RELIQUARY, _W_RIFT_SHARD_PENDANT, _W_SAIMTARS_LAST_WORD, _W_MAITELN_LANTERN_ROD,
		_W_ELDARS_SUNDERBLADE, _W_LARIK_STARLIGHT_STAFF, _W_BLANCOGOV_THUNDERBRAND,
		_W_RIVETED_HAUBERK,
		_W_STEELBOUND_HAUBERK,
		_W_WARDWOVEN_HAUBERK,
		_W_RUNECUT_HAUBERK,
		_W_WARDENGUARD_HAUBERK,
		_W_STARFORGED_HAUBERK,
		_W_RIVETED_HELM,
		_W_STEELBOUND_HELM,
		_W_WARDWOVEN_HELM,
		_W_RUNECUT_HELM,
		_W_WARDENGUARD_HELM,
		_W_STARFORGED_HELM,
		_W_RIVETED_PAULDRONS,
		_W_STEELBOUND_PAULDRONS,
		_W_WARDWOVEN_PAULDRONS,
		_W_RUNECUT_PAULDRONS,
		_W_WARDENGUARD_PAULDRONS,
		_W_STARFORGED_PAULDRONS,
		_W_RIVETED_BOOTS,
		_W_STEELBOUND_BOOTS,
		_W_WARDWOVEN_BOOTS,
		_W_RUNECUT_BOOTS,
		_W_WARDENGUARD_BOOTS,
		_W_STARFORGED_BOOTS,
		_W_RIVETED_SHIELD,
		_W_STEELBOUND_SHIELD,
		_W_WARDWOVEN_SHIELD,
		_W_RUNECUT_SHIELD,
		_W_WARDENGUARD_SHIELD,
		_W_STARFORGED_SHIELD,
		_W_RIVETED_RING,
		_W_STEELBOUND_RING,
		_W_WARDWOVEN_RING,
		_W_RUNECUT_RING,
		_W_WARDENGUARD_RING,
		_W_STARFORGED_RING,
		_W_RIVETED_CHARM,
		_W_STEELBOUND_CHARM,
		_W_WARDWOVEN_CHARM,
		_W_RUNECUT_CHARM,
		_W_WARDENGUARD_CHARM,
		_W_STARFORGED_CHARM,
	], "WeaponRegistry")

## Returns the WeaponData for the given id, or null if not found.
static func get_weapon(id: String) -> WeaponData:
	_ensure_loaded()
	if _weapons.has(id):
		return _weapons[id] as WeaponData
	return null

## Returns true if a weapon with the given id exists.
static func has_weapon(id: String) -> bool:
	_ensure_loaded()
	return _weapons.has(id)

## Returns all known weapon IDs, in no guaranteed order.
static func get_all_ids() -> Array[String]:
	_ensure_loaded()
	return RegistryUtil.get_all_ids(_weapons)

## Returns all equipment IDs matching the given slot ("weapon", "armor", "shoulders", "ring", "trinket", "offhand",
## "helmet", "boots").
static func get_by_slot(slot: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k in _weapons.keys():
		var w: WeaponData = _weapons[k] as WeaponData
		if w != null and w.slot == slot:
			result.append(str(k))
	return result
