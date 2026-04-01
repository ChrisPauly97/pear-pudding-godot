extends Node

# World signals
signal enemy_engaged(enemy_data: Dictionary)
signal hud_message_requested(text: String)
signal battle_won(result: Dictionary)
signal battle_lost()
signal map_transition_requested(map_name: String, target_door_id: String)
signal inventory_requested

# Battle signals
signal card_played(card_id: String, zone: String, slot: int)
signal card_attacked(attacker_id: String, target_id: String)
signal turn_ended(player_id: int)
signal battle_ended(winner: int)  # 0 = player, 1 = enemy

# Story signals
signal story_flag_set(flag: String)
