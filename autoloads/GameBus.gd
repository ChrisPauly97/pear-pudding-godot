extends Node

# World signals
signal enemy_engaged(enemy_data: Dictionary)
signal duel_requested(enemy_data: Dictionary, wager: int)
signal hud_message_requested(text: String)
signal dialogue_state_changed(active: bool)
signal battle_won(result: Dictionary)
signal battle_lost()
signal duel_won()
signal duel_lost()
# Ghost duels (GID-102 / TID-377): async, AI-piloted battle against a stored deck
# snapshot of another (possibly offline) session member. Zero live networking —
# did_win is the only outcome; SceneManager applies the (win-only) coin reward.
signal ghost_duel_ended(did_win: bool)
signal inventory_requested
signal shop_requested
signal bounty_board_requested
signal mailbox_requested
signal journal_requested
signal character_requested

# Battle signals
signal battle_fled
signal card_played(card_id: String, zone: String, slot: int)
signal card_attacked(attacker_id: String, target_id: String)
signal turn_ended(player_id: int)
signal battle_ended(winner: int)  # 0 = player, 1 = enemy
signal status_ticked(entity_id: String, effect_id: String, remaining: int)
signal fatigue_damage(player_id: int, damage: int)
# PvP card battles (GID-091): duel-style end, no rewards. did_win is from the
# local peer's perspective. SceneManager restores the shared co-op world.
signal pvp_battle_ended(did_win: bool)
# Co-op PvE joint battle (GID-099): all allies vs shared boss. did_win from local
# perspective. SceneManager restores the shared co-op world.
signal coop_pve_battle_ended(did_win: bool)
# Team PvP duels (GID-102 / TID-371): 2v2, duel-style end, no rewards. did_win is
# from the local peer's team perspective. SceneManager restores the shared co-op world.
signal team_battle_ended(did_win: bool)
# PvP referee match end (GID-097 dedicated-server relay / GID-104 session tournaments):
# emitted only when the local peer is refereeing (_local_player_idx < 0, i.e. it isn't
# one of the two combatants) — carries the winner's canonical GameState index (0/1),
# which pvp_battle_ended's plain bool can't express for a non-participant. A no-op
# unless something is actually listening (e.g. WorldScene's tournament bracket advance).
signal pvp_referee_match_ended(winner_idx: int)

# Story signals
signal story_flag_set(flag: String)
signal story_scroll_collected(scroll_id: String)
signal all_scrolls_collected()

# Achievement signals
signal achievement_unlocked(achievement_id: String)

# Economy signals
signal essence_changed(new_amount: int)
signal equipment_dropped(equip_id: String)
signal bag_full
signal card_routed_to_mailbox(template_id: String)

# Progression signals
signal level_up(new_level: int)
signal xp_changed(new_xp: int, new_level: int)
signal skill_tree_requested
signal corruption_points_changed(new_amount: int)
signal redemption_points_changed(new_amount: int)

# Tutorial signals
signal tutorial_popup_requested(popup_id: String)

# Endless Spire signals
signal spire_card_drafted(card_id: String)
signal spire_run_ended(stats: Dictionary)

# Puzzle signals
signal puzzle_requested(puzzle_id: String)
signal puzzle_solved(puzzle_id: String)

# Scripted story battle signals (GID-108)
signal scripted_battle_requested(battle_id: String)
signal scripted_battle_ended(battle_id: String, did_win: bool)

# World event signals
signal world_event_started(event_id: String)
signal world_event_ended(event_id: String)
signal traveling_shop_requested(stock: Array[String], price: int)

# Weather signals
signal weather_changed(weather_id: String, duration: float)

# Treasure map signals
signal fragment_collected()
signal treasure_map_assembled()
signal treasure_excavated(coins: int, card_id: String)

# Waystone signals
signal waystone_activated(waystone_id: String)

# Waypoint signals
signal waypoint_changed(waypoint: Dictionary)

# Mount signals
signal mount_state_changed(mounted: bool, mount_id: String)

# Card pack signals
signal pack_purchased(pack_id: String, rolled_cards: Array[Dictionary])

# Bounty signals
signal bounty_progress_changed(bounty_id: String, progress: int, count: int)
signal bounty_completed(bounty_id: String)

# Blacksmith signals
signal blacksmith_requested
signal weapon_upgraded(weapon_id: String, new_level: int)
signal weapon_salvaged(weapon_id: String, coins: int, essence: int)

# Siege signals
signal siege_victory
signal siege_defeated(coins_lost: int)

# Rival signals
signal rival_encounter_won(encounter_num: int)

# Garden signals
signal plant_harvested(plot_idx: int, plants_count: int)
signal inventory_changed
signal potion_crafted(potion_id: String)
signal potion_used(potion_id: String)

# Cantrip signals
signal cantrip_used(cantrip_id: String)

# Landmark discovery signals (GID-067)
signal landmark_discovered(landmark_id: String, display_name: String)

# Blight signals (GID-066)
signal blight_changed()

# Ambient audio signals
signal biome_changed(biome_id: int)
signal entered_named_map(map_name: String)
signal exited_to_world
