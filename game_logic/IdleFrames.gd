## NPC idle-life frames (GID-152 / TID-650): blink and glance for every
## townsperson, merchant and named NPC. One preload per file (Android packs only
## what is preloaded); regenerate with tools/generate_characters.py.
extends RefCounted

const _BOUNTY_MASTER := preload("res://assets/textures/characters/npc_bounty_master.png")
const _BOUNTY_MASTER_BLINK := preload("res://assets/textures/characters/npc_bounty_master_idle_1.png")
const _BOUNTY_MASTER_GLANCE := preload("res://assets/textures/characters/npc_bounty_master_idle_2.png")
const _BROTHER_ALDO := preload("res://assets/textures/characters/npc_brother_aldo.png")
const _BROTHER_ALDO_BLINK := preload("res://assets/textures/characters/npc_brother_aldo_idle_1.png")
const _BROTHER_ALDO_GLANCE := preload("res://assets/textures/characters/npc_brother_aldo_idle_2.png")
const _COMBAT_TRAINER := preload("res://assets/textures/characters/npc_combat_trainer.png")
const _COMBAT_TRAINER_BLINK := preload("res://assets/textures/characters/npc_combat_trainer_idle_1.png")
const _COMBAT_TRAINER_GLANCE := preload("res://assets/textures/characters/npc_combat_trainer_idle_2.png")
const _GRAVEDIGGER := preload("res://assets/textures/characters/npc_gravedigger.png")
const _GRAVEDIGGER_BLINK := preload("res://assets/textures/characters/npc_gravedigger_idle_1.png")
const _GRAVEDIGGER_GLANCE := preload("res://assets/textures/characters/npc_gravedigger_idle_2.png")
const _HILDA_BAKER := preload("res://assets/textures/characters/npc_hilda_baker.png")
const _HILDA_BAKER_BLINK := preload("res://assets/textures/characters/npc_hilda_baker_idle_1.png")
const _HILDA_BAKER_GLANCE := preload("res://assets/textures/characters/npc_hilda_baker_idle_2.png")
const _IVY_CHANDLER := preload("res://assets/textures/characters/npc_ivy_chandler.png")
const _IVY_CHANDLER_BLINK := preload("res://assets/textures/characters/npc_ivy_chandler_idle_1.png")
const _IVY_CHANDLER_GLANCE := preload("res://assets/textures/characters/npc_ivy_chandler_idle_2.png")
const _MERCHANT := preload("res://assets/textures/characters/npc_merchant.png")
const _MERCHANT_BLINK := preload("res://assets/textures/characters/npc_merchant_idle_1.png")
const _MERCHANT_GLANCE := preload("res://assets/textures/characters/npc_merchant_idle_2.png")
const _MERCHANT_TRAVELING := preload("res://assets/textures/characters/npc_merchant_traveling.png")
const _MERCHANT_TRAVELING_BLINK := preload("res://assets/textures/characters/npc_merchant_traveling_idle_1.png")
const _MERCHANT_TRAVELING_GLANCE := preload("res://assets/textures/characters/npc_merchant_traveling_idle_2.png")
const _OLD_TAM := preload("res://assets/textures/characters/npc_old_tam.png")
const _OLD_TAM_BLINK := preload("res://assets/textures/characters/npc_old_tam_idle_1.png")
const _OLD_TAM_GLANCE := preload("res://assets/textures/characters/npc_old_tam_idle_2.png")
const _RIFT_WARDEN := preload("res://assets/textures/characters/npc_rift_warden.png")
const _RIFT_WARDEN_BLINK := preload("res://assets/textures/characters/npc_rift_warden_idle_1.png")
const _RIFT_WARDEN_GLANCE := preload("res://assets/textures/characters/npc_rift_warden_idle_2.png")
const _TOWNSPERSON := preload("res://assets/textures/characters/npc_townsperson.png")
const _TOWNSPERSON_BLINK := preload("res://assets/textures/characters/npc_townsperson_idle_1.png")
const _TOWNSPERSON_GLANCE := preload("res://assets/textures/characters/npc_townsperson_idle_2.png")
const _TOWNSPERSON_2 := preload("res://assets/textures/characters/npc_townsperson_2.png")
const _TOWNSPERSON_2_BLINK := preload("res://assets/textures/characters/npc_townsperson_2_idle_1.png")
const _TOWNSPERSON_2_GLANCE := preload("res://assets/textures/characters/npc_townsperson_2_idle_2.png")
const _TOWNSPERSON_3 := preload("res://assets/textures/characters/npc_townsperson_3.png")
const _TOWNSPERSON_3_BLINK := preload("res://assets/textures/characters/npc_townsperson_3_idle_1.png")
const _TOWNSPERSON_3_GLANCE := preload("res://assets/textures/characters/npc_townsperson_3_idle_2.png")
const _WENNA_HERBALIST := preload("res://assets/textures/characters/npc_wenna_herbalist.png")
const _WENNA_HERBALIST_BLINK := preload("res://assets/textures/characters/npc_wenna_herbalist_idle_1.png")
const _WENNA_HERBALIST_GLANCE := preload("res://assets/textures/characters/npc_wenna_herbalist_idle_2.png")

const _TABLE: Dictionary = {
	_BOUNTY_MASTER: [_BOUNTY_MASTER_BLINK, _BOUNTY_MASTER_GLANCE],
	_BROTHER_ALDO: [_BROTHER_ALDO_BLINK, _BROTHER_ALDO_GLANCE],
	_COMBAT_TRAINER: [_COMBAT_TRAINER_BLINK, _COMBAT_TRAINER_GLANCE],
	_GRAVEDIGGER: [_GRAVEDIGGER_BLINK, _GRAVEDIGGER_GLANCE],
	_HILDA_BAKER: [_HILDA_BAKER_BLINK, _HILDA_BAKER_GLANCE],
	_IVY_CHANDLER: [_IVY_CHANDLER_BLINK, _IVY_CHANDLER_GLANCE],
	_MERCHANT: [_MERCHANT_BLINK, _MERCHANT_GLANCE],
	_MERCHANT_TRAVELING: [_MERCHANT_TRAVELING_BLINK, _MERCHANT_TRAVELING_GLANCE],
	_OLD_TAM: [_OLD_TAM_BLINK, _OLD_TAM_GLANCE],
	_RIFT_WARDEN: [_RIFT_WARDEN_BLINK, _RIFT_WARDEN_GLANCE],
	_TOWNSPERSON: [_TOWNSPERSON_BLINK, _TOWNSPERSON_GLANCE],
	_TOWNSPERSON_2: [_TOWNSPERSON_2_BLINK, _TOWNSPERSON_2_GLANCE],
	_TOWNSPERSON_3: [_TOWNSPERSON_3_BLINK, _TOWNSPERSON_3_GLANCE],
	_WENNA_HERBALIST: [_WENNA_HERBALIST_BLINK, _WENNA_HERBALIST_GLANCE],
}


## [blink, glance] for an idle NPC texture ([] when it has none).
static func for_idle(idle: Texture2D) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	out.assign(_TABLE.get(idle, []) as Array)
	return out
