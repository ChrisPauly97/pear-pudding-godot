# gdlint: disable=max-file-lines
# TID-761 pushed this past 500 lines (material drops). Tracked debt: shrink by extraction, don't add to it.
## Battle victory: the standard reward flow, plus the Spire, siege and mimic handlers
## that each replace it wholesale, the siege stage interstitial and the Chapter 2
## cliffhanger.
##
## A child of the SceneManager autoload, created in `SceneManager._ensure_modules()`.
## Reach SceneManager state as `_sm.<name>` and write the state only through
## `_sm._transition_to()`. Use `_sm.add_child` rather than a bare `add_child`.
extends Node

const _SceneManager = preload("res://autoloads/SceneManager.gd")
const _SceneFlow = preload("res://game_logic/SceneFlow.gd")
# gdlint:ignore = constant-name
const State = _SceneFlow.State
const CardDropUtil = preload("res://game_logic/CardDropUtil.gd")
const CardRegistry = preload("res://autoloads/CardRegistry.gd")
const EnemyRegistry = preload("res://autoloads/EnemyRegistry.gd")
const _SiegeDefs = preload("res://game_logic/SiegeDefs.gd")
const _CoopNightHunts = preload("res://game_logic/CoopNightHunts.gd")
const Gambits = preload("res://game_logic/battle/Gambits.gd")
const _UiUtil = preload("res://scenes/ui/UiUtil.gd")
const _WorldEventManager = preload("res://autoloads/WorldEventManager.gd")
const _WorldMap = preload("res://game_logic/world/WorldMap.gd")
const _WorldScene = preload("res://scenes/world/WorldScene.gd")
const _RewardToastFx = preload("res://scenes/world/RewardToastFx.gd")
const _ZoneLevels = preload("res://game_logic/world/ZoneLevels.gd")
const _RiftDefs = preload("res://game_logic/spire/RiftDefs.gd")
const _EnemyNPC = preload("res://scenes/world/entities/EnemyNPC.gd")
const _GearRolls = preload("res://game_logic/items/GearRolls.gd")
const _VeterancyUtil = preload("res://game_logic/VeterancyUtil.gd")
const _SaveGear = preload("res://autoloads/save_manager/SaveGear.gd")
const _MaterialDrops = preload("res://game_logic/professions/MaterialDrops.gd")

## Chain pulls (GID-135 / TID-532): a pursuing enemy this close to the hero when an
## in-place fight is won engages at once, without the camera zooming out between.
const CHAIN_RADIUS: float = 9.0
## If the follow-up never starts (it stood down), release the held zoom after this.
const CHAIN_GIVEUP_SECONDS: float = 1.5

var _sm: _SceneManager


func _init(scene_manager: _SceneManager) -> void:
	_sm = scene_manager


## Victory dispatch. The spire run, the siege gauntlet and a mimic chest each
## replace the standard reward flow wholesale rather than adding to it, so
## each gets its own handler and reports whether it consumed the result.
func _on_battle_won(result: Dictionary) -> void:
	if _sm.current_state() != State.BATTLE:
		return
	if _spire_battle_won(result):
		return
	if _siege_battle_won(result):
		return
	# Read enemy context before clearing pending_battle.
	var enemy_type: String = str(_sm.save_manager.pending_battle_enemy_data.get("enemy_type", ""))
	var is_boss: bool = bool(_sm.save_manager.pending_battle_enemy_data.get("is_boss", false))
	var gambit_id: String = str(_sm.save_manager.pending_battle_enemy_data.get("gambit_id", ""))
	var is_rival: bool = enemy_type.begins_with("rival_")
	var captured_enemy_id: String = _sm._current_battle_enemy_id
	if _mimic_battle_won(enemy_type, captured_enemy_id):
		return
	var drop_tier: int = EnemyRegistry.get_difficulty_tier(enemy_type) if enemy_type != "" else 1
	if is_boss:
		drop_tier = 4
	elif EnemyRegistry.get_night_drop_boost(enemy_type):
		drop_tier = mini(drop_tier + 1, 4)
	drop_tier = mini(drop_tier + Gambits.get_rarity_tier_bonus(gambit_id), 4)
	var is_nocturnal: bool = enemy_type.begins_with("spectre_")
	# GID-103 (TID-383): party night hunts — a bigger co-op party earns a further
	# rarity bump on a spectral kill, on top of the existing single-player boost.
	if is_nocturnal and NetworkManager.is_active():
		var party_size: int = multiplayer.get_peers().size() + 1
		drop_tier = mini(drop_tier + _CoopNightHunts.party_drop_tier_bonus(party_size), 4)
	if not _sm._current_battle_enemy_id.is_empty():
		if not is_rival and not is_nocturnal:
			_sm.save_manager.mark_enemy_defeated(_sm._current_battle_enemy_id)
		_sm.save_manager.increment_progress("enemies_defeated", 1)
		_sm._bump_session_stat("enemies_defeated", 1)
		_sm._current_battle_enemy_id = ""
	if enemy_type != "" and not is_rival and not is_nocturnal:
		_sm.save_manager.record_enemy_defeated(enemy_type)
		_sm.save_manager.bounties.increment_bounty_progress("defeat_enemy_type", {"enemy_type": enemy_type})
	# Quest kills count spectres and rivals too ("After Dark" asks for spectre_wisp kills).
	if enemy_type != "":
		_sm.save_manager.quests.progress_event("kill", enemy_type)
	_sm.save_manager.increment_progress("battles_won", 1)
	_sm.save_manager.check_deck_achievements(_sm.save_manager.player_deck)
	_sm._bump_session_stat("battles_won", 1)
	var reward: String = str(result.get("card_reward", ""))
	if reward != "":
		# Use pre-rolled rarity/stats from BattleScene if present; otherwise roll now.
		var rarity: String
		var stats: Dictionary
		if result.has("reward_rarity"):
			rarity = str(result["reward_rarity"])
			stats = result.get("reward_stats", {})
		else:
			rarity = CardDropUtil.effective_rarity(reward, CardDropUtil.roll_rarity(drop_tier))
			stats = CardDropUtil.roll_stats(reward, rarity)
		_sm.save_manager.grant_card_reward(reward, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)),
				int(stats.get("cost", -1)))
		_sm._bump_session_stat("cards_earned", 1)
	var weapon_reward: String = str(result.get("weapon_reward", ""))
	if weapon_reward != "":
		# TID-538: the drop rolls rarity by the enemy's tier and item level by its level.
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var lvl: int = int(_sm.save_manager.pending_battle_enemy_data.get("enemy_level", _sm.save_manager.level))
		var roll: Dictionary = _SaveGear.roll_for(weapon_reward, drop_tier, lvl, rng)
		var got: String = _sm.save_manager.gear.grant(weapon_reward, roll)
		if got == "upgraded":
			GameBus.hud_message_requested.emit(_SaveGear.drop_message(weapon_reward, roll, got))
	# Soulbind signature capture (GID-061): grant signature card + persist capture.
	var sig_capture: String = str(result.get("signature_capture", ""))
	if sig_capture != "":
		var sig_stats: Dictionary = CardDropUtil.roll_stats(sig_capture, "rare")
		_sm.save_manager.grant_card_reward(sig_capture, "rare", int(sig_stats.get("attack", -1)),
				int(sig_stats.get("health", -1)), int(sig_stats.get("cost", -1)))
		_sm.save_manager.mark_signature_captured(sig_capture)
		_sm._bump_session_stat("cards_earned", 1)
	# Boss battles emit card_rewards (list of all drop_pool cards)
	var rewards: Array = result.get("card_rewards", [])
	var pre_rolled: Array = result.get("reward_rarities", [])
	var pre_stats: Array = result.get("reward_stats_list", [])
	for ri in range(rewards.size()):
		var rs: String = str(rewards[ri])
		if rs != "":
			var r_rarity: String
			var r_stats: Dictionary
			if ri < pre_rolled.size():
				r_rarity = str(pre_rolled[ri])
				r_stats = pre_stats[ri] if ri < pre_stats.size() else {}
			else:
				r_rarity = CardDropUtil.effective_rarity(rs, CardDropUtil.roll_rarity(drop_tier))
				r_stats = CardDropUtil.roll_stats(rs, r_rarity)
			_sm.save_manager.grant_card_reward(rs, r_rarity, int(r_stats.get("attack", -1)), int(r_stats.get("health", -1)),
					int(r_stats.get("cost", -1)))
			_sm._bump_session_stat("cards_earned", 1)
	# Award coins based on enemy type, multiplied by active gambit reward factor.
	var coins_won: int = 0
	if enemy_type != "":
		coins_won = Gambits.apply_reward_multiplier(EnemyRegistry.get_coin_reward(enemy_type), gambit_id)
		_sm.save_manager.add_coins(coins_won)
		_sm._bump_session_stat("coins_earned", coins_won)
	# Award XP based on enemy type (table lives in EnemyRegistry).
	var xp_amount: int = _level_scaled_xp(EnemyRegistry.get_xp_reward(enemy_type, is_boss),
			_sm.save_manager.pending_battle_enemy_data)
	_sm.save_manager.add_xp(xp_amount)
	_sm._bump_session_stat("xp_earned", xp_amount)
	# Enemy material drops (TID-761): the main kill, then any joined enemies (each
	# peer rolls its own, like the coins). Granted locally once the fight is counted.
	var drop_rng := RandomNumberGenerator.new()
	drop_rng.randomize()
	var materials: Dictionary = {}
	_MaterialDrops.roll_into(materials, _sm.save_manager.pending_battle_enemy_data, enemy_type, drop_tier, drop_rng)
	# Joined enemies' coins/XP ride the same floating toast as the main kill.
	var joined: Vector2i = _reward_joined_enemies(gambit_id, materials, drop_rng)
	for mat_id: String in materials:
		_sm.save_manager.professions.add_material(mat_id, int(materials[mat_id]))
	var material_text: String = _MaterialDrops.describe(materials)
	# Rival encounter win: don't count as standard kill; update rival progress instead.
	if is_rival:
		if enemy_type == "rival_isfig_3":
			if not _sm.save_manager.rival_defeated:
				_sm.save_manager.set_rival_defeated()
				_sm.save_manager.grant_card_reward("isfig_shadow_echo", "legendary")
				_sm.save_manager.mark_scroll_collected("scroll_isfig_shadow")
				GameBus.story_scroll_collected.emit("scroll_isfig_shadow")
		else:
			_sm.save_manager.record_rival_win()
			if captured_enemy_id == "rival_enc2":
				_sm.save_manager.set_story_flag("chapter1_received_letter")
		GameBus.rival_encounter_won.emit(_sm.save_manager.rival_encounters_won)
	# Apply veterancy: attribute kills/survival to collection instances (GID-060).
	var veterancy: Dictionary = result.get("veterancy", {})
	for vet_uid: String in veterancy.keys():
		var vdata: Dictionary = veterancy[vet_uid]
		var new_rank: int = _sm.save_manager.record_veterancy(vet_uid, int(vdata.get("kills", 0)),
				bool(vdata.get("survived", true)))
		if new_rank > 0:
			_announce_rank_up(vet_uid, new_rank)
	# Cross-magic currency accrual (GID-086, generalized by GID-127): playing a
	# magic type's signature-branch cards earns the currency that type spends.
	# PlayerState.cross_currency_earned() applies the per-card rate; this only
	# banks the totals.
	var corruption_earned: int = int(result.get("corruption_earned", 0))
	var redemption_earned: int = int(result.get("redemption_earned", 0))
	if corruption_earned > 0:
		_sm.save_manager.add_corruption_points(corruption_earned)
	if redemption_earned > 0:
		_sm.save_manager.add_redemption_points(redemption_earned)
	# Blight Heart cleansing (GID-066): mark the heart purified and award corruption points.
	var blight_heart_id: String = str(_sm.save_manager.pending_battle_enemy_data.get("blight_heart_id", ""))
	if blight_heart_id != "":
		_sm.save_manager.mark_heart_cleansed(blight_heart_id)
		_sm.save_manager.add_corruption_points(5)
		GameBus.blight_changed.emit()
		GameBus.hud_message_requested.emit("The blight recedes… +5 Corruption Points.")
	_sm._finish_battle()
	# End the roaming boss world event if the defeated enemy was the roaming terror.
	if enemy_type == "roaming_terror":
		var wem: _WorldEventManager = get_node_or_null("/root/WorldEventManager") as _WorldEventManager
		if wem != null:
			wem.end_event("roaming_boss")
	# GID-135 / TID-531: a routine in-world win skipped the blocking result
	# card (BattleScene._emit_routine_victory_toast) — show the coins/XP/card
	# news as floating toasts over the world instead, once it's reattached.
	var chain: _EnemyNPC = _chain_candidate()
	_sm.hold_fight_zoom = chain != null
	if bool(result.get("in_world_toast", false)):
		var reward_card: String = str(result.get("card_reward", ""))
		_sm._restore_world(_show_reward_toasts.bind(coins_won + joined.x, xp_amount + joined.y, reward_card,
				str(result.get("rt_tip", "")), material_text))
	else:
		if material_text != "":
			GameBus.hud_message_requested.emit("Gathered: " + material_text)
		_sm._restore_world()
	if chain != null:
		_start_chain(chain)
	# Chapter 2 beats 6 → 7 (GID-108 / TID-407): defeating the war-camp boss sets
	# chapter2_warcamp_cleared and immediately shows the cliffhanger narration
	# (reuses TID-405's ChapterEndingOverlay verbatim); closing it sets
	# chapter2_complete.
	if enemy_type == "martarquas_warleader":
		_sm.save_manager.set_story_flag("chapter2_warcamp_cleared")
		_show_chapter2_cliffhanger()

## Floating "+coins / +xp / card" toast over the fight location (GID-135 /
## TID-531). Only ever called from `_restore_world`'s post-swap callback — see
## the CLAUDE.md spire-draft learning for why building this on the next line
## after `_restore_world()` instead would attach it to a scene about to die.
## A card just earned a veterancy rank (BID-074): say so, and the first time
## explain what veterancy is (TutorialRegistry "veterancy", shown once).
func _announce_rank_up(uid: String, rank: int) -> void:
	var inst: Dictionary = _sm.save_manager.get_instance_by_uid(uid)
	var base: String = str(CardRegistry.get_template(str(inst.get("template_id", ""))).get("name", "Your card"))
	GameBus.hud_message_requested.emit("Veteran! %s %s %s" % [base, _VeterancyUtil.title_for(rank),
			_VeterancyUtil.rank_chevrons(rank)])
	GameBus.tutorial_popup_requested.emit("veterancy")


## The nearest pursuing enemy within CHAIN_RADIUS of the hero, when the fight just
## won was fought in place (the world is still in the tree); else null.
func _chain_candidate() -> _EnemyNPC:
	var world: Node = _sm._saved_world_scene
	if world == null or not is_instance_valid(world) or not world.is_inside_tree() or NetworkManager.is_active():
		return null
	var player := world.get("_player") as Node3D
	if player == null:
		return null
	var best: _EnemyNPC = null
	var best_d: float = CHAIN_RADIUS
	for n: Node in get_tree().get_nodes_in_group(_EnemyNPC.GROUP):
		var e := n as _EnemyNPC
		if e == null or not e.is_pursuing() or not e.is_inside_tree():
			continue
		var d: float = Vector2(e.global_position.x - player.global_position.x,
				e.global_position.z - player.global_position.z).length()
		if d <= best_d:
			best = e
			best_d = d
	return best


## Lets `enemy` engage straight away (lifting the post-battle grace), and drops the
## held zoom if the follow-up fight never starts.
func _start_chain(enemy: _EnemyNPC) -> void:
	_sm._proximity_engage_blocked = false
	GameBus.hud_message_requested.emit("Another one!")
	enemy.engage()
	get_tree().create_timer(CHAIN_GIVEUP_SECONDS, false).timeout.connect(func() -> void:
		var world: Node = get_tree().current_scene
		if _sm.current_state() == State.WORLD and world != null and world.has_meta("battle_cam_size"):
			_sm.hold_fight_zoom = false
			_sm._thaw_world(world))


func _show_reward_toasts(coins_won: int, xp_won: int, reward_card_id: String, tip: String = "",
		materials_text: String = "") -> void:
	if tip != "":
		_sm._toast.show_text("Tip", tip)  # the post-fight coaching line (TID-559)
	var world: _WorldScene = get_tree().current_scene as _WorldScene
	if world == null:
		return
	var anchor: Node3D = world.get_player()
	if anchor == null:
		return
	var lines: Array[Dictionary] = []
	if coins_won > 0:
		lines.append({"text": "+%d Coins" % coins_won, "color": Color(1.0, 0.85, 0.3)})
	if xp_won > 0:
		lines.append({"text": "+%d XP" % xp_won, "color": Color(0.5, 1.0, 0.7)})
	if reward_card_id != "":
		var tmpl: Dictionary = CardRegistry.get_template(reward_card_id)
		lines.append({"text": str(tmpl.get("name", reward_card_id)), "color": Color(0.8, 0.9, 1.0)})
	if materials_text != "":
		lines.append({"text": materials_text, "color": Color(0.9, 0.75, 0.5)})
	if lines.is_empty():
		return
	var fx := _RewardToastFx.new()
	world.add_child(fx)
	fx.global_position = anchor.global_position
	fx.play(lines)

## Zone-level XP (TID-536): scaled by the enemy's level and its con colour
## against the player — grey enemies give none. Enemies without a level (story
## set pieces, duels) keep their base XP.
func _level_scaled_xp(base_xp: int, enemy_data: Dictionary) -> int:
	if not enemy_data.has("enemy_level"):
		return base_xp
	return _ZoneLevels.scaled_xp(base_xp, int(enemy_data["enemy_level"]), _sm.save_manager.level)

## Enemies that joined the fight mid-way (TID-551) each count as a kill:
## defeated in the world, bestiary + bounty progress, their own coins and XP.
## Returns the granted totals as (coins, xp) for the reward toast.
func _reward_joined_enemies(gambit_id: String, materials: Dictionary, drop_rng: RandomNumberGenerator) -> Vector2i:
	var total := Vector2i.ZERO
	for data: Dictionary in _sm._joined_enemies:
		var jid: String = str(data.get("id", ""))
		var jtype: String = str(data.get("enemy_type", ""))
		if jid != "":
			_sm.save_manager.mark_enemy_defeated(jid)
		_sm.save_manager.increment_progress("enemies_defeated", 1)
		_sm._bump_session_stat("enemies_defeated", 1)
		if jtype == "":
			continue
		_sm.save_manager.record_enemy_defeated(jtype)
		_sm.save_manager.bounties.increment_bounty_progress("defeat_enemy_type", {"enemy_type": jtype})
		_sm.save_manager.quests.progress_event("kill", jtype)
		var coins: int = Gambits.apply_reward_multiplier(EnemyRegistry.get_coin_reward(jtype), gambit_id)
		_sm.save_manager.add_coins(coins)
		_sm._bump_session_stat("coins_earned", coins)
		total.x += coins
		var xp: int = _level_scaled_xp(EnemyRegistry.get_xp_reward(jtype, bool(data.get("is_boss", false))), data)
		_sm.save_manager.add_xp(xp)
		_sm._bump_session_stat("xp_earned", xp)
		total.y += xp
		var jtier: int = 4 if bool(data.get("is_boss", false)) else EnemyRegistry.get_difficulty_tier(jtype)
		_MaterialDrops.roll_into(materials, data, jtype, jtier, drop_rng)
	_sm._joined_enemies.clear()
	return total

## Spire floor cleared: no card/coin rewards, save hero HP, show the draft.
func _spire_battle_won(result: Dictionary) -> bool:
	if not _sm.save_manager.spire.is_spire_active():
		return false
	var hero_hp: int = int(result.get("hero_hp", 30))
	_sm.save_manager.spire.set_spire_hero_hp(hero_hp)
	var spire_run: Dictionary = _sm.save_manager.spire.get_spire_run()
	var curr_floor: int = int(spire_run.get("floor", 1))
	var run_seed: int = int(spire_run.get("seed", 0))
	_sm.save_manager.set_story_flag("spire_floor_%d_%d_cleared" % [curr_floor, run_seed])
	var spire_enemy_type: String = str(_sm.save_manager.pending_battle_enemy_data.get("enemy_type", ""))
	if not _sm._current_battle_enemy_id.is_empty():
		_sm.save_manager.mark_enemy_defeated(_sm._current_battle_enemy_id)
		_sm.save_manager.increment_progress("enemies_defeated", 1)
		_sm._bump_session_stat("enemies_defeated", 1)
		_sm._current_battle_enemy_id = ""
	if spire_enemy_type != "":
		_sm.save_manager.record_enemy_defeated(spire_enemy_type)
		_sm.save_manager.bounties.increment_bounty_progress("defeat_enemy_type", {"enemy_type": spire_enemy_type})
	_sm.save_manager.increment_progress("battles_won", 1)
	_sm._bump_session_stat("battles_won", 1)
	_sm._finish_battle()
	# GID-142: the guardian ends the tier — no boon to draft; the exit door (now
	# open) walks the player out and records the clear.
	if _RiftDefs.is_guardian_floor(curr_floor):
		_sm._restore_world()
		return true
	# The draft is deferred into _restore_world's post-swap callback so it parents
	# to the live WorldScene rather than the dying battle overlay.
	_sm._restore_world(_sm._show_spire_draft.bind(curr_floor))
	return true

## Siege gauntlet stage cleared: chain to the next stage or apply the victory.
func _siege_battle_won(result: Dictionary) -> bool:
	var _siege: Dictionary = _sm.save_manager.town_siege.get_active_siege()
	if _siege.is_empty():
		return false
	var _siege_hero_hp: int = int(result.get("hero_hp", 30))
	_sm.save_manager.town_siege.set_siege_hero_hp(_siege_hero_hp)
	var _siege_stage: int = int(_siege.get("stage", 0))
	_sm.save_manager.increment_progress("battles_won", 1)
	_sm._bump_session_stat("battles_won", 1)
	_sm._current_battle_enemy_id = ""
	_sm.save_manager.clear_pending_battle()
	_sm.save_manager.clear_pending_battle_state()
	if _siege_stage < 2:
		_sm.save_manager.town_siege.advance_siege_stage()
		_sm.save_manager.save()
		_sm._dismiss_battle_overlay()
		_sm._restore_world()
		_show_siege_interstitial(_siege_stage + 1, _siege_hero_hp)
		return true
	var _siege_town: String = str(_siege.get("town", ""))
	_apply_siege_victory_rewards(_siege_town)
	# Chapter 2 beat 4 (GID-108 / TID-407): the story siege at marsax_hold
	# reuses this exact victory path — only the completion flag is new.
	if _siege_town == "marsax_hold":
		_sm.save_manager.set_story_flag("chapter2_siege_won")
	_sm.save_manager.town_siege.end_siege_victory()
	_sm.save_manager.save()
	_sm._dismiss_battle_overlay()
	_sm._restore_world()
	return true

## Mimic chest victory: open the chest, grant its loot straight to the bag.
func _mimic_battle_won(enemy_type: String, captured_enemy_id: String) -> bool:
	if enemy_type != "mimic" or captured_enemy_id.is_empty():
		return false
	var mimic_chest_id: String = captured_enemy_id
	var wmap_node: _WorldMap = (
			_sm._saved_world_scene.get("world_map") if _sm._saved_world_scene != null else null)
	if wmap_node != null:
		var mimic_chest: Dictionary = wmap_node.find_chest_by_id(mimic_chest_id)
		if not mimic_chest.is_empty():
			mimic_chest["opened"] = true
			var chest_cards: Array[String] = []
			chest_cards.assign(mimic_chest.get("card_ids", []))
			for card_id: String in chest_cards:
				var rarity: String = CardDropUtil.effective_rarity(card_id, CardDropUtil.roll_rarity(3))
				var stats: Dictionary = CardDropUtil.roll_stats(card_id, rarity)
				_sm.save_manager.grant_card_reward(card_id, rarity, int(stats.get("attack", -1)),
						int(stats.get("health", -1)), int(stats.get("cost", -1)))
				_sm._bump_session_stat("cards_earned", 1)
	var mimic_drop_pool: Array[String] = EnemyRegistry.get_drop_pool("mimic")
	if not mimic_drop_pool.is_empty():
		var bonus_card: String = mimic_drop_pool[randi() % mimic_drop_pool.size()]
		var b_rarity: String = CardDropUtil.effective_rarity(bonus_card, CardDropUtil.roll_rarity(2))
		var b_stats: Dictionary = CardDropUtil.roll_stats(bonus_card, b_rarity)
		_sm.save_manager.grant_card_reward(bonus_card, b_rarity, int(b_stats.get("attack", -1)),
				int(b_stats.get("health", -1)), int(b_stats.get("cost", -1)))
		_sm._bump_session_stat("cards_earned", 1)
	var mimic_coins: int = EnemyRegistry.get_coin_reward("mimic")
	_sm.save_manager.add_coins(mimic_coins)
	_sm._bump_session_stat("coins_earned", mimic_coins)
	_sm.save_manager.mark_chest_opened(mimic_chest_id)
	_sm.save_manager.record_enemy_defeated("mimic")
	_sm.save_manager.bounties.increment_bounty_progress("defeat_enemy_type", {"enemy_type": "mimic"})
	_sm.save_manager.increment_progress("enemies_defeated", 1)
	_sm._bump_session_stat("enemies_defeated", 1)
	_sm.save_manager.increment_progress("battles_won", 1)
	_sm._bump_session_stat("battles_won", 1)
	_sm._current_battle_enemy_id = ""
	_sm._finish_battle()
	_sm._restore_world()
	return true

## Co-op (GID-108 / TID-408, design rule 3): routed through GameBus so WorldScene
## (the sole listener) both shows it locally and broadcasts it to the rest of the
## party in a co-op session, instead of building the overlay directly here where
## no _net_sync reference exists.
func _show_chapter2_cliffhanger() -> void:
	var pages: Array[String] = [
		"By firelight, Maiteln reads the stolen muster plans: the tribe will not strike Blancogov. They march on the "
			+ "lords, one by one, before the alliance can gather.",
		"Maiteln, grim: every route, every garrison, every weakness — written in a steady court hand. The traitor "
			+ "knows the alliance's every move.",
		"And beneath the last page, in a script Saimtar knew like his own name — a list of the taken. His parents' "
			+ "names were not struck through.",
	]
	GameBus.narration_overlay_requested.emit(pages, "Chapter 2 Complete", "chapter2_complete")

## Applies siege victory rewards: 150 coins + a rare-or-better card.
func _apply_siege_victory_rewards(town: String) -> void:
	const SIEGE_VICTORY_COINS: int = 150
	_sm.save_manager.add_coins(SIEGE_VICTORY_COINS)
	_sm._bump_session_stat("coins_earned", SIEGE_VICTORY_COINS)
	var all_ids: Array[String] = CardRegistry.get_all_ids()
	if not all_ids.is_empty():
		var reward_id: String = all_ids[randi() % all_ids.size()]
		var rarity: String = CardDropUtil.roll_rarity(3)   # tier 3 = rare-or-better weighted
		var stats: Dictionary = CardDropUtil.roll_stats(reward_id, rarity)
		_sm.save_manager.grant_card_reward(reward_id, rarity, int(stats.get("attack", -1)), int(stats.get("health", -1)),
				int(stats.get("cost", -1)))
		_sm._bump_session_stat("cards_earned", 1)
	GameBus.siege_victory.emit()
	_sm.show_toast("Siege Defeated!", "%s thanks you! +%d coins + rare card" % [town.capitalize(), SIEGE_VICTORY_COINS])

## Shows a brief overlay between gauntlet stages, then chains the next battle after 2 s.
func _show_siege_interstitial(next_stage: int, hero_hp: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 200
	get_tree().root.add_child(layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)

	var vbox := _UiUtil.make_vbox(12, panel)

	var vh: float = get_viewport().get_visible_rect().size.y
	var title_lbl := _UiUtil.make_label(_SiegeDefs.get_stage_name(next_stage), int(vh * 0.04), Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER, vbox)

	var hp_lbl := _UiUtil.make_label("Hero HP: %d / 30" % hero_hp, int(vh * 0.03),
			Color(0.9, 0.3, 0.3) if hero_hp <= 10 else Color(1.0, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER, vbox)

	# Dismiss automatically and chain the next raider battle.
	get_tree().create_timer(2.0, false).timeout.connect(func() -> void:
		layer.queue_free()
		var next_type: String = "martarquas_raider_%d" % (next_stage + 1)
		var deck_ids: Array[String] = _SiegeDefs.get_raider_deck_ids(next_stage)
		var enemy_dict: Dictionary = {
			"enemy_type": next_type,
			"enemy_deck": deck_ids,
			"display_name": EnemyRegistry.get_display_name(next_type),
			"is_boss": false,
			"boss_hp": 0,
			"drop_pool": [],
			"coin_reward": 0,
		}
		GameBus.enemy_engaged.emit(enemy_dict))
