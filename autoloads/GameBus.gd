extends Node

# World signals
signal enemy_engaged(enemy_data: Dictionary)
signal hud_message_requested(text: String)
signal dialogue_state_changed(active: bool)
signal battle_won(result: Dictionary)
signal battle_lost()
signal map_transition_requested(map_name: String, target_door_id: String)
signal inventory_requested
signal shop_requested
signal journal_requested
signal character_requested

# Battle signals
signal card_played(card_id: String, zone: String, slot: int)
signal card_attacked(attacker_id: String, target_id: String)
signal turn_ended(player_id: int)
signal battle_ended(winner: int)  # 0 = player, 1 = enemy
signal status_applied(entity_id: String, effect_id: String, value: int)
signal status_ticked(entity_id: String, effect_id: String, remaining: int)

# Story signals
signal story_flag_set(flag: String)
signal story_scroll_collected(scroll_id: String)
signal all_scrolls_collected()

# Achievement signals
signal achievement_unlocked(achievement_id: String)

# Economy signals
signal essence_changed(new_amount: int)
signal equipment_dropped(equip_id: String)

# Progression signals
signal level_up(new_level: int)
