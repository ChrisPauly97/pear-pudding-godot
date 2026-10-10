# gdlint: disable=max-file-lines
# BID-053 lint debt: oversized script. Shrink it by extraction; don't add to it.
extends Node

const BiomeDef = preload("res://game_logic/world/BiomeDef.gd")
const _DamageSchools = preload("res://game_logic/battle/DamageSchools.gd")

const _FALLBACK_DECK: Array[String] = [
	"ghost", "ghost", "skeleton", "skeleton",
	"zombie", "zombie", "ghoul", "ghoul",
]

## The 8 core enemy types that count toward bestiary completion.
## Story/siege/special enemies (martarquas, rival, mimic, spectre) are excluded.
const _BESTIARY_ELIGIBLE: Array[String] = [
	"undead_basic", "undead_horde", "undead_elite", "ghoul_pack",
	"duelist_novice", "duelist_adept", "duelist_champion", "roaming_terror",
]

## GID-176 / TID-719: the level sub-range an enemy type lives in. An enemy's
## level is its tile level clamped into its zone's range ∩ this (ZoneLevels.enemy_level_at).
## Starter-zone types are authored; the rest default by difficulty tier.
const LEVEL_RANGES: Dictionary = {
	"undead_basic": Vector2i(1, 2), "undead_horde": Vector2i(2, 4), "ghoul_pack": Vector2i(3, 5),
	# GID-177 / TID-722: Chapter 1 road-camp types.
	"wolf_pack": Vector2i(4, 6), "forest_shade": Vector2i(5, 8), "bog_hag": Vector2i(6, 8),
	"imbued_stag": Vector2i(7, 9), "martarquas_scout": Vector2i(8, 10),
}
const TIER_LEVEL_RANGES: Array[Vector2i] = [Vector2i(1, 12), Vector2i(5, 24), Vector2i(12, 40), Vector2i(20, 60)]

static var _enemies: Dictionary = {}
static var _loaded: bool = false

static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_enemies = {
		"undead_basic": {
			"attack_school": "dark",
			"display_name": "Undead Wanderer",
			"schools": {"resist": ["dark"], "weak": ["light"]},
			"deck": ["ghost", "ghost", "ghost", "skeleton", "skeleton", "skeleton", "zombie", "zombie", "zombie",
					"ghoul"],
			"drop_pool": ["ghost", "skeleton", "mend", "wither", "surge_spirit", "ember_imp"],
			"coin_reward": 5,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 1,
			"ai_persona": "basic",
			"lore_text": ("Drawn forth by ancient dark rites, these shambling dead roam the wilds seeking the warmth "
					+ "of the living. They are slow but relentless, overwhelming lone travelers with sheer numbers."),
			"signature_card": "sig_wanderer",
			"capture_condition": "win_by_turn",
			"capture_param": 9,
		},
		"undead_horde": {
			"attack_school": "dark",
			"rt_attack_bonus": 2,  # BID-095: a horde hits as a horde (with its 4-unit pack)
			"display_name": "Horde Shambler",
			"schools": {"resist": ["dark"], "weak": ["light"]},
			"deck": ["ghost", "ghost", "ghost", "ghost", "skeleton", "skeleton", "skeleton", "zombie", "zombie",
					"ghoul", "ghoul"],
			"drop_pool": ["skeleton", "zombie", "dawn_acolyte", "dusk_wraith", "shrouded_wraith", "dusk_seer",
					"void_creeper"],
			# Starts on the board; shown beside it in the world (TID-541). Four strong: a horde (BID-095).
			"pack": ["zombie", "skeleton", "ghost", "zombie"],
			"leaderless": true,  # no enemy hero: clear the board to win (BID-077)
			"coin_reward": 8,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 2,
			"ai_persona": "aggro",
			"lore_text": ("Where one undead wanders, a horde is never far behind. These pack hunters press forward in "
					+ "relentless waves, making up in numbers what they lack in cunning."),
			"signature_card": "sig_shambler",
			"capture_condition": "spell_final_blow",
			"capture_param": 0,
		},
		"undead_elite": {
			"attack_school": "dark",
			"display_name": "Undead Warlord",
			"schools": {"resist": ["dark"], "weak": ["light", "rift"]},
			"deck": ["ghoul", "ghoul", "ghoul", "ghoul", "ghoul", "zombie", "zombie", "zombie", "zombie", "skeleton",
					"skeleton", "skeleton"],
			"drop_pool": ["ghoul", "restore", "drain", "blitz_ghoul", "veiled_paladin", "ash_warden"],
			"coin_reward": 20,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 4,
			"ai_persona": "control",
			"lore_text": ("A champion re-risen by Martarquas sorcery, the Undead Warlord retains fragments of its "
					+ "battle tactics. It fights with brutal efficiency — a grim echo of the soldier it once was."),
			"signature_card": "sig_warlord",
			"capture_condition": "hero_hp_at_most",
			"capture_param": 10,
		},
		"ghoul_pack": {
			"attack_school": "dark",
			"rt_hp_mult": 0.95,  # BID-095: real-time balance vs its level band
			"display_name": "Ghoul Pack Leader",
			"schools": {"resist": ["dark"], "weak": ["light", "verdant"]},
			"deck": ["ghoul", "ghoul", "ghoul", "ghoul", "zombie", "zombie", "zombie", "zombie", "skeleton", "skeleton",
					"skeleton", "skeleton"],
			"drop_pool": ["zombie", "ghoul", "dawn_paladin", "dusk_vampire", "iron_revenant", "dawn_guardian",
					"dawn_healer"],
			"pack": ["ghoul", "ghoul", "zombie"],  # starts on the board; shown beside it in the world (TID-541)
			"coin_reward": 12,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 3,
			"ai_persona": "aggro",
			"lore_text": ("Once a fierce warrior in life, the Ghoul Pack Leader still commands through primal "
					+ "instinct, driving its kin with savage coordination. Its bite carries a rot that weakens even "
					+ "the stoutest heart."),
			"signature_card": "sig_pack_leader",
			"capture_condition": "no_minion_hero_attacks",
			"capture_param": 0,
		},
		"wraith": {
			"rt_hp_mult": 0.9,  # GID-186: real-time balance vs its level band
			"attack_school": "dark",
			"display_name": "Wraith",
			"schools": {"resist": ["physical", "dark"], "weak": ["light", "rift"]},
			"deck": ["ghost", "ghost", "ghost", "ghost", "ghost", "ghost", "skeleton", "skeleton", "ember_imp",
					"ember_imp"],
			"drop_pool": ["ghost", "ember_imp", "spark", "surge_spirit", "fracture_shardling"],
			"coin_reward": 8,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 1,
			"ai_persona": "basic",
			"lore_text": ("A thin, flickering echo of the dead, the Wraith darts across the grasslands faster than the "
					+ "eye can track. It has little substance and less patience — it strikes fast and often, hoping "
					+ "to overwhelm before it is unmade."),
		},
		"forest_shade": {
			"attack_school": "verdant",
			"display_name": "Forest Shade",
			"schools": {"resist": ["verdant"], "weak": ["light", "rift"]},
			"deck": ["skeleton", "skeleton", "skeleton", "zombie", "zombie", "dusk_wraith", "dusk_wraith", "insight",
					"insight", "dusk_seer"],
			"drop_pool": ["skeleton", "dusk_wraith", "insight", "dusk_seer", "shrouded_wraith", "bloom_grove_mother",
					"thorn_thornback"],
			"coin_reward": 10,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 2,
			"ai_persona": "control",
			"lore_text": ("Something moves between the trees that isn't quite there. The Forest Shade lingers at the "
					+ "edge of sight, reading the battle before it commits — an unsettling patience for a creature "
					+ "of the wild."),
		},
		"sand_stalker": {
			"rt_hp_mult": 1.4,  # GID-186: real-time balance vs its level band
			"display_name": "Sand Stalker",
			"schools": {"resist": ["dark"], "weak": ["physical"]},
			"deck": ["skeleton", "skeleton", "skeleton", "skeleton", "zombie", "zombie", "zombie", "ghoul", "ghoul",
					"dagger_throw"],
			"drop_pool": ["zombie", "ghoul", "dagger_throw", "blitz_ghoul"],
			"coin_reward": 9,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 2,
			"ai_persona": "aggro",
			"lore_text": ("Buried beneath the dunes until footsteps wake it, the Sand Stalker erupts in a burst of "
					+ "grit and old bone. It presses the attack immediately, giving no quarter and no time to think."),
		},
		"cactus_worm": {
			"rt_hp_mult": 0.9,  # GID-186: real-time balance vs its level band
			"display_name": "Cactus Worm",
			"schools": {"resist": ["physical", "verdant"], "weak": ["dark"]},
			"deck": ["skeleton", "skeleton", "skeleton", "zombie", "zombie", "zombie", "thorn_bramble_snare",
					"thorn_bramble_snare", "thorn_thorn_volley", "dagger_throw"],
			"drop_pool": ["skeleton", "zombie", "thorn_bramble_snare", "thorn_thorn_volley", "dagger_throw",
					"thorn_bramble_warden", "bloom_sprout"],
			"coin_reward": 7,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 1,
			"ai_persona": "aggro",
			"lore_text": ("A fat green worm armoured in cactus spines, it lies still among the dunes until something "
					+ "warm brushes past, then rears up and lashes out. Its spines break off in whatever it strikes."),
		},
		"imbued_stag": {
			"attack_school": "verdant",
			"rt_hp_mult": 0.9,  # BID-095: real-time balance vs its level band
			"display_name": "Imbued Stag",
			"schools": {"resist": ["verdant"], "weak": ["dark"]},
			"deck": ["ghost", "ghost", "ghoul", "ghoul", "flux_kinetic_bolt", "flux_kinetic_bolt", "flux_momentum",
					"flux_momentum", "thorn_thorn_volley", "bloom_germinate", "bloom_germinate"],
			"drop_pool": ["flux_kinetic_bolt", "flux_momentum", "bloom_germinate", "thorn_thorn_volley",
					"flux_displace", "bloom_grove_mother", "thorn_bramble_warden", "bloom_rootweaver"],
			"coin_reward": 11,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 2,
			"ai_persona": "control",
			"lore_text": ("A stag that grazed too long on a ley line and drank the essence rising from it. Its antlers "
					+ "burn with raw magic and it guards the line as its own, charging any who come to tap it."),
		},
		"scorched_revenant": {
			"attack_school": "dark",
			"display_name": "Scorched Revenant",
			"schools": {"resist": ["dark"], "weak": ["light", "verdant"]},
			"deck": ["zombie", "zombie", "zombie", "ghoul", "ghoul", "scorch", "scorch", "char", "char", "alight",
					"alight", "ember"],
			"drop_pool": ["ghoul", "scorch", "char", "ember_imp", "ash_warden", "fracture_displacer"],
			"coin_reward": 12,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 3,
			"ai_persona": "aggro",
			"lore_text": ("Charred to the bone by the scorched wastes yet still standing, the Revenant carries embers "
					+ "of old fires in its ribs. It burns the field it fights on, indifferent to the cost."),
		},
		"mountain_troll": {
			"rt_hp_mult": 1.2,  # GID-186: real-time balance vs its level band
			"display_name": "Mountain Troll",
			"schools": {"resist": ["rift"], "weak": ["light", "physical", "dark"]},
			"deck": ["ghoul", "ghoul", "ghoul", "ghoul", "ghoul", "ghoul", "zombie", "zombie", "zombie", "restore",
					"restore", "wither"],
			"drop_pool": ["ghoul", "restore", "wither", "iron_revenant", "veiled_paladin"],
			"coin_reward": 15,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 3,
			"ai_persona": "control",
			"lore_text": ("Slow, immense, and nearly impossible to put down for good, the Mountain Troll grinds down "
					+ "anything foolish enough to challenge it on its own peaks. It does not need to be fast when it "
					+ "can simply outlast you."),
		},
		"stone_golem": {
			"display_name": "Stone Golem",
			"schools": {"resist": ["physical", "light"], "weak": ["verdant", "rift"]},
			"deck": ["ghoul", "ghoul", "ghoul", "ghoul", "ghoul", "ghoul", "zombie", "zombie", "zombie",
					"ash_bone_wall", "ash_bone_wall", "ash_arbiter"],
			"drop_pool": ["ghoul", "ash_arbiter", "ash_defile", "iron_revenant", "ancient_guardian"],
			"coin_reward": 18,
			"is_boss": true,
			"boss_hp": 40,
			"phase2_deck": ["ghoul", "ghoul", "ghoul", "ghoul", "zombie", "zombie", "ash_defile", "ash_defile",
					"ash_annihilate", "ash_annihilate", "ash_arbiter", "ash_arbiter"],
			"difficulty_tier": 4,
			"ai_persona": "control",
			"lore_text": ("Ancient stone given grim purpose by forgotten mountain rites, the Golem is less a creature "
					+ "than a fortress that walks. Wounding it only seems to focus its fury — the deeper into the "
					+ "fight, the harder it hits back."),
		},
		"hollow_steward": {
			"attack_school": "dark",
			"display_name": "The Hollow Steward",
			"schools": {"resist": ["dark"], "weak": ["light"]},
			"deck": ["skeleton", "skeleton", "skeleton", "skeleton", "dusk_wraith", "dusk_wraith", "dusk_wraith",
					"dusk_seer", "dusk_seer", "wither", "wither", "drain"],
			"drop_pool": ["dusk_wraith", "shrouded_wraith", "dark_pact", "dusk_seer", "void_creeper"],
			"coin_reward": 25,
			"is_boss": true,
			"boss_hp": 35,
			"phase2_deck": ["shrouded_wraith", "shrouded_wraith", "dusk_wraith", "dusk_wraith", "dusk_wraith", "drain",
					"drain", "wither", "wither", "dark_pact", "dark_pact", "skeleton"],
			"difficulty_tier": 4,
			"ai_persona": "control",
			"lore_text": ("Once the trusted steward of Farsyth Mansion, now a hollow thing bound to old, dark "
					+ "bargains. It keeps the household running out of habit alone, and turns on any who threaten to "
					+ "expose what it has become."),
		},
		"martarquas_vanguard": {
			"display_name": "Martarquas Vanguard",
			"schools": {"resist": ["physical"], "weak": ["light", "dark"]},
			"deck": ["skeleton", "skeleton", "skeleton", "zombie", "zombie", "zombie", "ghoul", "ghoul", "ghoul",
					"ember_imp", "ember_imp", "ember"],
			"drop_pool": ["ghoul", "blitz_ghoul", "ember_imp", "iron_revenant", "duel_crown"],
			"coin_reward": 30,
			"is_boss": true,
			"boss_hp": 40,
			"phase2_deck": ["ghoul", "ghoul", "ghoul", "ghoul", "blitz_ghoul", "blitz_ghoul", "ember", "ember",
					"scorch", "scorch", "ember_imp", "ember_imp"],
			"difficulty_tier": 4,
			"ai_persona": "control",
			"lore_text": ("Sent ahead of the tribe's main force to probe the temple's defenses, the Vanguard is "
					+ "disciplined where the raiders are reckless. It fights a measured, armored battle — testing "
					+ "exactly how ready the alliance really is."),
		},
		# GID-136 / TID-557: the town training dummy. `passive` is read by
		# `EnemyRegistry.is_passive()` / `BattleRealtime.maybe_start()` and
		# forwarded to `RealtimeCombat.set_passive()` — the dummy never casts
		# or swings, regardless of its (empty) deck or hero.attack. Huge HP, no
		# coin/card reward, not bestiary-eligible; started via
		# `NpcInteractions._offer_training_dummy_fight()` outside the normal
		# engage/duel record paths, so it's never marked defeated.
		"training_dummy": {
			"display_name": "Training Dummy",
			"schools": {"resist": ["dark"], "weak": ["verdant"]},
			"deck": [],
			"drop_pool": [],
			"coin_reward": 0,
			"is_boss": true,
			"boss_hp": 500,
			"phase2_deck": [],
			"difficulty_tier": 1,
			"ai_persona": "basic",
			"passive": true,
			"lore_text": "A straw-stuffed dummy, scarred by countless practice swings. It never fights back.",
		},
		"duelist_novice": {
			"display_name": "Novice Duelist",
			"schools": {"resist": ["rift"], "weak": ["dark"]},
			"deck": ["ghost", "ghost", "ghost", "skeleton", "skeleton", "skeleton", "zombie", "zombie", "ghoul",
					"mend"],
			"drop_pool": [],
			"coin_reward": 0,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 1,
			"ai_persona": "basic",
			"lore_text": ("A young card duelist eager to prove themselves on the Blancogov tournament circuit. Their "
					+ "deck is simple, but they fight with an enthusiasm that belies their rank."),
		},
		"duelist_adept": {
			"display_name": "Adept Duelist",
			"schools": {"resist": ["light"], "weak": ["dark"]},
			"deck": ["ghost", "ghost", "skeleton", "skeleton", "zombie", "zombie", "ghoul", "ghoul", "mend", "wither",
					"surge_spirit", "ember_imp"],
			"drop_pool": [],
			"coin_reward": 0,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 2,
			"ai_persona": "aggro",
			"lore_text": ("A seasoned competitor with dozens of tournament wins behind them. They read the board well "
					+ "and know how to manage resources to outlast less patient opponents."),
		},
		"duelist_champion": {
			"display_name": "Champion of Blancogov",
			"schools": {"resist": ["light", "rift"], "weak": ["dark"]},
			"deck": ["ghoul", "ghoul", "blitz_ghoul", "blitz_ghoul", "shrouded_wraith", "void_wyrm", "wither", "wither",
					"soul_rend", "dark_pact"],
			"drop_pool": [],
			"coin_reward": 0,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 3,
			"ai_persona": "control",
			"lore_text": ("The undefeated champion of the Blancogov card tournament. Years of dedicated study and "
					+ "thousands of matches have honed their deck to a razor's edge — they have not lost in three "
					+ "seasons."),
		},
		"roaming_terror": {
			"rt_hp_mult": 0.85,  # GID-186: real-time balance vs its level band
			"attack_school": "rift",
			"display_name": "Roaming Terror",
			"schools": {"resist": ["rift"], "weak": ["light"]},
			"deck": ["ghoul", "ghoul", "ghoul", "ghoul", "blitz_ghoul", "blitz_ghoul", "soul_harvest", "soul_harvest",
					"drain", "drain", "void_creeper", "void_creeper", "dusk_wraith", "dusk_wraith", "wither", "wither"],
			"drop_pool": ["blitz_ghoul", "soul_harvest", "void_wyrm", "dusk_vampire", "dark_pact", "shrouded_wraith",
					"iron_revenant", "flux_temporal_rider", "fracture_unmaker"],
			"coin_reward": 40,
			"is_boss": true,
			"boss_hp": 50,
			"phase2_deck": ["void_wyrm", "void_wyrm", "soul_rend", "soul_rend", "dusk_vampire", "dusk_vampire", "drain",
					"wither", "dark_pact", "blitz_ghoul", "blitz_ghoul", "ghoul", "ghoul", "ghoul", "void_creeper",
					"void_creeper"],
			"difficulty_tier": 4,
			"ai_persona": "control",
			"lore_text": ("An ancient horror that drifts the borderlands, drawn by conflict and chaos. When the "
					+ "Martarquas surge, this creature follows in their wake — and grows more dangerous as it is "
					+ "wounded."),
		},
		"martarquas_raider_1": {
			"display_name": "Martarquas Raider",
			"schools": {"resist": ["dark"], "weak": ["physical"]},
			"deck": ["ghost", "ghost", "zombie", "zombie", "ghoul"],
			"drop_pool": [],
			"coin_reward": 0,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 1,
			"ai_persona": "aggro",
			"lore_text": ("A Martarquas footsoldier, freshly blooded on raids through the border villages. Their early "
					+ "confidence hides a lack of experience — overcome them and the tribe's advance falters."),
		},
		"martarquas_raider_2": {
			"rt_hp_mult": 1.35,  # GID-186: real-time balance vs its level band
			"display_name": "Martarquas Veteran",
			"schools": {"resist": ["dark"], "weak": ["physical"]},
			"deck": ["ghost", "skeleton", "zombie", "zombie", "ghoul", "ghoul"],
			"drop_pool": [],
			"coin_reward": 0,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 2,
			"ai_persona": "aggro",
			"lore_text": ("A veteran of many raids, this Martarquas warrior fights with practiced brutality. The town "
					+ "guard has already fallen back — it falls to you to hold the gate."),
		},
		"martarquas_raider_3": {
			"rt_hp_mult": 0.85,  # GID-186: real-time balance vs its level band
			"display_name": "Martarquas Warlord",
			"schools": {"resist": ["dark", "physical"], "weak": ["light"]},
			"deck": ["ghost", "skeleton", "skeleton", "zombie", "zombie", "ghoul", "ghoul"],
			"drop_pool": [],
			"coin_reward": 0,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 3,
			"ai_persona": "aggro",
			"lore_text": ("The siege commander — where lesser raiders hesitated, this one drove them forward. Defeat "
					+ "the Warlord and the siege collapses. The town will owe you a debt it cannot easily repay."),
		},
		"martarquas_warleader": {
			"display_name": "Martarquas War-Leader",
			"schools": {"resist": ["dark"], "weak": ["physical", "light"]},
			"deck": ["ghost", "skeleton", "skeleton", "zombie", "zombie", "ghoul", "ghoul", "ghoul"],
			"drop_pool": ["ghost", "skeleton", "zombie", "ghoul"],
			"coin_reward": 0,
			"is_boss": true,
			"boss_hp": 45,
			"phase2_deck": ["skeleton", "zombie", "zombie", "ghoul", "ghoul", "ghoul"],
			"difficulty_tier": 4,
			"ai_persona": "control",
			"lore_text": ("The war-leader who drove the muster on Marsax hold. Steal his plans and the tribe's whole "
					+ "campaign unravels — but he does not give ground easily."),
		},
		# ── GID-149 new enemy roster ──────────────────────────────────────────
		"wolf_pack": {
			"display_name": "Grey Wolf Alpha",
			"schools": {"resist": ["verdant"], "weak": ["dark", "physical"]},
			"deck": ["wolf", "wolf", "wolf", "wolf", "wolf", "wolf", "wolf", "wolf", "dagger_throw", "dagger_throw"],
			"pack": ["wolf", "wolf", "wolf"],  # starts on the board; circles the Alpha in the world
			"drop_pool": ["wolf", "dagger_throw", "surge_spirit", "bloom_sprout", "thorn_briar_sprite"],
			"coin_reward": 6, "is_boss": false, "boss_hp": 0, "phase2_deck": [],
			"difficulty_tier": 1, "ai_persona": "aggro",
			"traits": ["howl"],
			"lore_text": ("Grey wolves came down from the hills when the dead began to walk; the living were easier "
					+ "prey. They hunt as one, and when the pack is thinned the Alpha howls for more."),
			"signature_card": "sig_alpha_wolf", "capture_condition": "no_ally_lost", "capture_param": 0,
		},
		"bog_hag": {
			"attack_school": "verdant",
			"display_name": "Bog Hag",
			"schools": {"resist": ["verdant", "dark"], "weak": []},
			"deck": ["thorn_bramble_snare", "thorn_bramble_snare", "thorn_thorn_volley", "thorn_thorn_volley",
					"bloom_germinate", "bloom_germinate", "wither", "wither", "treant", "treant", "drain"],
			"drop_pool": ["treant", "thorn_bramble_snare", "bloom_germinate", "wither", "bloom_rootweaver",
					"thorn_thornback", "bloom_elder_root", "thorn_briarwall"],
			"coin_reward": 10, "is_boss": false, "boss_hp": 0, "phase2_deck": [],
			"difficulty_tier": 2, "ai_persona": "control",
			"lore_text": ("She was a village healer once, before the marsh taught her what else a herb can do. She "
					+ "stirs her pools and waits, and her curses are slow — slow enough to stop, if you are quick."),
			"signature_card": "sig_cauldron_toad", "capture_condition": "hero_hp_at_least", "capture_param": 20,
		},
		"martarquas_scout": {
			"rt_hp_mult": 0.85,  # BID-095: real-time balance vs its level band
			"display_name": "Martarquas Scout",
			"schools": {"resist": ["dark"], "weak": ["verdant"]},
			"deck": ["dagger_throw", "dagger_throw", "dagger_throw", "shadow_bolt", "shadow_bolt", "brittle",
					"brittle", "skeleton", "skeleton", "ghost", "ghost"],
			"drop_pool": ["dagger_throw", "shadow_bolt", "brittle", "shrouded_wraith"],
			"coin_reward": 9, "is_boss": false, "boss_hp": 0, "phase2_deck": [],
			"difficulty_tier": 2, "ai_persona": "aggro",
			"lore_text": ("The tribe's eyes on the roads. Scouts travel light, strike first and never stay for a "
					+ "fair fight — the muster behind them needs to know what the alliance is doing."),
			"signature_card": "sig_pathfinder", "capture_condition": "win_by_turn", "capture_param": 5,
		},
		"scarab_swarm": {
			"rt_hp_mult": 0.75,  # GID-186: real-time balance vs its level band
			"display_name": "Scarab Queen",
			"schools": {"resist": ["physical"], "weak": ["verdant", "rift"]},
			"deck": ["scarab", "scarab", "scarab", "scarab", "scarab", "scarab", "scarab", "scarab",
					"thorn_thorn_volley", "thorn_thorn_volley", "flux_momentum"],
			"pack": ["scarab", "scarab", "scarab", "scarab", "scarab"],
			"drop_pool": ["scarab", "thorn_thorn_volley", "flux_momentum", "flux_skitter"],
			"coin_reward": 11, "is_boss": false, "boss_hp": 0, "phase2_deck": [],
			"difficulty_tier": 2, "ai_persona": "aggro",
			"traits": ["brood"],
			"lore_text": ("Under the dunes the queen lays without end. Her brood boils up through the sand at anything "
					+ "that stops to rest — clear them fast, or she will simply lay more."),
			"signature_card": "sig_scarab_matriarch", "capture_condition": "spell_final_blow", "capture_param": 0,
		},
		"ember_cultist": {
			"rt_hp_mult": 1.3,  # GID-186: real-time balance vs its level band
			"attack_school": "rift",
			"display_name": "Ember Cultist",
			"schools": {"resist": ["rift"], "weak": ["physical", "dark"]},
			"deck": ["ember_imp", "ember_imp", "ember_imp", "ember_imp", "ember_heat_wave", "ember_heat_wave",
					"ember_cinder", "ember_cinder", "ember_cinder", "ember_flame_lance", "ember_flame_lance"],
			"drop_pool": ["ember_imp", "ember_cinder", "ember_flame_lance", "ember_heat_wave", "flux_warp_adept",
					"fracture_mirror_wight"],
			"coin_reward": 14, "is_boss": false, "boss_hp": 0, "phase2_deck": [],
			"difficulty_tier": 3, "ai_persona": "control",
			"lore_text": ("Zealots who believe the scorched lands are a promise, not a ruin. They chant in rings of "
					+ "braziers and call up imps from the coals to do their fighting."),
			"signature_card": "sig_cinder_acolyte", "capture_condition": "no_minion_hero_attacks", "capture_param": 0,
		},
		"frost_wendigo": {
			"rt_hp_mult": 0.9,  # GID-186: real-time balance vs its level band
			"display_name": "Frost Wendigo",
			"schools": {"resist": ["physical"], "weak": ["light"]},
			"deck": ["ghoul", "ghoul", "ghoul", "ghoul", "zombie", "zombie", "ash_bone_spear", "ash_bone_spear",
					"brittle", "brittle", "shadow_bolt", "shadow_bolt"],
			"drop_pool": ["ghoul", "ash_bone_spear", "brittle", "shadow_bolt"],
			"coin_reward": 18, "is_boss": false, "boss_hp": 0, "phase2_deck": [],
			"difficulty_tier": 4, "ai_persona": "aggro",
			"traits": ["frenzy"],
			"lore_text": ("Only seen on the peaks after dark, and only once. It is always hungry, and the longer a "
					+ "fight goes on the hungrier it gets. End it quickly or not at all."),
			"signature_card": "sig_wendigo_antler", "capture_condition": "win_by_turn", "capture_param": 7,
		},
		"rift_echo": {
			"attack_school": "rift",
			"display_name": "Riftborn Echo",
			"schools": {"resist": ["rift"], "weak": ["light"]},
			"deck": ["flux_kinetic_bolt", "flux_kinetic_bolt", "flux_momentum", "flux_displace", "fracture_fault",
					"ghost", "ghost", "skeleton", "skeleton", "zombie"],
			"drop_pool": ["flux_kinetic_bolt", "flux_displace", "fracture_fault", "fracture_shardfall",
					"flux_warp_adept", "fracture_displacer"],
			"coin_reward": 13, "is_boss": false, "boss_hp": 0, "phase2_deck": [],
			"difficulty_tier": 3, "ai_persona": "control",
			"traits": ["mirror"],
			"lore_text": ("Where a ley line runs through dry country the rift leaks, and what leaks out wears your "
					+ "face. It knows your spells, because it learned them from you."),
			"signature_card": "sig_echo_shard", "capture_condition": "hero_hp_at_least", "capture_param": 15,
		},
		"barrow_king": {
			"rt_hp_mult": 0.75,  # GID-186: real-time balance vs its level band
			"attack_school": "dark",
			"display_name": "The Barrow King",
			"schools": {"resist": ["dark"], "weak": ["light"]},
			"schools_phase2": {"resist": ["physical"], "weak": ["light"], "immune": ["dark"]},
			"deck": ["skeleton", "skeleton", "skeleton", "skeleton", "ghost", "ghost", "ghoul", "ghoul", "zombie",
					"zombie"],
			"drop_pool": ["ghoul", "ash_bone_spear", "soul_rend", "shrouded_wraith"],
			"coin_reward": 60, "is_boss": true, "boss_hp": 55,
			"phase2_deck": ["ash_bone_spear", "ash_bone_spear", "ash_desecrate", "ash_desecrate", "soul_rend",
					"shadow_bolt", "drain", "skeleton", "skeleton"],
			"difficulty_tier": 4, "ai_persona": "control",
			"lore_text": ("Madrian's first lord, buried with his guard beneath the graveyard. Open his crypt and he "
					+ "wakes to defend it: first with the guard, then — when they fall — with the old death-magic "
					+ "he was buried to keep quiet."),
			"signature_card": "sig_barrow_crown", "capture_condition": "no_ally_lost", "capture_param": 0,
		},
		"rival_isfig_1": {
			"attack_school": "rift",
			"display_name": "Isfig",
			"schools": {"resist": ["rift"], "weak": ["dark"]},
			"deck": ["ghost", "ghost", "ghost", "skeleton", "skeleton", "skeleton", "mend", "wither"],
			"drop_pool": [],
			"coin_reward": 10,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 1,
			"ai_persona": "control",
			"lore_text": ("A sharp-eyed young man who seems to know more about Saimtar's journey than he lets on. He "
					+ "smiles as he challenges you to a duel — not out of malice, but to measure you."),
		},
		"rival_isfig_2": {
			"rt_hp_mult": 1.4,  # GID-186: real-time balance vs its level band
			"attack_school": "rift",
			"display_name": "Isfig the Pursuing",
			"schools": {"resist": ["rift"], "weak": ["dark", "physical"]},
			"deck": ["skeleton", "skeleton", "skeleton", "zombie", "zombie", "zombie", "ghost", "mend", "wither",
					"surge_spirit"],
			"drop_pool": [],
			"coin_reward": 15,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 2,
			"ai_persona": "control",
			"lore_text": ("He has followed you across the wilds, watching and adapting. The easy smile is gone; this "
					+ "time he means to stop you — or find out once and for all what you carry that Scargroth's "
					+ "letter warned him about."),
		},
		"rival_isfig_3": {
			"attack_school": "rift",
			"display_name": "Isfig, Maiteln's Shadow",
			"schools": {"resist": ["light", "rift"], "weak": ["dark"]},
			"deck": ["zombie", "zombie", "zombie", "ghoul", "ghoul", "blitz_ghoul", "drain", "wither", "soul_rend",
					"dusk_wraith"],
			"drop_pool": [],
			"coin_reward": 25,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 3,
			"ai_persona": "control",
			"lore_text": ("Standing in the shadow of the temple, Isfig speaks Maiteln's name with a cold familiarity "
					+ "that turns your blood to ice. Whatever he once was, he has chosen his side — and it is not "
					+ "yours."),
		},
		"spectre_wisp": {
			"attack_school": "dark",
			"display_name": "Wisp",
			"schools": {"resist": ["dark"], "weak": ["light"]},
			"deck": ["ghost", "ghost", "ghost", "ghost", "shadow_bolt", "shadow_bolt", "soul_rend", "wither",
					"surge_spirit", "void_creeper"],
			"drop_pool": ["ghost", "shadow_bolt", "soul_rend", "wither", "dusk_wraith", "void_creeper",
					"flux_skitter", "fracture_shardling"],
			"coin_reward": 8,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 1,
			"ai_persona": "basic",
			"night_drop_boost": true,
			"lore_text": ("A lost soul drawn out by darkness, trailing cold light through the night mist. Where one "
					+ "wisp drifts, the veil between worlds has grown thin."),
		},
		"spectre_haunt": {
			"rt_hp_mult": 0.85,  # GID-186: real-time balance vs its level band
			"attack_school": "dark",
			"display_name": "Phantom",
			"schools": {"resist": ["dark", "physical"], "weak": ["light", "rift"]},
			"deck": ["ghost", "ghost", "ghost", "shadow_bolt", "shadow_bolt", "soul_rend", "soul_rend", "wither",
					"wither", "dusk_wraith", "void_creeper", "void_creeper"],
			"drop_pool": ["shadow_bolt", "soul_rend", "dusk_wraith", "shrouded_wraith", "void_creeper", "dark_pact",
					"fracture_mirror_wight", "flux_blinkfox"],
			"coin_reward": 12,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 2,
			"ai_persona": "aggro",
			"night_drop_boost": true,
			"lore_text": ("A vengeful spirit anchored to the mortal world by unfinished purpose, the Phantom strikes "
					+ "with cold malice and retreats into shadow before the blow can be answered."),
		},
		"spectre_dread": {
			"rt_hp_mult": 0.7,  # GID-186: real-time balance vs its level band
			"attack_school": "dark",
			"display_name": "Wraith",
			"schools": {"resist": ["dark", "physical"], "weak": ["light"]},
			"deck": ["ghost", "ghost", "shadow_bolt", "shadow_bolt", "soul_rend", "soul_rend", "soul_harvest",
					"soul_harvest", "dusk_wraith", "dusk_wraith", "void_creeper", "void_creeper", "dark_pact",
					"wither"],
			"drop_pool": ["soul_rend", "soul_harvest", "dusk_wraith", "shrouded_wraith", "void_wyrm", "dark_pact",
					"dusk_vampire", "fracture_unmaker", "flux_temporal_rider"],
			"coin_reward": 18,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 3,
			"ai_persona": "control",
			"night_drop_boost": true,
			"lore_text": ("A Wraith of apex terror, born when sorrow and power collapse into a single point. It hunts "
					+ "not for sustenance but for the sheer extinguishing of light — it is drawn to those who carry "
					+ "hope."),
		},
		"mimic": {
			"attack_school": "verdant",
			"display_name": "Mimic",
			"schools": {"resist": ["verdant"], "weak": ["rift"]},
			"deck": ["ghost", "skeleton", "zombie", "ghoul", "ghost", "skeleton", "zombie", "ghoul"],
			"drop_pool": ["ghost", "skeleton", "zombie", "ghoul"],
			"coin_reward": 25,
			"is_boss": false,
			"boss_hp": 0,
			"phase2_deck": [],
			"difficulty_tier": 2,
			"ai_persona": "basic",
			"lore_text": ("Not every treasure chest holds gold. Some hold teeth. The Mimic waits in perfect stillness, "
					+ "indistinguishable from its surroundings — until you reach inside."),
		},
		"blight_heart": {
			"rt_hp_mult": 0.95,  # GID-186: real-time balance vs its level band
			"attack_school": "dark",
			"display_name": "The Blight Heart",
			"schools": {"resist": ["dark"], "weak": ["light", "verdant"]},
			"deck": ["void_creeper", "void_creeper", "void_creeper", "soul_harvest", "soul_harvest", "soul_harvest",
					"dusk_wraith", "dusk_wraith", "wither", "wither", "dark_pact", "dark_pact", "drain", "drain",
					"void_wyrm", "void_wyrm"],
			"drop_pool": ["void_creeper", "soul_harvest", "dark_pact", "void_wyrm", "dusk_vampire"],
			"coin_reward": 30,
			"is_boss": true,
			"boss_hp": 40,
			"phase2_deck": [],
			"difficulty_tier": 4,
			"ai_persona": "control",
			"lore_text": ("A pulsing node of corrupted essence, the Blight Heart anchors the spreading darkness to "
					+ "this land. Destroy it and the corruption will slowly recede — but it will not yield without a "
					+ "fierce fight."),
		},
	}

## Returns the battle deck for a type. Falls back to a minimal undead deck if unknown.
static func get_deck(type_id: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	if _enemies.has(type_id):
		result.assign(_enemies[type_id]["deck"])
	else:
		push_warning("EnemyRegistry: unknown enemy type '%s', using fallback deck" % type_id)
		result = _FALLBACK_DECK.duplicate()
	return result

## Returns the drop pool for a type. Falls back to a single ghost if unknown.
## Fight traits (GID-149): named rules BattleModifiers applies (see game_logic/battle/EnemyTraits.gd).
static func get_traits(type_id: String) -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	out.assign((_enemies.get(type_id, {}) as Dictionary).get("traits", []))
	return out

## School of an enemy's hero swings and heavy blows (GID-181 / TID-751). Optional `attack_school`
## per type; anything absent or unknown is "physical".
static func get_attack_school(type_id: String) -> String:
	_ensure_loaded()
	var school: String = str((_enemies.get(type_id, {}) as Dictionary).get("attack_school", "physical"))
	return school if _DamageSchools.is_school(school) else _DamageSchools.PHYSICAL

## Damage-school profile (GID-181 / TID-750) in the shape game_logic/battle/DamageSchools.gd reads:
## {"resist": {school: true}, "weak": {...}, "immune": {...}}. Every key is present (possibly empty).
## `phase` 2 uses a boss's `schools_phase2` (a full replacement) when it has one; every other
## enemy, and phase 1, uses `schools`. Unknown types give an all-empty profile (neutral).
static func get_school_profile(type_id: String, phase: int = 1) -> Dictionary:
	_ensure_loaded()
	var data: Dictionary = _enemies.get(type_id, {})
	var src: Dictionary = data.get("schools", {})
	if phase >= 2 and data.has("schools_phase2"):
		src = data["schools_phase2"]
	var out: Dictionary = {}
	for kind: String in ["resist", "weak", "immune"]:
		var tags: Dictionary = {}
		var names: Array = src.get(kind, [])
		for school: Variant in names:
			tags[str(school)] = true
		out[kind] = tags
	return out

## Pack encounters (GID-135 / TID-541): the units that start on the enemy board —
## the same ones drawn beside the leader in the world. Empty for everyone else.
static func get_pack(type_id: String) -> Array[String]:
	_ensure_loaded()
	var out: Array[String] = []
	out.assign((_enemies.get(type_id, {}) as Dictionary).get("pack", []))
	return out

## Leaderless packs (BID-077): no enemy hero to hit — the fight ends when the pack's board is clear.
static func is_leaderless(type_id: String) -> bool:
	_ensure_loaded()
	return bool((_enemies.get(type_id, {}) as Dictionary).get("leaderless", false))

static func get_drop_pool(type_id: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	if _enemies.has(type_id):
		result.assign(_enemies[type_id]["drop_pool"])
	else:
		result = ["ghost"]
	return result

## Returns the coin reward for defeating an enemy of this type. Falls back to 5 if unknown.
static func get_coin_reward(type_id: String) -> int:
	_ensure_loaded()
	if _enemies.has(type_id):
		return int(_enemies[type_id]["coin_reward"])
	return 5

## Returns true if the enemy type is a boss.
static func is_boss(type_id: String) -> bool:
	_ensure_loaded()
	if _enemies.has(type_id):
		return bool(_enemies[type_id]["is_boss"])
	return false

## Alias for is_boss() — kept for backward compatibility.
static func get_is_boss(type_id: String) -> bool:
	return is_boss(type_id)

## Returns the display name for a type, or the raw ID if unknown.
static func get_display_name(type_id: String) -> String:
	_ensure_loaded()
	if _enemies.has(type_id):
		return str(_enemies[type_id]["display_name"])
	return type_id

## Returns the boss HP override (0 = use default 30).
static func get_boss_hp(type_id: String) -> int:
	_ensure_loaded()
	if _enemies.has(type_id):
		return int(_enemies[type_id]["boss_hp"])
	return 0

## Returns the phase 2 deck for this enemy type, or empty array if none.
static func get_phase2_deck(type_id: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	if _enemies.has(type_id):
		result.assign(_enemies[type_id]["phase2_deck"])
	return result

## Selects an enemy type based on depth through a named map (0 = start, 1 = end).
static func type_for_depth(depth: int, max_depth: int) -> String:
	var pct: float = float(depth) / float(max(max_depth, 1))
	if pct < 0.33:
		return "undead_basic"
	if pct < 0.66:
		return "undead_horde"
	return "ghoul_pack"

## Returns the AI persona ("basic" | "aggro" | "control") for an enemy type
## (GID-112). Falls back to "basic" if unknown so puzzle mode / any caller
## that passes an empty or unrecognised type_id gets today's predictable AI.
static func get_ai_persona(type_id: String) -> String:
	_ensure_loaded()
	if _enemies.has(type_id):
		var data: Dictionary = _enemies[type_id]
		return str(data.get("ai_persona", "basic"))
	return "basic"

## TID-557: true for enemies that never cast or swing in real-time combat (the
## training dummy). `BattleRealtime.maybe_start` forwards this to
## `RealtimeCombat.set_passive`.
## Real-time per-type HP multiplier (hero + pack units), content tuning that
## evens a type out against its level band (BID-095). 1.0 when unset.
static func rt_hp_mult(type_id: String) -> float:
	_ensure_loaded()
	var data: Dictionary = _enemies.get(type_id, {})
	return float(data.get("rt_hp_mult", 1.0))

## Real-time per-type attack bonus for the type's units (BID-095), 0 when unset.
static func rt_attack_bonus(type_id: String) -> int:
	_ensure_loaded()
	var data: Dictionary = _enemies.get(type_id, {})
	return int(data.get("rt_attack_bonus", 0))

static func is_passive(type_id: String) -> bool:
	_ensure_loaded()
	if _enemies.has(type_id):
		var data: Dictionary = _enemies[type_id]
		return bool(data.get("passive", false))
	return false

## Returns the difficulty tier (1–4) for an enemy type. Falls back to 1 if unknown.
static func get_difficulty_tier(type_id: String) -> int:
	_ensure_loaded()
	if _enemies.has(type_id):
		return int(_enemies[type_id]["difficulty_tier"])
	return 1

## Selects an enemy type based on Manhattan distance from the world origin chunk.
static func type_for_chunk_dist(dist: int) -> String:
	if dist <= 3:
		return "undead_basic"
	if dist <= 8:
		return "undead_horde"
	if dist <= 14:
		return "ghoul_pack"
	return "undead_elite"

## Selects an enemy type by biome and Manhattan distance from origin.
static func type_for_biome(biome_id: int, dist: int) -> String:
	var pool: Array = BiomeDef.ENEMY_POOLS[biome_id]
	var idx: int = clamp(dist / 8, 0, pool.size() - 1)
	return pool[idx]

## Returns all known enemy type IDs sorted by difficulty_tier then id.
static func get_all_enemy_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for k: String in _enemies.keys():
		result.append(k)
	result.sort_custom(func(a: String, b: String) -> bool:
		var ta: int = int(_enemies[a]["difficulty_tier"])
		var tb: int = int(_enemies[b]["difficulty_tier"])
		if ta != tb:
			return ta < tb
		return a < b
	)
	return result

## Returns the IDs of the enemy types that count toward bestiary completion.
static func get_bestiary_enemy_ids() -> Array[String]:
	return _BESTIARY_ELIGIBLE.duplicate()

## Returns true if enemies of this type engage the player on proximity.
## false = interact-only (wanderers). true = aggressive (attack on sight).
static func is_tracking(type_id: String) -> bool:
	return type_id == "undead_elite" or type_id == "ghoul_pack" or type_id == "roaming_terror" \
		or type_id == "spectre_wisp" or type_id == "spectre_haunt" or type_id == "spectre_dread" \
		or type_id == "scorched_revenant" or type_id == "mountain_troll" or type_id == "stone_golem" \
		or type_id == "hollow_steward" or type_id == "martarquas_vanguard" or type_id == "imbued_stag" \
		or type_id == "wolf_pack" or type_id == "martarquas_scout" or type_id == "frost_wendigo" \
		or type_id == "rift_echo"

## Returns true if this enemy type boosts card drop rarity by one tier on defeat.
static func get_night_drop_boost(type_id: String) -> bool:
	_ensure_loaded()
	if _enemies.has(type_id):
		var data: Dictionary = _enemies[type_id]
		return bool(data.get("night_drop_boost", false))
	return false

## Returns the lore text for a type, or "" if unknown or not yet written.
static func get_lore_text(type_id: String) -> String:
	_ensure_loaded()
	if _enemies.has(type_id):
		return str(_enemies[type_id]["lore_text"])
	return ""

## Returns the signature card id for this enemy type, or "" if none.
static func get_signature_card(type_id: String) -> String:
	_ensure_loaded()
	if _enemies.has(type_id):
		var data: Dictionary = _enemies[type_id]
		return str(data.get("signature_card", ""))
	return ""

## Returns the capture condition key for this enemy type, or "" if none.
static func get_capture_condition(type_id: String) -> String:
	_ensure_loaded()
	if _enemies.has(type_id):
		var data: Dictionary = _enemies[type_id]
		return str(data.get("capture_condition", ""))
	return ""

## Returns the numeric capture param for this enemy type (0 if none or unknown).
static func get_capture_param(type_id: String) -> int:
	_ensure_loaded()
	if _enemies.has(type_id):
		var data: Dictionary = _enemies[type_id]
		return int(data.get("capture_param", 0))
	return 0

## Returns XP rewarded for defeating this enemy type. Bosses are 2×.
static func level_range(type_id: String) -> Vector2i:
	if LEVEL_RANGES.has(type_id):
		return LEVEL_RANGES[type_id] as Vector2i
	var tier: int = clampi(get_difficulty_tier(type_id), 1, TIER_LEVEL_RANGES.size())
	return TIER_LEVEL_RANGES[tier - 1]

static func get_xp_reward(type_id: String, is_boss: bool = false) -> int:
	const XP_TABLE: Dictionary = {
		"undead_basic": 20, "undead_horde": 35, "ghoul_pack": 50, "undead_elite": 80,
		"roaming_terror": 150,
		"spectre_wisp": 25, "spectre_haunt": 40, "spectre_dread": 60,
	}
	var base: int = int(XP_TABLE.get(type_id, 25))
	return base * 2 if is_boss else base

## Returns all unique signature card ids across all known enemy types.
static func get_all_signature_card_ids() -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for key: String in _enemies.keys():
		var data: Dictionary = _enemies[key]
		var sig: String = str(data.get("signature_card", ""))
		if sig != "" and not result.has(sig):
			result.append(sig)
	return result
