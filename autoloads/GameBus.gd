extends Node

# World signals
signal enemy_engaged(enemy_data: Dictionary)
signal battle_won(result: Dictionary)
signal battle_lost()
signal chest_opened(card_ids: Array)
signal map_transition_requested(map_name: String, target_door_id: String)

# Battle signals
signal card_played(card_id: String, zone: String, slot: int)
signal card_attacked(attacker_id: String, target_id: String)
signal turn_ended(player_id: int)
signal battle_ended(winner: int)  # 0 = player, 1 = enemy
