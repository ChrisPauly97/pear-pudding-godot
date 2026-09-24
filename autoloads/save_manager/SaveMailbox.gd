## Mailbox: overflow card instances waiting to be claimed, sold or scrapped.
##
## Owned by SaveManager (`SaveManager.mailbox`), created in its `_init`. The state
## stays on SaveManager because PERSISTED_FIELDS walks its properties, so this
## reads and writes it through `_save.<field>`.
extends RefCounted

var _save: Node


func _init(save_manager: Node) -> void:
	_save = save_manager


## Returns all card instances currently held in the mailbox overflow queue.
func get_mailbox_instances() -> Array[Dictionary]:
	return _save.mailbox_cards

## Position of `uid` in the mailbox, or -1 when it isn't there.
func _mailbox_index(uid: String) -> int:
	for i in range(_save.mailbox_cards.size()):
		if str(_save.mailbox_cards[i].get("uid", "")) == uid:
			return i
	return -1

## Moves a mailbox card into the bag. Returns false (no-op) if the uid isn't in the
## mailbox or the bag is still full.
func claim_mailbox_card(uid: String) -> bool:
	if _save.is_bag_full():
		return false
	var idx: int = _mailbox_index(uid)
	if idx < 0:
		return false
	var inst: Dictionary = _save.mailbox_cards[idx]
	_save.mailbox_cards.remove_at(idx)
	_save.owned_cards.append(inst)
	_save._uid_index[uid] = inst
	_save._dirty = true
	return true

## Claims as many mailbox cards as fit in the bag. Returns the number claimed.
func claim_all_mailbox_cards() -> int:
	var claimed: int = 0
	while not _save.mailbox_cards.is_empty():
		var uid: String = str(_save.mailbox_cards[0].get("uid", ""))
		if not claim_mailbox_card(uid):
			break
		claimed += 1
	return claimed

## Sells a mailbox card for gold. No-op if uid not found.
func sell_mailbox_card(uid: String) -> void:
	var idx: int = _mailbox_index(uid)
	if idx < 0:
		return
	var rarity: String = str(_save.mailbox_cards[idx].get("rarity", "common"))
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
	_save.add_coins(int(cfg.get("sell_gold", 0)))
	_save.mailbox_cards.remove_at(idx)
	_save._dirty = true

## Scraps a mailbox card for essence. No-op if uid not found.
func scrap_mailbox_card(uid: String) -> void:
	var idx: int = _mailbox_index(uid)
	if idx < 0:
		return
	var rarity: String = str(_save.mailbox_cards[idx].get("rarity", "common"))
	var cfg: Dictionary = IsoConst.RARITY_CONFIG.get(rarity, {})
	if _save.essence == 0:
		GameBus.tutorial_popup_requested.emit("essence")
	_save.essence += int(cfg.get("scrap_essence", 0))
	GameBus.essence_changed.emit(_save.essence)
	_save.mailbox_cards.remove_at(idx)
	_save._dirty = true
